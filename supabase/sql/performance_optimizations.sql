-- Performance optimizations for catalog, analytics, chat, and notifications.
-- Run this after the main marketplace/chat/profile SQL files.

create extension if not exists pg_trgm;

create index if not exists profiles_status_profile_type_id_idx
  on public.profiles (status, profile_type, id);

create index if not exists profiles_user_id_id_idx
  on public.profiles (user_id, id);

create index if not exists profiles_status_full_name_trgm_idx
  on public.profiles using gin (full_name gin_trgm_ops)
  where status = 'approved';

create index if not exists profiles_status_city_trgm_idx
  on public.profiles using gin (city gin_trgm_ops)
  where status = 'approved';

create index if not exists profiles_status_country_trgm_idx
  on public.profiles using gin (country gin_trgm_ops)
  where status = 'approved';

create index if not exists profiles_status_eye_color_trgm_idx
  on public.profiles using gin (eye_color gin_trgm_ops)
  where status = 'approved';

create index if not exists profiles_status_hair_color_trgm_idx
  on public.profiles using gin (hair_color gin_trgm_ops)
  where status = 'approved';

create index if not exists profiles_status_age_height_idx
  on public.profiles (status, age, height);

create index if not exists profiles_status_body_sizes_idx
  on public.profiles (status, shoe_size, bust, waist, hips);

create index if not exists profiles_status_rates_idx
  on public.profiles (status, min_hourly_rate, min_daily_fee);

create index if not exists profile_analytics_profile_event_created_idx
  on public.profile_analytics_events (profile_id, event_type, created_at desc);

create index if not exists selection_items_profile_created_visible_idx
  on public.selection_items (profile_id, created_at desc)
  where model_hidden_at is null;

create index if not exists selection_chats_profile_created_idx
  on public.selection_chats (profile_id, created_at desc);

create index if not exists selection_chat_messages_chat_created_desc_idx
  on public.selection_chat_messages (chat_id, created_at desc);

create index if not exists selection_chat_reactions_chat_updated_idx
  on public.selection_chat_message_reactions (chat_id, updated_at desc);

create index if not exists app_notifications_user_visible_created_idx
  on public.app_notifications (user_id, created_at desc)
  where deleted_at is null;

create index if not exists castings_created_at_idx
  on public.castings (created_at desc);

create index if not exists casting_responses_user_created_idx
  on public.casting_responses (user_id, created_at desc);

create index if not exists casting_agent_applications_status_created_idx
  on public.casting_agent_applications (status, created_at desc);

create or replace function public.get_my_profile_analytics()
returns table (
  profile_count int,
  views int,
  selection_adds int,
  invitations int,
  last_event_at timestamptz
)
language sql
security definer
set search_path = public
set row_security = off
as $get_my_profile_analytics$
  with my_profiles as (
    select id
    from public.profiles
    where user_id = auth.uid()
  ),
  event_summary as (
    select
      count(*) filter (where event_type = 'profile_view')::int as views,
      max(created_at) as last_event_at
    from public.profile_analytics_events
    where profile_id in (select id from my_profiles)
  ),
  selection_summary as (
    select count(*)::int as selection_adds
    from public.selection_items
    where profile_id in (select id from my_profiles)
      and model_hidden_at is null
  ),
  invitation_summary as (
    select count(*)::int as invitations
    from public.selection_chats
    where profile_id in (select id from my_profiles)
  )
  select
    (select count(*)::int from my_profiles) as profile_count,
    coalesce((select views from event_summary), 0) as views,
    coalesce((select selection_adds from selection_summary), 0) as selection_adds,
    coalesce((select invitations from invitation_summary), 0) as invitations,
    (select last_event_at from event_summary) as last_event_at;
$get_my_profile_analytics$;

grant execute on function public.get_my_profile_analytics()
  to authenticated;

create or replace function public.get_my_selection_invitations()
returns table (
  selection_id uuid,
  profile_id uuid,
  model_user_id uuid,
  created_at timestamptz,
  selection_title text,
  request_video_intro boolean,
  video_intro_requirements text,
  profile_name text,
  photo_urls text[]
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $get_my_selection_invitations$
  select
    si.selection_id,
    si.profile_id,
    p.user_id as model_user_id,
    si.created_at,
    coalesce(s.title, '') as selection_title,
    coalesce(s.request_video_intro, false) as request_video_intro,
    coalesce(s.video_intro_requirements, '') as video_intro_requirements,
    coalesce(p.full_name, '') as profile_name,
    coalesce(p.photo_urls, array[]::text[]) as photo_urls
  from public.selection_items si
  join public.profiles p on p.id = si.profile_id
  join public.selections s on s.id = si.selection_id
  where p.user_id = auth.uid()
    and si.model_hidden_at is null
  order by si.created_at desc
  limit 100;
$get_my_selection_invitations$;

grant execute on function public.get_my_selection_invitations()
  to authenticated;
