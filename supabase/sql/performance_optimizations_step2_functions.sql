-- Step 2: functions only.
-- Run this whole file after performance_optimizations_step1_indexes.sql.

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
as $$
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
$$;

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
as $$
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
$$;

grant execute on function public.get_my_selection_invitations()
  to authenticated;
