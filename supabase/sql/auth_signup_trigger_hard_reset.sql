-- Emergency fix for Supabase Auth sign-up error:
-- {"code":"unexpected_failure","message":"Database error saving new user"}
--
-- This removes custom non-internal triggers from auth.users and recreates one
-- safe profile/role sync trigger that never blocks user creation.

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
  add column if not exists email text,
  add column if not exists phone text,
  add column if not exists full_name text,
  add column if not exists avatar_url text,
  add column if not exists auth_provider text,
  add column if not exists account_type text not null default 'user',
  add column if not exists onboarding_completed_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists last_seen_at timestamptz not null default now();

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Drop every custom trigger on auth.users. Supabase internal FK triggers are
-- marked internal and are not touched by this block.
do $$
declare
  r record;
begin
  for r in
    select tgname
    from pg_trigger
    where tgrelid = 'auth.users'::regclass
      and not tgisinternal
  loop
    execute format('drop trigger if exists %I on auth.users', r.tgname);
  end loop;
end;
$$;

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

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_account_type text;
begin
  v_account_type := public.normalize_account_type(
    coalesce(
      v_meta ->> 'account_type',
      v_meta ->> 'requested_account_type',
      'user'
    )
  );

  begin
    insert into public.user_profiles (
      user_id,
      email,
      phone,
      full_name,
      avatar_url,
      auth_provider,
      account_type,
      updated_at,
      last_seen_at
    )
    values (
      new.id,
      new.email,
      new.phone,
      nullif(
        btrim(
          coalesce(
            v_meta ->> 'full_name',
            v_meta ->> 'name',
            v_meta ->> 'display_name',
            ''
          )
        ),
        ''
      ),
      nullif(
        btrim(coalesce(v_meta ->> 'avatar_url', v_meta ->> 'picture', '')),
        ''
      ),
      coalesce(new.raw_app_meta_data ->> 'provider', ''),
      v_account_type,
      now(),
      now()
    )
    on conflict (user_id)
    do update set
      email = excluded.email,
      phone = excluded.phone,
      full_name = coalesce(excluded.full_name, public.user_profiles.full_name),
      avatar_url = coalesce(
        excluded.avatar_url,
        public.user_profiles.avatar_url
      ),
      auth_provider = coalesce(
        nullif(excluded.auth_provider, ''),
        public.user_profiles.auth_provider
      ),
      updated_at = now(),
      last_seen_at = now();
  exception
    when others then
      raise warning 'user_profiles sync failed for %: %', new.id, sqlerrm;
  end;

  begin
    insert into public.user_roles (user_id, role, updated_at)
    values (new.id, 'user', now())
    on conflict (user_id)
    do nothing;
  exception
    when others then
      raise warning 'user_roles sync failed for %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Show the final active custom triggers. The result should contain only:
-- on_auth_user_created -> public.handle_new_user
select
  t.tgname as trigger_name,
  n.nspname as function_schema,
  p.proname as function_name
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
join pg_namespace n on n.oid = p.pronamespace
where t.tgrelid = 'auth.users'::regclass
  and not t.tgisinternal
order by t.tgname;

notify pgrst, 'reload schema';
