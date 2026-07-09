-- Public account handles such as @artemkukhar.
-- Run after user_profiles/account_public_roles SQL.

alter table public.user_profiles
  add column if not exists account_tag text;

alter table public.user_profiles
  add column if not exists account_tag_visibility text not null default 'public';

alter table public.user_profiles
  drop constraint if exists user_profiles_account_tag_visibility_check;

alter table public.user_profiles
  add constraint user_profiles_account_tag_visibility_check
  check (account_tag_visibility in ('public', 'conversations', 'hidden'));

update public.user_profiles
set account_tag = nullif(
  regexp_replace(
    lower(regexp_replace(btrim(coalesce(account_tag, '')), '^@', '')),
    '[^a-z0-9._-]',
    '',
    'g'
  ),
  ''
)
where account_tag is not null;

create unique index if not exists user_profiles_account_tag_lower_idx
  on public.user_profiles (lower(account_tag))
  where account_tag is not null and btrim(account_tag) <> '';

create or replace function public.save_account_profile(p_profile jsonb)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $save_account_profile$
declare
  v_user_id uuid := auth.uid();
  v_account_tag text := nullif(
    regexp_replace(
      lower(regexp_replace(btrim(coalesce(p_profile ->> 'account_tag', '')), '^@', '')),
      '[^a-z0-9._-]',
      '',
      'g'
    ),
    ''
  );
  v_account_tag_visibility text := coalesce(
    nullif(btrim(coalesce(p_profile ->> 'account_tag_visibility', '')), ''),
    'public'
  );
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_account_tag_visibility not in ('public', 'conversations', 'hidden') then
    v_account_tag_visibility := 'public';
  end if;

  insert into public.user_profiles (
    user_id,
    email,
    phone,
    account_tag,
    account_tag_visibility,
    avatar_url,
    full_name,
    company_name,
    position,
    city,
    country,
    website,
    social_url,
    bio,
    updated_at,
    last_seen_at
  )
  values (
    v_user_id,
    nullif(btrim(coalesce(p_profile ->> 'email', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'phone', '')), ''),
    v_account_tag,
    v_account_tag_visibility,
    nullif(btrim(coalesce(p_profile ->> 'avatar_url', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'full_name', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'company_name', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'position', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'city', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'country', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'website', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'social_url', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'bio', '')), ''),
    now(),
    now()
  )
  on conflict (user_id)
  do update set
    email = excluded.email,
    phone = excluded.phone,
    account_tag = excluded.account_tag,
    account_tag_visibility = excluded.account_tag_visibility,
    avatar_url = excluded.avatar_url,
    full_name = excluded.full_name,
    company_name = excluded.company_name,
    position = excluded.position,
    city = excluded.city,
    country = excluded.country,
    website = excluded.website,
    social_url = excluded.social_url,
    bio = excluded.bio,
    updated_at = now(),
    last_seen_at = now();
end;
$save_account_profile$;

grant execute on function public.save_account_profile(jsonb) to authenticated;

create or replace function public.get_public_account_profile(p_account_tag text)
returns table (
  user_id uuid,
  account_tag text,
  avatar_url text,
  full_name text,
  company_name text,
  position text,
  account_type text,
  city text,
  country text,
  website text,
  social_url text,
  bio text
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $get_public_account_profile$
  select
    up.user_id,
    up.account_tag,
    up.avatar_url,
    up.full_name,
    up.company_name,
    up.position,
    up.account_type,
    up.city,
    up.country,
    up.website,
    up.social_url,
    up.bio
  from public.user_profiles up
  where lower(up.account_tag) = lower(
    nullif(
      regexp_replace(
        lower(regexp_replace(btrim(coalesce(p_account_tag, '')), '^@', '')),
        '[^a-z0-9._-]',
        '',
        'g'
      ),
      ''
    )
  )
    and up.account_tag_visibility = 'public'
    and nullif(btrim(coalesce(up.account_tag, '')), '') is not null
  limit 1;
$get_public_account_profile$;

grant execute on function public.get_public_account_profile(text)
  to anon, authenticated;
