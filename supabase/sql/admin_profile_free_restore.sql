-- Adds a reversible free-placement switch for admin-owned profiles.
-- Apply after profile_billing_mvp.sql and admin_profile_disable_override.sql.

alter table public.billing_profile_subscriptions
  drop constraint if exists billing_profile_subscriptions_source_check;

alter table public.billing_profile_subscriptions
  add constraint billing_profile_subscriptions_source_check
  check (
    source in (
      'manual',
      'trial',
      'yookassa',
      'cloudpayments',
      'system',
      'admin_disabled'
    )
  );

update public.billing_profile_subscriptions s
set source = 'admin_disabled',
    updated_at = now()
where s.status = 'canceled'
  and s.source = 'manual'
  and exists (
    select 1
    from public.profiles p
    join public.user_roles ur on ur.user_id = p.user_id
    where p.id = s.profile_id
      and lower(ur.role) = 'admin'
  );

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
          and disabled.source = 'admin_disabled'
      )
  );
$$;

grant execute on function public.profile_billing_is_active(uuid)
  to anon, authenticated;

create or replace function public.admin_restore_free_profile_billing(
  p_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_profile_title text := '';
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can restore profile billing';
  end if;

  select coalesce(nullif(p.full_name, ''), p.id::text)
  into v_profile_title
  from public.profiles p
  join public.user_roles ur on ur.user_id = p.user_id
  where p.id = p_profile_id
    and lower(ur.role) = 'admin'
  limit 1;

  if not found then
    raise exception 'Admin-owned profile not found';
  end if;

  delete from public.billing_profile_subscriptions
  where profile_id = p_profile_id
    and status = 'canceled'
    and source = 'admin_disabled';

  perform public.admin_record_backoffice_action(
    'profile_billing_restored',
    'Бесплатное размещение админской анкеты включено',
    '',
    'profiles',
    p_profile_id,
    v_profile_title,
    jsonb_build_object('profile_id', p_profile_id)
  );
end;
$$;

grant execute on function public.admin_restore_free_profile_billing(uuid)
  to authenticated;

create or replace function public.admin_revoke_profile_billing(
  p_profile_id uuid,
  p_admin_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_profile_title text := '';
  v_profile_user_id uuid;
  v_admin_owned boolean := false;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can revoke profile billing';
  end if;

  if p_profile_id is null then
    raise exception 'Profile id is required';
  end if;

  select p.user_id, coalesce(nullif(p.full_name, ''), p.id::text)
  into v_profile_user_id, v_profile_title
  from public.profiles p
  where p.id = p_profile_id
  limit 1;

  if not found then
    raise exception 'Profile not found';
  end if;

  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = v_profile_user_id
      and lower(ur.role) = 'admin'
  )
  into v_admin_owned;

  insert into public.billing_profile_subscriptions (
    profile_id,
    user_id,
    status,
    source,
    current_period_start,
    current_period_end,
    granted_by_user_id,
    admin_note,
    updated_at
  )
  values (
    p_profile_id,
    v_profile_user_id,
    'canceled',
    case when v_admin_owned then 'admin_disabled' else 'manual' end,
    now(),
    now(),
    auth.uid(),
    coalesce(p_admin_note, ''),
    now()
  )
  on conflict (profile_id) do update
  set status = 'canceled',
      source = excluded.source,
      current_period_end = now(),
      granted_by_user_id = auth.uid(),
      admin_note = excluded.admin_note,
      updated_at = now();

  perform public.admin_record_backoffice_action(
    'profile_billing_revoked',
    'Активное размещение анкеты отключено',
    coalesce(p_admin_note, ''),
    'profiles',
    p_profile_id,
    v_profile_title,
    jsonb_build_object(
      'profile_id', p_profile_id,
      'admin_note', coalesce(p_admin_note, '')
    )
  );
end;
$$;

grant execute on function public.admin_revoke_profile_billing(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';
