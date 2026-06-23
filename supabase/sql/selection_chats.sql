-- Full chat for selection-based invitations.
-- Run after roles_and_agent_approval.sql, selections_rpc.sql, and push token SQL.

create table if not exists public.selection_chats (
  id uuid primary key default gen_random_uuid(),
  selection_id uuid not null references public.selections(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  model_user_id uuid not null references auth.users(id) on delete cascade,
  agent_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (selection_id, profile_id)
);

create table if not exists public.selection_chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.selection_chats(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (length(btrim(body)) > 0 and length(body) <= 2000),
  created_at timestamptz not null default now()
);

alter table public.selection_chats
  add column if not exists model_deleted_at timestamptz,
  add column if not exists agent_deleted_at timestamptz;

alter table public.selection_chat_messages
  add column if not exists media_type text not null default 'text'
    check (media_type in ('text', 'image', 'video')),
  add column if not exists media_url text,
  add column if not exists media_thumbnail_url text,
  add column if not exists deleted_at timestamptz;

create table if not exists public.selection_chat_message_reactions (
  message_id uuid not null references public.selection_chat_messages(id)
    on delete cascade,
  chat_id uuid not null references public.selection_chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (length(emoji) between 1 and 12),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  route text not null default '',
  read_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.app_notifications
  add column if not exists deleted_at timestamptz;

create index if not exists selection_chats_model_user_id_idx
  on public.selection_chats (model_user_id);

create index if not exists selection_chats_agent_user_id_idx
  on public.selection_chats (agent_user_id);

create index if not exists selection_chat_messages_chat_created_idx
  on public.selection_chat_messages (chat_id, created_at);

create index if not exists selection_chat_reactions_chat_idx
  on public.selection_chat_message_reactions (chat_id);

create index if not exists app_notifications_user_created_idx
  on public.app_notifications (user_id, created_at desc);

alter table public.selection_chats enable row level security;
alter table public.selection_chat_messages enable row level security;
alter table public.selection_chat_message_reactions enable row level security;
alter table public.app_notifications enable row level security;

drop policy if exists "Selection chat participants can view chats"
  on public.selection_chats;

create policy "Selection chat participants can view chats"
  on public.selection_chats
  for select
  to authenticated
  using (
    auth.uid() = model_user_id
    or auth.uid() = agent_user_id
    or public.current_user_is_admin()
  );

drop policy if exists "Selection agents and invited models can create chats"
  on public.selection_chats;

create policy "Selection agents and invited models can create chats"
  on public.selection_chats
  for insert
  to authenticated
  with check (
    public.current_user_is_admin()
    or (
      auth.uid() = agent_user_id
      and public.current_user_can_create_selections()
      and exists (
        select 1
        from public.selections s
        where s.id = selection_chats.selection_id
          and s.created_by = auth.uid()
      )
    )
    or (
      auth.uid() = model_user_id
      and exists (
        select 1
        from public.selection_items si
        join public.profiles p on p.id = si.profile_id
        where si.selection_id = selection_chats.selection_id
          and si.profile_id = selection_chats.profile_id
          and p.user_id = auth.uid()
      )
    )
  );

drop policy if exists "Selection chat participants can update chats"
  on public.selection_chats;

create policy "Selection chat participants can update chats"
  on public.selection_chats
  for update
  to authenticated
  using (
    auth.uid() = model_user_id
    or auth.uid() = agent_user_id
    or public.current_user_is_admin()
  )
  with check (
    auth.uid() = model_user_id
    or auth.uid() = agent_user_id
    or public.current_user_is_admin()
  );

create or replace function public.hide_selection_chat_for_me(p_chat_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $hide_selection_chat_for_me$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.selection_chats
  set
    model_deleted_at = case
      when model_user_id = v_user_id then now()
      else model_deleted_at
    end,
    agent_deleted_at = case
      when agent_user_id = v_user_id then now()
      else agent_deleted_at
    end,
    updated_at = now()
  where id = p_chat_id
    and (model_user_id = v_user_id or agent_user_id = v_user_id);
end;
$hide_selection_chat_for_me$;

grant execute on function public.hide_selection_chat_for_me(uuid)
  to authenticated;

drop policy if exists "Selection chat participants can view messages"
  on public.selection_chat_messages;

create policy "Selection chat participants can view messages"
  on public.selection_chat_messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.selection_chats sc
      where sc.id = selection_chat_messages.chat_id
        and (
          auth.uid() = sc.model_user_id
          or auth.uid() = sc.agent_user_id
          or public.current_user_is_admin()
        )
    )
  );

drop policy if exists "Selection chat participants can send messages"
  on public.selection_chat_messages;

create policy "Selection chat participants can send messages"
  on public.selection_chat_messages
  for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and exists (
      select 1
      from public.selection_chats sc
      where sc.id = selection_chat_messages.chat_id
        and (
          auth.uid() = sc.model_user_id
          or auth.uid() = sc.agent_user_id
          or public.current_user_is_admin()
        )
    )
  );

drop policy if exists "Selection message senders can delete own messages"
  on public.selection_chat_messages;

create policy "Selection message senders can delete own messages"
  on public.selection_chat_messages
  for update
  to authenticated
  using (
    auth.uid() = sender_id
    or public.current_user_is_admin()
  )
  with check (
    auth.uid() = sender_id
    or public.current_user_is_admin()
  );

drop policy if exists "Selection chat participants can view reactions"
  on public.selection_chat_message_reactions;

create policy "Selection chat participants can view reactions"
  on public.selection_chat_message_reactions
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.selection_chats sc
      where sc.id = selection_chat_message_reactions.chat_id
        and (
          auth.uid() = sc.model_user_id
          or auth.uid() = sc.agent_user_id
          or public.current_user_is_admin()
        )
    )
  );

drop policy if exists "Selection chat participants can react"
  on public.selection_chat_message_reactions;

create policy "Selection chat participants can react"
  on public.selection_chat_message_reactions
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.selection_chats sc
      where sc.id = selection_chat_message_reactions.chat_id
        and (
          auth.uid() = sc.model_user_id
          or auth.uid() = sc.agent_user_id
          or public.current_user_is_admin()
        )
    )
  );

drop policy if exists "Selection users can update own reactions"
  on public.selection_chat_message_reactions;

create policy "Selection users can update own reactions"
  on public.selection_chat_message_reactions
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Selection users can delete own reactions"
  on public.selection_chat_message_reactions;

create policy "Selection users can delete own reactions"
  on public.selection_chat_message_reactions
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can view own app notifications"
  on public.app_notifications;

create policy "Users can view own app notifications"
  on public.app_notifications
  for select
  to authenticated
  using (auth.uid() = user_id and deleted_at is null);

drop policy if exists "Users can update own app notifications"
  on public.app_notifications;

create policy "Users can update own app notifications"
  on public.app_notifications
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own app notifications"
  on public.app_notifications;

create policy "Users can delete own app notifications"
  on public.app_notifications
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.notify_selection_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chat public.selection_chats%rowtype;
  v_recipient uuid;
  v_title text;
begin
  select * into v_chat
  from public.selection_chats
  where id = new.chat_id;

  if v_chat.id is null then
    return new;
  end if;

  if new.sender_id = v_chat.model_user_id then
    v_recipient := v_chat.agent_user_id;
  else
    v_recipient := v_chat.model_user_id;
  end if;

  if v_recipient is null or v_recipient = new.sender_id then
    return new;
  end if;

  select coalesce(title, 'Чат') into v_title
  from public.selections
  where id = v_chat.selection_id;

  insert into public.app_notifications (user_id, title, body, route)
  values (
    v_recipient,
    coalesce(v_title, 'Чат'),
    left(new.body, 180),
    '/chat/' || new.chat_id::text
  );

  return new;
end;
$$;

drop trigger if exists selection_chat_message_notify
  on public.selection_chat_messages;

create trigger selection_chat_message_notify
after insert on public.selection_chat_messages
for each row
execute function public.notify_selection_chat_message();

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'selection_chat_messages'
  ) then
    alter publication supabase_realtime
      add table public.selection_chat_messages;
  end if;

  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'selection_chat_message_reactions'
  ) then
    alter publication supabase_realtime
      add table public.selection_chat_message_reactions;
  end if;
end $$;
