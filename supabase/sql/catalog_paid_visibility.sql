-- Enforce paid catalog visibility while keeping admin-owned profiles free.
-- Apply after profile_billing_mvp.sql.
-- Owners still see their own profiles through profiles_owner_read_own;
-- admins still see everything through profiles_admin_read_all.

create or replace function public.profile_billing_is_active(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.billing_profile_subscriptions s
    where s.profile_id = p_profile_id
      and s.status in ('trial_active', 'active_paid')
      and s.current_period_end > now()
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = p_profile_id
      and (
        exists (
          select 1
          from public.user_roles ur
          where ur.user_id = p.user_id
            and lower(ur.role) = 'admin'
        )
        or exists (
          select 1
          from public.user_profiles up
          where up.user_id = p.user_id
            and lower(coalesce(up.account_type, '')) in (
              'admin',
              'moderator',
              'support'
            )
        )
      )
  );
$$;

grant execute on function public.profile_billing_is_active(uuid)
  to anon, authenticated;

create or replace view public.billing_entitlements as
select
  s.profile_id,
  s.user_id,
  s.status,
  s.source,
  s.product_id,
  bp.code as product_code,
  bp.duration_months,
  s.current_period_start,
  s.current_period_end,
  (
    s.status in ('trial_active', 'active_paid')
    and s.current_period_end is not null
    and s.current_period_end > now()
  ) as is_active,
  s.updated_at
from public.billing_profile_subscriptions s
left join public.billing_products bp on bp.id = s.product_id
union all
select
  p.id as profile_id,
  p.user_id,
  'admin_free'::text as status,
  'admin'::text as source,
  null::uuid as product_id,
  null::text as product_code,
  null::int as duration_months,
  null::timestamptz as current_period_start,
  null::timestamptz as current_period_end,
  true as is_active,
  p.updated_at
from public.profiles p
where not exists (
    select 1
    from public.billing_profile_subscriptions s
    where s.profile_id = p.id
  )
  and (
    exists (
      select 1
      from public.user_roles ur
      where ur.user_id = p.user_id
        and lower(ur.role) = 'admin'
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = p.user_id
        and lower(coalesce(up.account_type, '')) in (
          'admin',
          'moderator',
          'support'
        )
    )
  );

alter view public.billing_entitlements set (security_invoker = true);
grant select on public.billing_entitlements to authenticated;

drop policy if exists "profiles_public_read_approved" on public.profiles;
create policy "profiles_public_read_approved"
  on public.profiles
  for select
  to anon, authenticated
  using (
    status = 'approved'
    and public.profile_billing_is_active(id)
  );

create or replace view public.catalog_profiles
with (security_invoker = false, security_barrier = true)
as
select p.*
from public.profiles p
where p.status = 'approved'
  and public.profile_billing_is_active(p.id);

grant select on public.catalog_profiles to anon, authenticated;
