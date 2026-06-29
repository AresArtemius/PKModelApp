-- Read receipts and typing indicators for selection chats.
-- Run after selection_chats.sql.

alter table public.selection_chat_messages
  add column if not exists read_at timestamptz;

create index if not exists selection_chat_messages_chat_read_idx
  on public.selection_chat_messages (chat_id, read_at);

create table if not exists public.selection_chat_typing_states (
  chat_id uuid not null references public.selection_chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  is_typing boolean not null default false,
  typed_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

alter table public.selection_chat_typing_states enable row level security;

drop policy if exists "Selection chat participants can view typing states"
  on public.selection_chat_typing_states;

create policy "Selection chat participants can view typing states"
  on public.selection_chat_typing_states
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.selection_chats sc
      where sc.id = selection_chat_typing_states.chat_id
        and (
          auth.uid() = sc.model_user_id
          or auth.uid() = sc.agent_user_id
          or public.current_user_is_admin()
        )
    )
  );

drop policy if exists "Selection chat participants can upsert own typing state"
  on public.selection_chat_typing_states;

create policy "Selection chat participants can upsert own typing state"
  on public.selection_chat_typing_states
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.selection_chats sc
      where sc.id = selection_chat_typing_states.chat_id
        and (
          auth.uid() = sc.model_user_id
          or auth.uid() = sc.agent_user_id
          or public.current_user_is_admin()
        )
    )
  );

drop policy if exists "Selection chat participants can update own typing state"
  on public.selection_chat_typing_states;

create policy "Selection chat participants can update own typing state"
  on public.selection_chat_typing_states
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.mark_selection_chat_read(p_chat_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $mark_selection_chat_read$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.selection_chats sc
    where sc.id = p_chat_id
      and (
        sc.model_user_id = v_user_id
        or sc.agent_user_id = v_user_id
        or public.current_user_is_admin()
      )
  ) then
    raise exception 'Chat not found or access denied';
  end if;

  update public.selection_chat_messages
  set read_at = coalesce(read_at, now())
  where chat_id = p_chat_id
    and sender_id <> v_user_id
    and deleted_at is null
    and read_at is null;
end;
$mark_selection_chat_read$;

grant execute on function public.mark_selection_chat_read(uuid)
  to authenticated;

create or replace function public.set_selection_chat_typing(
  p_chat_id uuid,
  p_is_typing boolean
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $set_selection_chat_typing$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.selection_chats sc
    where sc.id = p_chat_id
      and (
        sc.model_user_id = v_user_id
        or sc.agent_user_id = v_user_id
        or public.current_user_is_admin()
      )
  ) then
    raise exception 'Chat not found or access denied';
  end if;

  insert into public.selection_chat_typing_states (
    chat_id,
    user_id,
    is_typing,
    typed_at
  )
  values (
    p_chat_id,
    v_user_id,
    coalesce(p_is_typing, false),
    now()
  )
  on conflict (chat_id, user_id)
  do update set
    is_typing = excluded.is_typing,
    typed_at = now();
end;
$set_selection_chat_typing$;

grant execute on function public.set_selection_chat_typing(uuid, boolean)
  to authenticated;

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
      and tablename = 'selection_chat_typing_states'
  ) then
    alter publication supabase_realtime
      add table public.selection_chat_typing_states;
  end if;
end $$;
