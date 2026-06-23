-- Role onboarding after first sign-in.
-- Run after user_profiles and roles_and_agent_approval.sql exist.

alter table public.user_profiles
  add column if not exists onboarding_completed_at timestamptz;

create index if not exists user_profiles_onboarding_completed_idx
  on public.user_profiles (onboarding_completed_at);

-- Keep already-approved admins out of the first-login onboarding gate.
update public.user_profiles up
set onboarding_completed_at = coalesce(up.onboarding_completed_at, now()),
    updated_at = now()
where exists (
  select 1
  from public.user_roles ur
  where ur.user_id = up.user_id
    and lower(ur.role) = 'admin'
);

notify pgrst, 'reload schema';
