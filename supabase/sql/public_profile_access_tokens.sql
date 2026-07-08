-- Tokenized public profile links for client PDFs/selections.
-- Run in Supabase SQL Editor before relying on tokenized PDF links in production.

create extension if not exists pgcrypto;

create table if not exists public.public_profile_access_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  token_hash text not null unique,
  source text not null default 'pdf',
  related_id text not null default '',
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days',
  revoked_at timestamptz
);

alter table public.public_profile_access_tokens
  add column if not exists profile_id uuid references public.profiles(id) on delete cascade,
  add column if not exists token_hash text not null default '',
  add column if not exists source text not null default 'pdf',
  add column if not exists related_id text not null default '',
  add column if not exists created_by_user_id uuid references auth.users(id) on delete set null,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists expires_at timestamptz not null default now() + interval '30 days',
  add column if not exists revoked_at timestamptz;

create unique index if not exists public_profile_access_tokens_hash_idx
  on public.public_profile_access_tokens (token_hash);

create index if not exists public_profile_access_tokens_profile_idx
  on public.public_profile_access_tokens (profile_id, expires_at desc);

create index if not exists public_profile_access_tokens_related_idx
  on public.public_profile_access_tokens (source, related_id);

alter table public.public_profile_access_tokens enable row level security;

drop policy if exists "Admins can view public profile access tokens"
  on public.public_profile_access_tokens;

create policy "Admins can view public profile access tokens"
  on public.public_profile_access_tokens
  for select
  to authenticated
  using (public.current_user_is_admin());

drop policy if exists "Admins can revoke public profile access tokens"
  on public.public_profile_access_tokens;

create policy "Admins can revoke public profile access tokens"
  on public.public_profile_access_tokens
  for update
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

create or replace function public.create_public_profile_access_token(
  p_profile_id uuid,
  p_source text default 'pdf',
  p_related_id text default '',
  p_expires_in interval default interval '30 days'
)
returns text
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_token text;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can create public profile access tokens';
  end if;

  if not exists (select 1 from public.profiles where id = p_profile_id) then
    raise exception 'Profile not found';
  end if;

  v_token := encode(gen_random_bytes(32), 'hex');

  insert into public.public_profile_access_tokens (
    profile_id,
    token_hash,
    source,
    related_id,
    created_by_user_id,
    expires_at
  )
  values (
    p_profile_id,
    encode(digest(v_token, 'sha256'), 'hex'),
    coalesce(nullif(btrim(p_source), ''), 'pdf'),
    coalesce(p_related_id, ''),
    auth.uid(),
    now() + coalesce(p_expires_in, interval '30 days')
  );

  return v_token;
end;
$$;

grant execute on function public.create_public_profile_access_token(
  uuid,
  text,
  text,
  interval
) to authenticated;

create or replace function public.get_public_profile_by_access_token(
  p_profile_id uuid,
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_profile jsonb;
begin
  if coalesce(btrim(p_token), '') = '' then
    return null;
  end if;

  if not exists (
    select 1
    from public.public_profile_access_tokens t
    where t.profile_id = p_profile_id
      and t.token_hash = encode(digest(btrim(p_token), 'sha256'), 'hex')
      and t.revoked_at is null
      and t.expires_at > now()
  ) then
    return null;
  end if;

  select jsonb_build_object(
    'id', p.id,
    'user_id', p.user_id,
    'full_name', p.full_name,
    'status', p.status,
    'birth_date', p.birth_date,
    'age', p.age,
    'height', p.height,
    'bust', p.bust,
    'waist', p.waist,
    'hips', p.hips,
    'shoe_size', p.shoe_size,
    'eye_color', p.eye_color,
    'hair_color', p.hair_color,
    'country', p.country,
    'city', p.city,
    'resume', p.resume,
    'photo_urls', p.photo_urls,
    'video_urls', p.video_urls,
    'video_preview_urls', p.video_preview_urls,
    'unavailable_days', p.unavailable_days,
    'min_hourly_rate', p.min_hourly_rate,
    'min_daily_fee', p.min_daily_fee,
    'profile_type', p.profile_type,
    'profile_roles', p.profile_roles,
    'experience', p.experience,
    'skills', p.skills,
    'services', p.services,
    'genres', p.genres,
    'equipment', p.equipment,
    'is_pro', p.is_pro,
    'pro_until', p.pro_until,
    'is_verified', p.is_verified,
    'cover_photo_url', p.cover_photo_url,
    'cover_photo_focal_x', p.cover_photo_focal_x,
    'cover_photo_focal_y', p.cover_photo_focal_y,
    'showreel_url', p.showreel_url,
    'showreel_preview_url', p.showreel_preview_url,
    'photo_category_labels', p.photo_category_labels,
    'video_category_labels', p.video_category_labels
  )
  into v_profile
  from public.profiles p
  where p.id = p_profile_id;

  return v_profile;
end;
$$;

grant execute on function public.get_public_profile_by_access_token(uuid, text)
  to anon, authenticated;
