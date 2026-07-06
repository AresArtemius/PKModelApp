-- Profile media/schema guard for PK ModelApp.
-- Run this whole file in Supabase SQL Editor after app updates.
-- It is idempotent: safe to run more than once.

alter table public.profiles
  add column if not exists profile_type text not null default 'model',
  add column if not exists profile_roles text[] not null default array['model']::text[],
  add column if not exists experience text not null default '',
  add column if not exists skills text not null default '',
  add column if not exists services text not null default '',
  add column if not exists genres text not null default '',
  add column if not exists equipment text not null default '',
  add column if not exists birth_date date,
  add column if not exists unavailable_days text[] not null default '{}',
  add column if not exists is_verified boolean not null default false,
  add column if not exists verification_status text not null default 'none',
  add column if not exists verification_requested_at timestamptz,
  add column if not exists cover_photo_url text not null default '',
  add column if not exists pending_cover_photo_url text not null default '',
  add column if not exists cover_photo_focal_x double precision not null default 0,
  add column if not exists cover_photo_focal_y double precision not null default -0.72,
  add column if not exists pending_cover_photo_focal_x double precision not null default 0,
  add column if not exists pending_cover_photo_focal_y double precision not null default -0.72,
  add column if not exists photo_category_labels text[] not null default '{}',
  add column if not exists video_category_labels text[] not null default '{}',
  add column if not exists pending_photo_category_labels text[] not null default '{}',
  add column if not exists pending_video_category_labels text[] not null default '{}',
  add column if not exists showreel_url text not null default '',
  add column if not exists showreel_preview_url text not null default '',
  add column if not exists pending_showreel_url text not null default '',
  add column if not exists pending_showreel_preview_url text not null default '',
  add column if not exists pending_photo_urls text[] not null default '{}',
  add column if not exists pending_video_urls text[] not null default '{}',
  add column if not exists pending_video_preview_urls text[] not null default '{}',
  add column if not exists has_pending_media boolean not null default false;

update public.profiles
set
  profile_type = coalesce(nullif(btrim(profile_type), ''), 'model'),
  profile_roles = case
    when coalesce(array_length(profile_roles, 1), 0) = 0
      then array[coalesce(nullif(btrim(profile_type), ''), 'model')]
    else profile_roles
  end,
  cover_photo_focal_x = greatest(-1, least(1, coalesce(cover_photo_focal_x, 0))),
  cover_photo_focal_y = greatest(-1, least(1, coalesce(cover_photo_focal_y, -0.72))),
  pending_cover_photo_focal_x = greatest(-1, least(1, coalesce(pending_cover_photo_focal_x, 0))),
  pending_cover_photo_focal_y = greatest(-1, least(1, coalesce(pending_cover_photo_focal_y, -0.72)));

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
set cover_photo_url = public.resolve_profile_cover_photo(cover_photo_url, photo_urls)
where btrim(coalesce(cover_photo_url, '')) = ''
  and coalesce(array_length(photo_urls, 1), 0) > 0;

insert into storage.buckets (id, name, public)
values ('profile-media', 'profile-media', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "profile_media_public_read" on storage.objects;
create policy "profile_media_public_read"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'profile-media');

drop policy if exists "profile_media_owner_insert" on storage.objects;
create policy "profile_media_owner_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "profile_media_owner_update" on storage.objects;
create policy "profile_media_owner_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "profile_media_owner_delete" on storage.objects;
create policy "profile_media_owner_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_profile_roles_check'
  ) then
    alter table public.profiles
      add constraint profiles_profile_roles_check
      check (
        array_length(profile_roles, 1) > 0
        and profile_roles <@ array[
          'model',
          'actor',
          'photographer',
          'videographer',
          'stylist',
          'makeup_artist',
          'hair_stylist'
        ]::text[]
      );
  end if;
end $$;

create index if not exists profiles_profile_roles_gin_idx
  on public.profiles using gin (profile_roles);
create index if not exists profiles_user_id_id_idx
  on public.profiles (user_id, id);
create index if not exists profiles_status_profile_type_id_idx
  on public.profiles (status, profile_type, id);
