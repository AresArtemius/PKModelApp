-- Server-side search across the full history of a selection chat.
-- Run after selection_chats.sql and selection_chat_voice_messages.sql.

alter table public.selection_chat_messages
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists read_at timestamptz,
  add column if not exists listened_at timestamptz,
  add column if not exists pinned_at timestamptz,
  add column if not exists pinned_by uuid references auth.users(id) on delete set null,
  add column if not exists file_name text,
  add column if not exists file_size bigint,
  add column if not exists file_mime text;

create index if not exists selection_chat_messages_chat_body_idx
  on public.selection_chat_messages (chat_id, lower(body));

create or replace function public.search_selection_chat_messages(
  p_chat_id uuid,
  p_query text,
  p_limit integer default 80
)
returns table (
  id uuid,
  chat_id uuid,
  sender_id uuid,
  body text,
  media_type text,
  media_url text,
  media_thumbnail_url text,
  deleted_at timestamptz,
  created_at timestamptz,
  read_at timestamptz,
  listened_at timestamptz,
  file_name text,
  file_size bigint,
  file_mime text,
  pinned_at timestamptz,
  pinned_by uuid,
  metadata jsonb
)
language plpgsql
security definer
set search_path = public
set row_security = off
as $search_selection_chat_messages$
declare
  v_user_id uuid := auth.uid();
  v_query text := lower(nullif(btrim(coalesce(p_query, '')), ''));
  v_limit integer := greatest(1, least(coalesce(p_limit, 80), 80));
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_query is null then
    return;
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

  return query
  select
    m.id,
    m.chat_id,
    m.sender_id,
    m.body,
    m.media_type,
    m.media_url,
    m.media_thumbnail_url,
    m.deleted_at,
    m.created_at,
    m.read_at,
    m.listened_at,
    m.file_name,
    m.file_size,
    m.file_mime,
    m.pinned_at,
    m.pinned_by,
    coalesce(m.metadata, '{}'::jsonb) as metadata
  from public.selection_chat_messages m
  where m.chat_id = p_chat_id
    and m.deleted_at is null
    and (
      lower(coalesce(m.body, '')) like '%' || v_query || '%'
      or lower(coalesce(m.file_name, '')) like '%' || v_query || '%'
      or lower(coalesce(m.file_mime, '')) like '%' || v_query || '%'
      or lower(coalesce(m.media_type, '')) like '%' || v_query || '%'
      or (
        m.media_type = 'audio'
        and (
          'голосовое' like '%' || v_query || '%'
          or 'voice audio' like '%' || v_query || '%'
        )
      )
      or (
        m.media_type = 'image'
        and (
          'фото изображение' like '%' || v_query || '%'
          or 'photo image' like '%' || v_query || '%'
        )
      )
      or (
        m.media_type = 'video'
        and 'видео video' like '%' || v_query || '%'
      )
    )
  order by m.created_at
  limit v_limit;
end;
$search_selection_chat_messages$;

grant execute on function public.search_selection_chat_messages(uuid, text, integer)
  to authenticated;
