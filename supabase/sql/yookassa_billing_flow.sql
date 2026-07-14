-- YooKassa payment flow for paid active profile placement.
-- Run after supabase/sql/profile_billing_mvp.sql.

create or replace function public.create_yookassa_profile_payment_order(
  p_profile_id uuid,
  p_product_code text
)
returns table (
  order_id uuid,
  profile_id uuid,
  product_code text,
  amount_minor int,
  currency text,
  description text,
  idempotency_key text
)
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_product public.billing_products%rowtype;
  v_order_id uuid;
  v_idempotency_key text := gen_random_uuid()::text;
  v_description text;
begin
  if v_user_id is null then
    raise exception 'Auth required';
  end if;

  if p_profile_id is null then
    raise exception 'Profile id is required';
  end if;

  if nullif(btrim(coalesce(p_product_code, '')), '') is null then
    raise exception 'Product code is required';
  end if;

  select *
  into v_profile
  from public.profiles
  where id = p_profile_id
  limit 1;

  if v_profile.id is null then
    raise exception 'Profile not found';
  end if;

  if v_profile.user_id <> v_user_id and not public.current_user_is_admin() then
    raise exception 'Access denied';
  end if;

  select *
  into v_product
  from public.billing_products
  where code = p_product_code
    and is_active
  limit 1;

  if v_product.id is null then
    raise exception 'Billing product not found';
  end if;

  v_description := concat(
    'PK Management: размещение анкеты на ',
    v_product.duration_months,
    ' мес.'
  );

  insert into public.billing_payment_orders (
    user_id,
    profile_id,
    product_id,
    provider,
    status,
    amount_minor,
    currency,
    description,
    idempotency_key,
    metadata,
    created_by_user_id
  )
  values (
    v_profile.user_id,
    v_profile.id,
    v_product.id,
    'yookassa',
    'pending',
    v_product.price_minor,
    v_product.currency,
    v_description,
    v_idempotency_key,
    jsonb_build_object(
      'product_code', v_product.code,
      'duration_months', v_product.duration_months
    ),
    v_user_id
  )
  returning id into v_order_id;

  return query
  select
    v_order_id,
    v_profile.id,
    v_product.code,
    v_product.price_minor,
    v_product.currency,
    v_description,
    v_idempotency_key;
end;
$$;

grant execute on function public.create_yookassa_profile_payment_order(uuid, text)
  to authenticated;

create or replace function public.mark_yookassa_profile_payment_started(
  p_order_id uuid,
  p_provider_payment_id text,
  p_confirmation_url text,
  p_provider_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user_id uuid := auth.uid();
  v_order public.billing_payment_orders%rowtype;
begin
  if v_user_id is null then
    raise exception 'Auth required';
  end if;

  select *
  into v_order
  from public.billing_payment_orders
  where id = p_order_id
  limit 1;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.created_by_user_id <> v_user_id and not public.current_user_is_admin() then
    raise exception 'Access denied';
  end if;

  update public.billing_payment_orders
  set
    provider_payment_id = coalesce(nullif(p_provider_payment_id, ''), provider_payment_id),
    confirmation_url = coalesce(nullif(p_confirmation_url, ''), confirmation_url),
    status = case
      when status = 'pending' then 'waiting_for_capture'
      else status
    end,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'yookassa_payment', coalesce(p_provider_payload, '{}'::jsonb)
    ),
    updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.mark_yookassa_profile_payment_started(uuid, text, text, jsonb)
  to authenticated;

create or replace function public.apply_yookassa_profile_payment_succeeded(
  p_provider_payment_id text,
  p_provider_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_order public.billing_payment_orders%rowtype;
  v_product public.billing_products%rowtype;
  v_base_start timestamptz;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_payment_id uuid;
begin
  if nullif(btrim(coalesce(p_provider_payment_id, '')), '') is null then
    raise exception 'Provider payment id is required';
  end if;

  select *
  into v_order
  from public.billing_payment_orders
  where provider = 'yookassa'
    and provider_payment_id = p_provider_payment_id
  limit 1;

  if v_order.id is null then
    raise exception 'Billing order not found for provider payment id %', p_provider_payment_id;
  end if;

  select *
  into v_product
  from public.billing_products
  where id = v_order.product_id
  limit 1;

  if v_product.id is null then
    raise exception 'Billing product not found for order %', v_order.id;
  end if;

  select id
  into v_payment_id
  from public.billing_payments
  where provider = 'yookassa'
    and provider_payment_id = p_provider_payment_id
    and status = 'succeeded'
  limit 1;

  if v_payment_id is not null then
    update public.billing_payment_orders
    set
      status = 'succeeded',
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'yookassa_webhook_duplicate', coalesce(p_provider_payload, '{}'::jsonb)
      ),
      paid_at = coalesce(paid_at, now()),
      updated_at = now()
    where id = v_order.id;

    return v_payment_id;
  end if;

  update public.billing_payment_orders
  set
    status = 'succeeded',
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'yookassa_webhook', coalesce(p_provider_payload, '{}'::jsonb)
    ),
    paid_at = coalesce(paid_at, now()),
    updated_at = now()
  where id = v_order.id;

  begin
    insert into public.billing_payments (
      order_id,
      user_id,
      profile_id,
      product_id,
      provider,
      provider_payment_id,
      status,
      amount_minor,
      currency,
      metadata,
      paid_at
    )
    values (
      v_order.id,
      v_order.user_id,
      v_order.profile_id,
      v_order.product_id,
      'yookassa',
      p_provider_payment_id,
      'succeeded',
      v_order.amount_minor,
      v_order.currency,
      coalesce(p_provider_payload, '{}'::jsonb),
      now()
    )
    returning id into v_payment_id;
  exception
    when unique_violation then
      select id
      into v_payment_id
      from public.billing_payments
      where provider = 'yookassa'
        and provider_payment_id = p_provider_payment_id
      limit 1;

      update public.billing_payments
      set
        status = 'succeeded',
        metadata = coalesce(p_provider_payload, '{}'::jsonb)
      where id = v_payment_id;
  end;

  select greatest(coalesce(current_period_end, now()), now())
  into v_base_start
  from public.billing_profile_subscriptions
  where profile_id = v_order.profile_id
    and status in ('trial_active', 'active_paid')
    and current_period_end > now();

  v_period_start := coalesce(v_base_start, now());
  v_period_end := v_period_start + make_interval(months => v_product.duration_months);

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
    admin_note,
    metadata,
    updated_at
  )
  values (
    v_order.profile_id,
    v_order.user_id,
    'active_paid',
    'yookassa',
    v_order.product_id,
    v_order.id,
    v_payment_id,
    v_period_start,
    v_period_end,
    '',
    jsonb_build_object(
      'duration_months', v_product.duration_months,
      'provider_payment_id', p_provider_payment_id
    ),
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
    admin_note = excluded.admin_note,
    metadata = excluded.metadata,
    updated_at = now();

  return v_payment_id;
end;
$$;

grant execute on function public.apply_yookassa_profile_payment_succeeded(text, jsonb)
  to service_role;

create or replace function public.mark_yookassa_profile_payment_canceled(
  p_provider_payment_id text,
  p_provider_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  update public.billing_payment_orders
  set
    status = 'canceled',
    error_message = coalesce(
      p_provider_payload #>> '{object,cancellation_details,reason}',
      p_provider_payload #>> '{cancellation_details,reason}',
      error_message
    ),
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'yookassa_webhook', coalesce(p_provider_payload, '{}'::jsonb)
    ),
    canceled_at = coalesce(canceled_at, now()),
    updated_at = now()
  where provider = 'yookassa'
    and provider_payment_id = p_provider_payment_id;
end;
$$;

grant execute on function public.mark_yookassa_profile_payment_canceled(text, jsonb)
  to service_role;
