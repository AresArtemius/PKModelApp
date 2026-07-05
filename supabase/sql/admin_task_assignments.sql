-- Admin/operator task assignments.
-- Generic assignment layer for moderation, customer applications, merge requests
-- and safety reports.

create table if not exists public.admin_task_assignments (
  id uuid primary key default gen_random_uuid(),
  target_table text not null default '',
  target_id text not null default '',
  assigned_to_user_id uuid references auth.users(id) on delete set null,
  assigned_to_name text not null default '',
  assigned_by_user_id uuid references auth.users(id) on delete set null,
  priority text not null default 'normal',
  due_at timestamptz,
  assigned_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.admin_task_assignments
  add column if not exists target_table text not null default '',
  add column if not exists target_id text not null default '',
  add column if not exists assigned_to_user_id uuid references auth.users(id) on delete set null,
  add column if not exists assigned_to_name text not null default '',
  add column if not exists assigned_by_user_id uuid references auth.users(id) on delete set null,
  add column if not exists priority text not null default 'normal',
  add column if not exists due_at timestamptz,
  add column if not exists assigned_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.admin_task_assignments
  drop constraint if exists admin_task_assignments_priority_check;

alter table public.admin_task_assignments
  add constraint admin_task_assignments_priority_check
  check (priority in ('normal', 'urgent', 'critical'));

create unique index if not exists admin_task_assignments_target_unique_idx
  on public.admin_task_assignments (target_table, target_id);

create index if not exists admin_task_assignments_assignee_idx
  on public.admin_task_assignments (assigned_to_user_id, assigned_at desc);

create index if not exists admin_task_assignments_target_idx
  on public.admin_task_assignments (target_table, target_id);

create index if not exists admin_task_assignments_sla_idx
  on public.admin_task_assignments (priority, due_at);

alter table public.admin_task_assignments enable row level security;

drop policy if exists "Admins can view admin task assignments" on public.admin_task_assignments;
create policy "Admins can view admin task assignments"
  on public.admin_task_assignments
  for select
  to authenticated
  using (public.current_user_is_admin());

drop policy if exists "Admins can insert admin task assignments" on public.admin_task_assignments;
create policy "Admins can insert admin task assignments"
  on public.admin_task_assignments
  for insert
  to authenticated
  with check (public.current_user_is_admin());

drop policy if exists "Admins can update admin task assignments" on public.admin_task_assignments;
create policy "Admins can update admin task assignments"
  on public.admin_task_assignments
  for update
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

drop policy if exists "Admins can delete admin task assignments" on public.admin_task_assignments;
create policy "Admins can delete admin task assignments"
  on public.admin_task_assignments
  for delete
  to authenticated
  using (public.current_user_is_admin());
