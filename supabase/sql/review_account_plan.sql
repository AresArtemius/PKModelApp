-- Review account for App Store: give art@test.ru an active "casting_agent_pro"
-- plan for a year so chats, selections and castings work for the reviewer
-- without a purchase. Re-runnable. Remove the row (or set status='canceled')
-- after the review if needed.

insert into public.user_billing_profiles
  (user_id, plan, status, provider, current_period_end, updated_at)
select u.id, 'casting_agent_pro', 'active', 'manual', now() + interval '1 year', now()
from auth.users u
where lower(u.email) = 'art@test.ru'
on conflict (user_id) do update
  set plan = excluded.plan,
      status = excluded.status,
      provider = excluded.provider,
      current_period_end = excluded.current_period_end,
      updated_at = now();

-- Check:
select u.email, b.plan, b.status, b.current_period_end
from public.user_billing_profiles b
join auth.users u on u.id = b.user_id
where lower(u.email) = 'art@test.ru';
