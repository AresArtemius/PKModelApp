-- Profile submission and moderation fix for PK ModelApp.
-- Run this whole file in Supabase SQL Editor.

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id::text = auth.uid()::text
      and lower(role) = 'admin'
  )
  or exists (
    select 1
    from public.user_profiles
    where user_id::text = auth.uid()::text
      and lower(account_type) in ('admin', 'moderator', 'support')
  );
$$;

grant execute on function public.current_user_is_admin() to authenticated;

alter table public.profiles
  add column if not exists profile_type text not null default 'model',
  add column if not exists experience text not null default '',
  add column if not exists skills text not null default '',
  add column if not exists services text not null default '',
  add column if not exists genres text not null default '',
  add column if not exists equipment text not null default '',
  add column if not exists pending_photo_urls text[] not null default '{}',
  add column if not exists pending_video_urls text[] not null default '{}',
  add column if not exists pending_video_preview_urls text[] not null default '{}',
  add column if not exists has_pending_media boolean not null default false;

update public.profiles
set profile_type = 'model'
where profile_type is null or btrim(profile_type) = '';

create index if not exists profiles_user_id_id_idx
  on public.profiles (user_id, id);

create index if not exists profiles_status_profile_type_id_idx
  on public.profiles (status, profile_type, id);

alter table public.profiles enable row level security;

drop policy if exists "profiles_public_read_approved" on public.profiles;
create policy "profiles_public_read_approved"
  on public.profiles
  for select
  to anon, authenticated
  using (status = 'approved');

drop policy if exists "profiles_owner_read_own" on public.profiles;
create policy "profiles_owner_read_own"
  on public.profiles
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "profiles_admin_read_all" on public.profiles;
create policy "profiles_admin_read_all"
  on public.profiles
  for select
  to authenticated
  using (public.current_user_is_admin());

drop policy if exists "profiles_owner_insert_own" on public.profiles;
create policy "profiles_owner_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "profiles_owner_update_own" on public.profiles;
create policy "profiles_owner_update_own"
  on public.profiles
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "profiles_admin_update_all" on public.profiles;
create policy "profiles_admin_update_all"
  on public.profiles
  for update
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

create or replace function public.submit_profile_for_review(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set status = 'pending',
      moderation_comment = null
  where id = p_profile_id
    and user_id = auth.uid();

  if not found then
    raise exception 'Profile not found or access denied';
  end if;
end;
$$;

grant execute on function public.submit_profile_for_review(uuid) to authenticated;

create or replace function public.pending_profiles_for_moderation()
returns table (
  id uuid,
  full_name text,
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
  video_urls text[],
  video_preview_urls text[],
  pending_photo_urls text[],
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
    p.status,
    p.moderation_comment,
    p.is_verified,
    p.verification_status,
    p.photo_urls,
    p.video_urls,
    p.video_preview_urls,
    p.pending_photo_urls,
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

create or replace function public.profile_moderation_status_counts()
returns table (
  status text,
  count bigint
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
    coalesce(nullif(btrim(p.status), ''), 'empty') as status,
    count(*)::bigint as count
  from public.profiles p
  group by coalesce(nullif(btrim(p.status), ''), 'empty')
  order by status;
end;
$$;

grant execute on function public.profile_moderation_status_counts()
  to authenticated;

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
