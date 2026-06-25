-- Emergency reset for profile approval functions.
-- Run this whole file in Supabase SQL Editor if moderation approval returns:
-- invalid input value for enum profile_status: "".

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure::text as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('approve_profile', 'admin_publish_profile')
  loop
    execute format('drop function if exists %s cascade', fn.signature);
  end loop;
end $$;

create or replace function public.admin_publish_profile(p_profile_id uuid)
returns setof public.profiles
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can publish profiles';
  end if;

  return query
  update public.profiles p
  set status = 'approved',
      moderation_comment = null,
      photo_urls = coalesce(p.photo_urls, '{}')
        || coalesce(p.pending_photo_urls, '{}'),
      video_urls = coalesce(p.video_urls, '{}')
        || coalesce(p.pending_video_urls, '{}'),
      video_preview_urls = coalesce(p.video_preview_urls, '{}')
        || coalesce(p.pending_video_preview_urls, '{}'),
      pending_photo_urls = '{}',
      pending_video_urls = '{}',
      pending_video_preview_urls = '{}',
      has_pending_media = false
  where p.id = p_profile_id
  returning p.*;

  if not found then
    raise exception 'Profile not found';
  end if;
end;
$$;

grant execute on function public.admin_publish_profile(uuid) to authenticated;

create or replace function public.admin_publish_profile(p_profile_id text)
returns setof public.profiles
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  return query
  select *
  from public.admin_publish_profile(p_profile_id::uuid);
end;
$$;

grant execute on function public.admin_publish_profile(text) to authenticated;

create or replace function public.approve_profile(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  perform 1
  from public.admin_publish_profile(p_profile_id);
end;
$$;

grant execute on function public.approve_profile(uuid) to authenticated;

create or replace function public.approve_profile(p_profile_id text)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  perform 1
  from public.admin_publish_profile(p_profile_id::uuid);
end;
$$;

grant execute on function public.approve_profile(text) to authenticated;
