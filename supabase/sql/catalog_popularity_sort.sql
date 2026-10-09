-- Catalogue sort «Популярные» (leftover of step 20в).
-- Adds a `popularity` column to the catalog_profiles view: profile views
-- over the last 30 days plus selection adds (×3) from
-- profile_analytics_events. Run in the Supabase SQL Editor after
-- profile_billing_mvp.sql and
-- marketplace_pipeline_notifications_safety_analytics.sql. Safe to re-run.
--
-- `create or replace view` cannot add columns in the middle, so the view is
-- dropped and recreated with the same grants.

drop view if exists public.catalog_profiles;

create view public.catalog_profiles
with (security_invoker = false, security_barrier = true)
as
select
  p.*,
  coalesce(pop.score, 0)::int as popularity
from public.profiles p
left join lateral (
  select
    (count(*) filter (where e.event_type = 'profile_view'))
    + 3 * (count(*) filter (where e.event_type = 'selection_add')) as score
  from public.profile_analytics_events e
  where e.profile_id = p.id
    and e.created_at > now() - interval '30 days'
) pop on true
where p.status = 'approved'
  and public.profile_billing_is_active(p.id);

grant select on public.catalog_profiles to anon, authenticated;
