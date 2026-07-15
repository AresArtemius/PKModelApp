-- Update the active profile placement tariff line.
-- Final prices are rounded to whole rubles after applying the discount:
-- 3 months: 499 * 3 - 5% = 1422.15 -> 1422 RUB;
-- 6 months: 499 * 6 - 7% = 2784.42 -> 2784 RUB;
-- 12 months: 499 * 12 - 10% = 5389.20 -> 5389 RUB.

update public.billing_products
set
  price_minor = case code
    when 'profile_active_1m' then 49900
    when 'profile_active_3m' then 142200
    when 'profile_active_6m' then 278400
    when 'profile_active_12m' then 538900
    else price_minor
  end,
  metadata = (coalesce(metadata, '{}'::jsonb) - 'saving_minor') || case code
    when 'profile_active_1m' then
      jsonb_build_object('discount_percent', 0, 'base_monthly_minor', 49900)
    when 'profile_active_3m' then
      jsonb_build_object('discount_percent', 5, 'base_monthly_minor', 49900)
    when 'profile_active_6m' then
      jsonb_build_object('discount_percent', 7, 'base_monthly_minor', 49900)
    when 'profile_active_12m' then
      jsonb_build_object('discount_percent', 10, 'base_monthly_minor', 49900)
    else '{}'::jsonb
  end,
  updated_at = now()
where code in (
  'profile_active_1m',
  'profile_active_3m',
  'profile_active_6m',
  'profile_active_12m'
);
