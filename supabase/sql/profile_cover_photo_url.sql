-- Stable cover photo support for PK ModelApp profiles.
-- Run this whole file in Supabase SQL Editor.

alter table public.profiles
  add column if not exists cover_photo_url text not null default '',
  add column if not exists pending_cover_photo_url text not null default '';

create or replace function public.resolve_profile_cover_photo(
  p_preferred text,
  p_photo_urls text[]
)
returns text
language sql
immutable
as $$
  select coalesce(
    (
      select url
      from unnest(coalesce(p_photo_urls, '{}'::text[])) as url
      where btrim(url) <> ''
        and url = btrim(coalesce(p_preferred, ''))
      limit 1
    ),
    (
      select url
      from unnest(coalesce(p_photo_urls, '{}'::text[])) as url
      where btrim(url) <> ''
      limit 1
    ),
    ''
  );
$$;

update public.profiles
set cover_photo_url = public.resolve_profile_cover_photo(
      cover_photo_url,
      photo_urls
    )
where btrim(coalesce(cover_photo_url, '')) = ''
  and coalesce(array_length(photo_urls, 1), 0) > 0;

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
      cover_photo_url = public.resolve_profile_cover_photo(
        coalesce(nullif(btrim(p.pending_cover_photo_url), ''), p.cover_photo_url),
        coalesce(p.photo_urls, '{}') || coalesce(p.pending_photo_urls, '{}')
      ),
      video_urls = coalesce(p.video_urls, '{}')
        || coalesce(p.pending_video_urls, '{}'),
      video_preview_urls = coalesce(p.video_preview_urls, '{}')
        || coalesce(p.pending_video_preview_urls, '{}'),
      pending_photo_urls = '{}',
      pending_cover_photo_url = '',
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

drop function if exists public.pending_profiles_for_moderation();

create or replace function public.pending_profiles_for_moderation()
returns table (
  id uuid,
  full_name text,
  birth_date date,
  age integer,
  height integer,
  bust integer,
  waist integer,
  hips integer,
  shoe_size integer,
  eye_color text,
  hair_color text,
  country text,
  city text,
  resume text,
  unavailable_days text[],
  is_available boolean,
  status text,
  moderation_comment text,
  is_verified boolean,
  verification_status text,
  photo_urls text[],
  cover_photo_url text,
  video_urls text[],
  video_preview_urls text[],
  pending_photo_urls text[],
  pending_cover_photo_url text,
  pending_video_urls text[],
  pending_video_preview_urls text[],
  has_pending_media boolean
)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can view profile moderation';
  end if;

  return query
  select
    p.id,
    p.full_name,
    p.birth_date,
    p.age,
    p.height,
    p.bust,
    p.waist,
    p.hips,
    p.shoe_size,
    p.eye_color,
    p.hair_color,
    p.country,
    p.city,
    p.resume,
    p.unavailable_days,
    p.is_available,
    p.status::text,
    p.moderation_comment,
    p.is_verified,
    p.verification_status,
    p.photo_urls,
    p.cover_photo_url,
    p.video_urls,
    p.video_preview_urls,
    p.pending_photo_urls,
    p.pending_cover_photo_url,
    p.pending_video_urls,
    p.pending_video_preview_urls,
    p.has_pending_media
  from public.profiles p
  where p.status = 'pending'
  order by p.id desc
  limit 200;
end;
$$;

grant execute on function public.pending_profiles_for_moderation()
  to authenticated;
