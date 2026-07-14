-- MVP billing layer for paid active profile placement.
-- Run after auth/profile/admin role SQL.
-- The first launch flow is manual admin override; YooKassa webhooks can later
-- reuse the same orders/payments/subscriptions tables.

create table if not exists public.billing_products (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text not null default '',
  duration_months int not null check (duration_months in (1, 3, 6, 12)),
  price_minor int not null check (price_minor >= 0),
  currency text not null default 'RUB',
  is_active boolean not null default true,
  sort_order int not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.billing_products (
  code,
  title,
  description,
  duration_months,
  price_minor,
  currency,
  is_active,
  sort_order,
  metadata
)
values
  (
    'profile_active_1m',
    'Активная анкета на 1 месяц',
    'Размещение одной анкеты в активной базе PK Management на 1 месяц.',
    1,
    50000,
    'RUB',
    true,
    10,
    jsonb_build_object('saving_minor', 0)
  ),
  (
    'profile_active_3m',
    'Активная анкета на 3 месяца',
    'Размещение одной анкеты в активной базе PK Management на 3 месяца.',
    3,
    140000,
    'RUB',
    true,
    20,
    jsonb_build_object('saving_minor', 10000)
  ),
  (
    'profile_active_6m',
    'Активная анкета на 6 месяцев',
    'Размещение одной анкеты в активной базе PK Management на 6 месяцев.',
    6,
    240000,
    'RUB',
    true,
    30,
    jsonb_build_object('saving_minor', 60000)
  ),
  (
    'profile_active_12m',
    'Активная анкета на 12 месяцев',
    'Размещение одной анкеты в активной базе PK Management на 12 месяцев.',
    12,
    400000,
    'RUB',
    true,
    40,
    jsonb_build_object('saving_minor', 200000)
  )
on conflict (code) do update
set
  title = excluded.title,
  description = excluded.description,
  duration_months = excluded.duration_months,
  price_minor = excluded.price_minor,
  currency = excluded.currency,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  metadata = excluded.metadata,
  updated_at = now();

create table if not exists public.billing_payment_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.billing_products(id),
  provider text not null default 'manual'
    check (provider in ('manual', 'yookassa', 'cloudpayments')),
  provider_payment_id text not null default '',
  provider_customer_id text not null default '',
  confirmation_url text not null default '',
  idempotency_key text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'waiting_for_capture', 'succeeded', 'canceled', 'failed')),
  amount_minor int not null check (amount_minor >= 0),
  currency text not null default 'RUB',
  description text not null default '',
  error_message text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  paid_at timestamptz,
  canceled_at timestamptz
);

alter table public.billing_payment_orders
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists profile_id uuid references public.profiles(id) on delete cascade,
  add column if not exists product_id uuid references public.billing_products(id),
  add column if not exists provider text not null default 'manual',
  add column if not exists provider_payment_id text not null default '',
  add column if not exists provider_customer_id text not null default '',
  add column if not exists confirmation_url text not null default '',
  add column if not exists idempotency_key text not null default '',
  add column if not exists status text not null default 'pending',
  add column if not exists amount_minor int not null default 0,
  add column if not exists currency text not null default 'RUB',
  add column if not exists description text not null default '',
  add column if not exists error_message text not null default '',
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists created_by_user_id uuid references auth.users(id) on delete set null,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists paid_at timestamptz,
  add column if not exists canceled_at timestamptz;

create index if not exists billing_payment_orders_user_created_idx
  on public.billing_payment_orders (user_id, created_at desc);

create index if not exists billing_payment_orders_profile_created_idx
  on public.billing_payment_orders (profile_id, created_at desc);

create index if not exists billing_payment_orders_provider_payment_idx
  on public.billing_payment_orders (provider, provider_payment_id)
  where provider_payment_id <> '';

create index if not exists billing_payment_orders_status_idx
  on public.billing_payment_orders (status, created_at desc);

create table if not exists public.billing_payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.billing_payment_orders(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid references public.billing_products(id),
  provider text not null default 'manual'
    check (provider in ('manual', 'yookassa', 'cloudpayments')),
  provider_payment_id text not null default '',
  status text not null default 'succeeded'
    check (status in ('succeeded', 'refunded', 'partially_refunded', 'canceled', 'failed')),
  amount_minor int not null check (amount_minor >= 0),
  currency text not null default 'RUB',
  receipt_url text not null default '',
  paid_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists billing_payments_user_paid_idx
  on public.billing_payments (user_id, paid_at desc);

create index if not exists billing_payments_profile_paid_idx
  on public.billing_payments (profile_id, paid_at desc);

create unique index if not exists billing_payments_provider_payment_unique_idx
  on public.billing_payments (provider, provider_payment_id)
  where provider_payment_id <> '';

create table if not exists public.billing_profile_subscriptions (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'inactive'
    check (status in ('inactive', 'trial_active', 'active_paid', 'payment_overdue', 'canceled')),
  source text not null default 'manual'
    check (source in ('manual', 'trial', 'yookassa', 'cloudpayments', 'system')),
  product_id uuid references public.billing_products(id),
  last_order_id uuid references public.billing_payment_orders(id) on delete set null,
  last_payment_id uuid references public.billing_payments(id) on delete set null,
  current_period_start timestamptz,
  current_period_end timestamptz,
  granted_by_user_id uuid references auth.users(id) on delete set null,
  admin_note text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.billing_profile_subscriptions
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists status text not null default 'inactive',
  add column if not exists source text not null default 'manual',
  add column if not exists product_id uuid references public.billing_products(id),
  add column if not exists last_order_id uuid references public.billing_payment_orders(id) on delete set null,
  add column if not exists last_payment_id uuid references public.billing_payments(id) on delete set null,
  add column if not exists current_period_start timestamptz,
  add column if not exists current_period_end timestamptz,
  add column if not exists granted_by_user_id uuid references auth.users(id) on delete set null,
  add column if not exists admin_note text not null default '',
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists billing_profile_subscriptions_user_status_idx
  on public.billing_profile_subscriptions (user_id, status, current_period_end desc);

create index if not exists billing_profile_subscriptions_status_period_idx
  on public.billing_profile_subscriptions (status, current_period_end);

create table if not exists public.billing_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('yookassa', 'cloudpayments')),
  provider_event_id text not null,
  event_type text not null default '',
  related_payment_id text not null default '',
  payload jsonb not null default '{}'::jsonb,
  processing_status text not null default 'received'
    check (processing_status in ('received', 'processed', 'ignored', 'failed')),
  processing_error text not null default '',
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (provider, provider_event_id)
);

create index if not exists billing_webhook_events_provider_created_idx
  on public.billing_webhook_events (provider, created_at desc);

create index if not exists billing_webhook_events_status_idx
  on public.billing_webhook_events (processing_status, created_at desc);

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
left join public.billing_products bp on bp.id = s.product_id;

alter view public.billing_entitlements set (security_invoker = true);

create or replace function public.profile_billing_is_active(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.billing_profile_subscriptions s
    where s.profile_id = p_profile_id
      and s.status in ('trial_active', 'active_paid')
      and s.current_period_end > now()
  );
$$;

grant execute on function public.profile_billing_is_active(uuid)
  to authenticated;

create or replace function public.my_profile_billing_summary(p_profile_id uuid)
returns table (
  profile_id uuid,
  status text,
  source text,
  product_code text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  is_active boolean,
  days_left int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Auth required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_profile_id
      and (
        p.user_id = v_user_id
        or public.current_user_is_admin()
      )
  ) then
    raise exception 'Profile not found or access denied';
  end if;

  return query
  select
    p_profile_id,
    coalesce(be.status, 'inactive') as status,
    coalesce(be.source, '') as source,
    coalesce(be.product_code, '') as product_code,
    be.current_period_start,
    be.current_period_end,
    coalesce(be.is_active, false) as is_active,
    coalesce(
      greatest(
        0,
        ceil(extract(epoch from (be.current_period_end - now())) / 86400)::int
      ),
      0
    ) as days_left
  from (select 1) x
  left join public.billing_entitlements be
    on be.profile_id = p_profile_id;
end;
$$;

grant execute on function public.my_profile_billing_summary(uuid)
  to authenticated;

create or replace function public.admin_grant_profile_billing(
  p_profile_id uuid,
  p_duration_months int,
  p_admin_note text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_admin_id uuid := auth.uid();
  v_profile_user_id uuid;
  v_profile_title text := '';
  v_product public.billing_products%rowtype;
  v_base_start timestamptz;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_order_id uuid;
  v_payment_id uuid;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can grant profile billing';
  end if;

  if p_profile_id is null then
    raise exception 'Profile id is required';
  end if;

  if p_duration_months not in (1, 3, 6, 12) then
    raise exception 'Duration must be 1, 3, 6, or 12 months';
  end if;

  select p.user_id, coalesce(nullif(p.full_name, ''), p.id::text)
  into v_profile_user_id, v_profile_title
  from public.profiles p
  where p.id = p_profile_id
  limit 1;

  if v_profile_user_id is null then
    raise exception 'Profile not found';
  end if;

  select *
  into v_product
  from public.billing_products
  where duration_months = p_duration_months
    and is_active
  order by sort_order
  limit 1;

  if v_product.id is null then
    raise exception 'Billing product for % months not found', p_duration_months;
  end if;

  select greatest(coalesce(current_period_end, now()), now())
  into v_base_start
  from public.billing_profile_subscriptions
  where profile_id = p_profile_id
    and status in ('trial_active', 'active_paid')
    and current_period_end > now();

  v_period_start := coalesce(v_base_start, now());
  v_period_end := v_period_start + make_interval(months => p_duration_months);

  insert into public.billing_payment_orders (
    user_id,
    profile_id,
    product_id,
    provider,
    status,
    amount_minor,
    currency,
    description,
    metadata,
    created_by_user_id,
    paid_at
  )
  values (
    v_profile_user_id,
    p_profile_id,
    v_product.id,
    'manual',
    'succeeded',
    v_product.price_minor,
    v_product.currency,
    concat('Ручная активация анкеты на ', p_duration_months, ' мес.'),
    jsonb_build_object('admin_note', coalesce(p_admin_note, '')),
    v_admin_id,
    now()
  )
  returning id into v_order_id;

  insert into public.billing_payments (
    order_id,
    user_id,
    profile_id,
    product_id,
    provider,
    status,
    amount_minor,
    currency,
    metadata,
    paid_at
  )
  values (
    v_order_id,
    v_profile_user_id,
    p_profile_id,
    v_product.id,
    'manual',
    'succeeded',
    v_product.price_minor,
    v_product.currency,
    jsonb_build_object('admin_note', coalesce(p_admin_note, '')),
    now()
  )
  returning id into v_payment_id;

  insert into public.billing_profile_subscriptions (
    profile_id,
    user_id,
    status,
    source,
    product_id,
    last_order_id,
    last_payment_id,
    current_period_start,
    current_period_end,
    granted_by_user_id,
    admin_note,
    metadata,
    updated_at
  )
  values (
    p_profile_id,
    v_profile_user_id,
    'active_paid',
    'manual',
    v_product.id,
    v_order_id,
    v_payment_id,
    v_period_start,
    v_period_end,
    v_admin_id,
    coalesce(p_admin_note, ''),
    jsonb_build_object('duration_months', p_duration_months),
    now()
  )
  on conflict (profile_id) do update
  set
    user_id = excluded.user_id,
    status = excluded.status,
    source = excluded.source,
    product_id = excluded.product_id,
    last_order_id = excluded.last_order_id,
    last_payment_id = excluded.last_payment_id,
    current_period_start = excluded.current_period_start,
    current_period_end = excluded.current_period_end,
    granted_by_user_id = excluded.granted_by_user_id,
    admin_note = excluded.admin_note,
    metadata = excluded.metadata,
    updated_at = now();

  perform public.admin_record_backoffice_action(
    'profile_billing_granted',
    'Анкета активирована в базе',
    concat(
      'Активное размещение продлено на ',
      p_duration_months,
      ' мес. до ',
      to_char(v_period_end, 'YYYY-MM-DD HH24:MI')
    ),
    'profiles',
    p_profile_id,
    v_profile_title,
    jsonb_build_object(
      'profile_id', p_profile_id,
      'user_id', v_profile_user_id,
      'duration_months', p_duration_months,
      'period_start', v_period_start,
      'period_end', v_period_end,
      'order_id', v_order_id,
      'payment_id', v_payment_id,
      'admin_note', coalesce(p_admin_note, '')
    )
  );

  return v_payment_id;
end;
$$;

grant execute on function public.admin_grant_profile_billing(uuid, int, text)
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
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can revoke profile billing';
  end if;

  if p_profile_id is null then
    raise exception 'Profile id is required';
  end if;

  select coalesce(nullif(full_name, ''), id::text)
  into v_profile_title
  from public.profiles
  where id = p_profile_id
  limit 1;

  if not found then
    raise exception 'Profile not found';
  end if;

  update public.billing_profile_subscriptions
  set
    status = 'canceled',
    source = 'manual',
    current_period_end = now(),
    admin_note = coalesce(p_admin_note, ''),
    updated_at = now()
  where profile_id = p_profile_id;

  if not found then
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
    select
      p.id,
      p.user_id,
      'canceled',
      'manual',
      now(),
      now(),
      auth.uid(),
      coalesce(p_admin_note, ''),
      now()
    from public.profiles p
    where p.id = p_profile_id;
  end if;

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

alter table public.billing_products enable row level security;
alter table public.billing_payment_orders enable row level security;
alter table public.billing_payments enable row level security;
alter table public.billing_profile_subscriptions enable row level security;
alter table public.billing_webhook_events enable row level security;

drop policy if exists "Users can view active billing products"
  on public.billing_products;
create policy "Users can view active billing products"
  on public.billing_products
  for select
  to authenticated
  using (is_active or public.current_user_is_admin());

drop policy if exists "Admins can manage billing products"
  on public.billing_products;
create policy "Admins can manage billing products"
  on public.billing_products
  for all
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

drop policy if exists "Users and admins can view billing orders"
  on public.billing_payment_orders;
create policy "Users and admins can view billing orders"
  on public.billing_payment_orders
  for select
  to authenticated
  using (user_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "Admins can manage billing orders"
  on public.billing_payment_orders;
create policy "Admins can manage billing orders"
  on public.billing_payment_orders
  for all
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

drop policy if exists "Users and admins can view billing payments"
  on public.billing_payments;
create policy "Users and admins can view billing payments"
  on public.billing_payments
  for select
  to authenticated
  using (user_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "Admins can manage billing payments"
  on public.billing_payments;
create policy "Admins can manage billing payments"
  on public.billing_payments
  for all
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

drop policy if exists "Users and admins can view profile billing"
  on public.billing_profile_subscriptions;
create policy "Users and admins can view profile billing"
  on public.billing_profile_subscriptions
  for select
  to authenticated
  using (user_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "Admins can manage profile billing"
  on public.billing_profile_subscriptions;
create policy "Admins can manage profile billing"
  on public.billing_profile_subscriptions
  for all
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

drop policy if exists "Admins can view billing webhook events"
  on public.billing_webhook_events;
create policy "Admins can view billing webhook events"
  on public.billing_webhook_events
  for select
  to authenticated
  using (public.current_user_is_admin());

grant select on public.billing_entitlements to authenticated;
grant select on public.billing_products to authenticated;
grant select on public.billing_payment_orders to authenticated;
grant select on public.billing_payments to authenticated;
grant select on public.billing_profile_subscriptions to authenticated;
grant select on public.billing_webhook_events to authenticated;
