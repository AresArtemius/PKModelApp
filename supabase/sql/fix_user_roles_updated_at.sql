-- Compatibility fix for older projects where user_roles was created before
-- updated_at was added. Apply this in Supabase SQL Editor if approving agent
-- applications fails with: column "updated_at" of relation "user_roles" does not exist.

alter table public.user_roles
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.casting_agent_applications
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists requested_account_type text not null default 'casting_agent',
  add column if not exists decided_at timestamptz,
  add column if not exists decided_by uuid references auth.users(id) on delete set null;

notify pgrst, 'reload schema';
