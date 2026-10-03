-- Keep profiles.age in sync with birth_date, so catalog filters and the
-- filter bounds (which read the age column) match the age shown in the app
-- (which is computed from birth_date). Safe to run multiple times.
--
-- 1. age is recomputed from birth_date on every insert/update;
-- 2. a nightly pg_cron job advances ages after birthdays;
-- 3. the filter bounds accept ages 0–120 (babies to seniors) and heights
--    up to 250 cm.

create or replace function public.profile_age_from_birth_date(p_birth_date date)
returns int
language sql
immutable
as $$
  select case
    when p_birth_date is null then null
    else greatest(
      0,
      (date_part('year', age(current_date, p_birth_date)))::int
    )
  end;
$$;

create or replace function public.profiles_sync_age_from_birth_date()
returns trigger
language plpgsql
as $$
begin
  if new.birth_date is not null then
    new.age := public.profile_age_from_birth_date(new.birth_date);
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_sync_age_from_birth_date on public.profiles;
create trigger profiles_sync_age_from_birth_date
before insert or update of birth_date, age on public.profiles
for each row
execute function public.profiles_sync_age_from_birth_date();

-- One-off backfill of stale ages.
update public.profiles
set age = public.profile_age_from_birth_date(birth_date)
where birth_date is not null
  and age is distinct from public.profile_age_from_birth_date(birth_date);

-- Nightly refresh (03:10 UTC): birthdays move people to the next age.
create extension if not exists pg_cron;
do $$
begin
  perform cron.unschedule('profiles-refresh-age');
exception when others then
  null;
end;
$$;
select cron.schedule(
  'profiles-refresh-age',
  '10 3 * * *',
  $$
    update public.profiles
    set age = public.profile_age_from_birth_date(birth_date)
    where birth_date is not null
      and age is distinct from public.profile_age_from_birth_date(birth_date);
  $$
);

-- Bounds: widen the sanity caps (0–120 years, 20–250 cm).
create or replace function public.catalog_filter_bounds()
returns table (
  age_min int,
  age_max int,
  height_min int,
  height_max int,
  shoe_min int,
  shoe_max int,
  bust_min int,
  bust_max int,
  waist_min int,
  waist_max int,
  hips_min int,
  hips_max int,
  min_hourly_rate_min int,
  min_hourly_rate_max int,
  min_daily_fee_min int,
  min_daily_fee_max int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    (min(age) filter (where age between 0 and 120))::int,
    (max(age) filter (where age between 0 and 120))::int,
    (min(height) filter (where height between 20 and 250))::int,
    (max(height) filter (where height between 20 and 250))::int,
    (min(shoe_size) filter (where shoe_size between 5 and 55))::int,
    (max(shoe_size) filter (where shoe_size between 5 and 55))::int,
    (min(bust) filter (where bust between 30 and 160))::int,
    (max(bust) filter (where bust between 30 and 160))::int,
    (min(waist) filter (where waist between 30 and 150))::int,
    (max(waist) filter (where waist between 30 and 150))::int,
    (min(hips) filter (where hips between 30 and 160))::int,
    (max(hips) filter (where hips between 30 and 160))::int,
    (min(min_hourly_rate) filter (where min_hourly_rate >= 0))::int,
    (max(min_hourly_rate) filter (where min_hourly_rate >= 0))::int,
    (min(min_daily_fee) filter (where min_daily_fee >= 0))::int,
    (max(min_daily_fee) filter (where min_daily_fee >= 0))::int
  from public.catalog_profiles;
$$;

grant execute on function public.catalog_filter_bounds() to anon, authenticated;
