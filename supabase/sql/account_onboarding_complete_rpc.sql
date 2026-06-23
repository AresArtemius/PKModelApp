-- Robust role onboarding RPC.
-- Fixes cases where the app cannot save account_type because of RLS/policies.

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  phone text,
  full_name text,
  avatar_url text,
  auth_provider text,
  account_type text not null default 'user',
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

alter table public.user_profiles
  add column if not exists account_type text not null default 'user',
  add column if not exists onboarding_completed_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists last_seen_at timestamptz not null default now();

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.casting_agent_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  comment text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null
);

create unique index if not exists casting_agent_applications_one_pending_idx
  on public.casting_agent_applications (user_id)
  where status = 'pending';

create or replace function public.normalize_account_type(p_value text)
returns text
language sql
immutable
as $$
  select case lower(btrim(coalesce(p_value, '')))
    when 'model' then 'model'
    when 'actor' then 'actor'
    when 'casting_agent' then 'casting_agent'
    when 'brand' then 'brand'
    when 'photographer' then 'photographer'
    when 'videographer' then 'videographer'
    when 'stylist' then 'stylist'
    when 'makeup_artist' then 'makeup_artist'
    when 'hair_stylist' then 'hair_stylist'
    when 'agency' then 'agency'
    else 'user'
  end;
$$;

create or replace function public.complete_account_onboarding(
  p_account_type text
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user_id uuid := auth.uid();
  v_account_type text := public.normalize_account_type(p_account_type);
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.user_profiles (
    user_id,
    account_type,
    onboarding_completed_at,
    updated_at,
    last_seen_at
  )
  values (
    v_user_id,
    v_account_type,
    now(),
    now(),
    now()
  )
  on conflict (user_id)
  do update set
    account_type = excluded.account_type,
    onboarding_completed_at = excluded.onboarding_completed_at,
    updated_at = now(),
    last_seen_at = now();

  insert into public.user_roles (user_id, role, updated_at)
  values (v_user_id, 'user', now())
  on conflict (user_id)
  do nothing;

  if v_account_type = 'casting_agent' then
    insert into public.casting_agent_applications (
      user_id,
      status,
      updated_at
    )
    values (
      v_user_id,
      'pending',
      now()
    )
    on conflict do nothing;
  end if;
end;
$$;

grant execute on function public.complete_account_onboarding(text)
  to authenticated;

notify pgrst, 'reload schema';
