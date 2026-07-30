-- Allows an administrator to explicitly hide an admin-owned profile.
-- Admin-owned profiles remain free by default, but a manual canceled
-- subscription created by admin_revoke_profile_billing takes precedence.

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
    join public.user_roles ur on ur.user_id = p.user_id
    where p.id = p_profile_id
      and lower(ur.role) = 'admin'
      and not exists (
        select 1
        from public.billing_profile_subscriptions disabled
        where disabled.profile_id = p.id
          and disabled.status = 'canceled'
          and disabled.source = 'manual'
      )
  );
$$;

grant execute on function public.profile_billing_is_active(uuid)
  to anon, authenticated;

notify pgrst, 'reload schema';
