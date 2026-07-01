-- Fix for older Supabase projects where public.user_roles.role still has a
-- legacy CHECK constraint that rejects the permission role "casting_agent".
--
-- Symptom:
--   new row for relation "user_roles" violates check constraint
--   "user_roles_role_check"

alter table public.user_roles
  drop constraint if exists user_roles_role_check;

alter table public.user_roles
  add constraint user_roles_role_check
  check (lower(role) in ('user', 'admin', 'casting_agent'))
  not valid;

notify pgrst, 'reload schema';
