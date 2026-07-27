-- Dynamic advanced-search bounds based on valid published profile values.
-- Safe to run multiple times in Supabase SQL Editor.

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
    (min(age) filter (where age between 1 and 90))::int,
    (max(age) filter (where age between 1 and 90))::int,
    (min(height) filter (where height between 20 and 210))::int,
    (max(height) filter (where height between 20 and 210))::int,
    (min(shoe_size) filter (where shoe_size between 5 and 55))::int,
    (max(shoe_size) filter (where shoe_size between 5 and 55))::int,
    (min(bust) filter (where bust between 60 and 130))::int,
    (max(bust) filter (where bust between 60 and 130))::int,
    (min(waist) filter (where waist between 30 and 90))::int,
    (max(waist) filter (where waist between 30 and 90))::int,
    (min(hips) filter (where hips between 60 and 150))::int,
    (max(hips) filter (where hips between 60 and 150))::int,
    (min(min_hourly_rate) filter (where min_hourly_rate >= 0))::int,
    (max(min_hourly_rate) filter (where min_hourly_rate >= 0))::int,
    (min(min_daily_fee) filter (where min_daily_fee >= 0))::int,
    (max(min_daily_fee) filter (where min_daily_fee >= 0))::int
  from public.catalog_profiles;
$$;

grant execute on function public.catalog_filter_bounds() to authenticated, anon;
