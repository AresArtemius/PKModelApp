-- Chat backend v2: list in one request, delivery receipts, presence, live list.
-- Run after selection_chats.sql, selection_chat_read_typing.sql and
-- selection_chat_list_states.sql. Safe to run multiple times.
--
-- Б1. selection_chat_list(): the whole chat list in a single RPC
--     (chat, counterpart, last message, unread count, content flags),
--     indexes for the hot paths, and a trigger that bumps a chat to the top
--     when a message arrives.
-- Б2. delivered_at on messages + mark_selection_chats_delivered() so the
--     sender sees ✓ (sent) / ✓✓ (delivered) / ✓✓ black (read).
-- Б3. user_presence + touch_presence() for "в сети / был(а) в …".
-- Б4. selection_chats and user_presence in the realtime publication so the
--     chat list and presence update live.

-- ---------------------------------------------------------------------------
-- Б1. Indexes
-- ---------------------------------------------------------------------------

create index if not exists selection_chat_messages_chat_created_idx
  on public.selection_chat_messages (chat_id, created_at desc)
  where deleted_at is null;

create index if not exists selection_chat_messages_unread_idx
  on public.selection_chat_messages (chat_id, sender_id)
  where deleted_at is null and read_at is null;

create index if not exists selection_chats_model_user_idx
  on public.selection_chats (model_user_id, updated_at desc);

create index if not exists selection_chats_agent_user_idx
  on public.selection_chats (agent_user_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- Б1. New message → chat goes to the top (updated_at bump)
-- ---------------------------------------------------------------------------

create or replace function public.bump_selection_chat_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.selection_chats
  set updated_at = greatest(updated_at, coalesce(new.created_at, now()))
  where id = new.chat_id;
  return new;
end;
$$;

drop trigger if exists bump_selection_chat_updated_at
  on public.selection_chat_messages;
create trigger bump_selection_chat_updated_at
after insert on public.selection_chat_messages
for each row
execute function public.bump_selection_chat_updated_at();

-- ---------------------------------------------------------------------------
-- Б2. Delivery receipts
-- ---------------------------------------------------------------------------

alter table public.selection_chat_messages
  add column if not exists delivered_at timestamptz;

-- Called by the client when it receives messages (list open / chat open /
-- realtime insert): everything addressed to me in these chats is delivered.
create or replace function public.mark_selection_chats_delivered(
  p_chat_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if p_chat_ids is null or cardinality(p_chat_ids) = 0 then
    return;
  end if;

  update public.selection_chat_messages m
  set delivered_at = now()
  from public.selection_chats sc
  where m.chat_id = sc.id
    and m.chat_id = any (p_chat_ids)
    and m.sender_id <> v_user_id
    and m.deleted_at is null
    and m.delivered_at is null
    and (sc.model_user_id = v_user_id or sc.agent_user_id = v_user_id);
end;
$$;

grant execute on function public.mark_selection_chats_delivered(uuid[])
  to authenticated;

-- Reading implies delivery.
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
  set
    read_at = coalesce(read_at, now()),
    delivered_at = coalesce(delivered_at, now())
  where chat_id = p_chat_id
    and sender_id <> v_user_id
    and deleted_at is null
    and read_at is null;
end;
$mark_selection_chat_read$;

grant execute on function public.mark_selection_chat_read(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Б3. Presence
-- ---------------------------------------------------------------------------

create table if not exists public.user_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_online boolean not null default false,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_presence enable row level security;

drop policy if exists "Authenticated users can read presence"
  on public.user_presence;
create policy "Authenticated users can read presence"
  on public.user_presence
  for select
  to authenticated
  using (true);

-- Heartbeat: the client calls touch_presence(true) every ~30 s while the
-- app is in the foreground and touch_presence(false) when it goes away.
-- A row older than ~70 s is treated as offline by the client regardless.
create or replace function public.touch_presence(
  p_online boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.user_presence (user_id, is_online, last_seen_at, updated_at)
  values (v_user_id, coalesce(p_online, true), now(), now())
  on conflict (user_id) do update
  set
    is_online = excluded.is_online,
    last_seen_at = now(),
    updated_at = now();

  update public.user_profiles
  set last_seen_at = now()
  where user_id = v_user_id;
end;
$$;

grant execute on function public.touch_presence(boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Б1. Chat list in one request
-- ---------------------------------------------------------------------------

drop function if exists public.selection_chat_list(boolean);

create or replace function public.selection_chat_list(
  p_archived boolean default false
)
returns table (
  chat_id uuid,
  selection_id uuid,
  profile_id uuid,
  other_user_id uuid,
  is_model boolean,
  pinned boolean,
  archived boolean,
  created_at timestamptz,
  updated_at timestamptz,
  selection_title text,
  profile_full_name text,
  profile_photo_url text,
  other_has_account boolean,
  other_full_name text,
  other_company_name text,
  other_position text,
  other_avatar_url text,
  other_account_tag text,
  other_is_online boolean,
  other_last_seen_at timestamptz,
  last_message_id uuid,
  last_message_sender_id uuid,
  last_message_body text,
  last_message_media_type text,
  last_message_media_url text,
  last_message_file_name text,
  last_message_file_size bigint,
  last_message_file_mime text,
  last_message_metadata jsonb,
  last_message_read_at timestamptz,
  last_message_delivered_at timestamptz,
  last_message_listened_at timestamptz,
  last_message_pinned_at timestamptz,
  last_message_edited_at timestamptz,
  last_message_created_at timestamptz,
  unread_count int,
  has_media boolean,
  has_file boolean,
  has_audio boolean,
  has_pinned boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select auth.uid() as uid
  ),
  mine as (
    select
      sc.*,
      (sc.model_user_id = me.uid) as i_am_model,
      case
        when sc.model_user_id = me.uid then sc.agent_user_id
        else sc.model_user_id
      end as counterpart_id
    from public.selection_chats sc
    cross join me
    where me.uid is not null
      and (sc.model_user_id = me.uid or sc.agent_user_id = me.uid)
      and (
        case
          when sc.model_user_id = me.uid then sc.model_deleted_at
          else sc.agent_deleted_at
        end
      ) is null
      and (
        (
          case
            when sc.model_user_id = me.uid then sc.model_archived_at
            else sc.agent_archived_at
          end
        ) is not null
      ) = coalesce(p_archived, false)
  )
  select
    c.id as chat_id,
    c.selection_id,
    c.profile_id,
    c.counterpart_id as other_user_id,
    c.i_am_model as is_model,
    (case when c.i_am_model then c.model_pinned_at else c.agent_pinned_at end)
      is not null as pinned,
    (case when c.i_am_model then c.model_archived_at else c.agent_archived_at end)
      is not null as archived,
    c.created_at,
    c.updated_at,
    coalesce(s.title, '') as selection_title,
    coalesce(p.full_name, '') as profile_full_name,
    coalesce(
      nullif(btrim(p.cover_photo_url), ''),
      (
        select x
        from unnest(p.photo_urls) with ordinality as u(x, n)
        where btrim(x) <> ''
        order by n
        limit 1
      ),
      ''
    ) as profile_photo_url,
    (up.user_id is not null) as other_has_account,
    coalesce(up.full_name, '') as other_full_name,
    coalesce(up.company_name, '') as other_company_name,
    coalesce(up.position, '') as other_position,
    coalesce(up.avatar_url, '') as other_avatar_url,
    case
      when lower(coalesce(up.account_tag_visibility, 'public')) = 'hidden' then ''
      else coalesce(up.account_tag, '')
    end as other_account_tag,
    coalesce(
      pr.is_online and pr.last_seen_at > now() - interval '70 seconds',
      false
    ) as other_is_online,
    coalesce(pr.last_seen_at, up.last_seen_at) as other_last_seen_at,
    lm.id as last_message_id,
    lm.sender_id as last_message_sender_id,
    lm.body as last_message_body,
    coalesce(lm.media_type, 'text') as last_message_media_type,
    lm.media_url as last_message_media_url,
    lm.file_name as last_message_file_name,
    lm.file_size as last_message_file_size,
    lm.file_mime as last_message_file_mime,
    coalesce(lm.metadata, '{}'::jsonb) as last_message_metadata,
    lm.read_at as last_message_read_at,
    lm.delivered_at as last_message_delivered_at,
    lm.listened_at as last_message_listened_at,
    lm.pinned_at as last_message_pinned_at,
    lm.edited_at as last_message_edited_at,
    lm.created_at as last_message_created_at,
    coalesce(un.unread_count, 0)::int as unread_count,
    coalesce(fl.has_media, false) as has_media,
    coalesce(fl.has_file, false) as has_file,
    coalesce(fl.has_audio, false) as has_audio,
    coalesce(fl.has_pinned, false) as has_pinned
  from mine c
  cross join me
  left join public.selections s on s.id = c.selection_id
  left join public.profiles p on p.id = c.profile_id
  left join public.user_profiles up on up.user_id = c.counterpart_id
  left join public.user_presence pr on pr.user_id = c.counterpart_id
  left join lateral (
    select m.*
    from public.selection_chat_messages m
    where m.chat_id = c.id
      and m.deleted_at is null
    order by m.created_at desc
    limit 1
  ) lm on true
  left join lateral (
    select count(*) as unread_count
    from public.selection_chat_messages m
    where m.chat_id = c.id
      and m.deleted_at is null
      and m.read_at is null
      and m.sender_id <> me.uid
  ) un on true
  left join lateral (
    select
      bool_or(m.media_type <> 'text') as has_media,
      bool_or(m.media_type = 'file') as has_file,
      bool_or(m.media_type = 'audio') as has_audio,
      bool_or(m.pinned_at is not null) as has_pinned
    from public.selection_chat_messages m
    where m.chat_id = c.id
      and m.deleted_at is null
      and (m.media_type <> 'text' or m.pinned_at is not null)
  ) fl on true
  order by
    (case when c.i_am_model then c.model_pinned_at else c.agent_pinned_at end)
      is not null desc,
    coalesce(lm.created_at, c.updated_at, c.created_at) desc
  limit 200;
$$;

grant execute on function public.selection_chat_list(boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Б4. Realtime: chat list + presence
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'selection_chats'
  ) then
    alter publication supabase_realtime add table public.selection_chats;
  end if;

  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_presence'
  ) then
    alter publication supabase_realtime add table public.user_presence;
  end if;
end $$;
