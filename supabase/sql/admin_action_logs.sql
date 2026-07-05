-- Admin/back-office action audit log.
-- Tracks operational actions such as moderation, customer-status decisions,
-- casting creation/deletion and future admin tools.

create table if not exists public.admin_action_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_name text not null default '',
  actor_company text not null default '',
  action_type text not null default '',
  title text not null default '',
  description text not null default '',
  target_table text not null default '',
  target_id uuid,
  target_text text not null default '',
  status text not null default 'done',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.admin_action_logs
  add column if not exists actor_user_id uuid references auth.users(id) on delete set null,
  add column if not exists actor_name text not null default '',
  add column if not exists actor_company text not null default '',
  add column if not exists action_type text not null default '',
  add column if not exists title text not null default '',
  add column if not exists description text not null default '',
  add column if not exists target_table text not null default '',
  add column if not exists target_id uuid,
  add column if not exists target_text text not null default '',
  add column if not exists status text not null default 'done',
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create index if not exists admin_action_logs_created_idx
  on public.admin_action_logs (created_at desc);

create index if not exists admin_action_logs_actor_created_idx
  on public.admin_action_logs (actor_user_id, created_at desc);

create index if not exists admin_action_logs_target_idx
  on public.admin_action_logs (target_table, target_id);

alter table public.admin_action_logs enable row level security;

drop policy if exists "Admins can view admin action logs" on public.admin_action_logs;
create policy "Admins can view admin action logs"
  on public.admin_action_logs
  for select
  to authenticated
  using (public.current_user_is_admin());

drop policy if exists "Admins can insert admin action logs" on public.admin_action_logs;
create policy "Admins can insert admin action logs"
  on public.admin_action_logs
  for insert
  to authenticated
  with check (public.current_user_is_admin());

drop policy if exists "Admins can delete admin action logs" on public.admin_action_logs;
create policy "Admins can delete admin action logs"
  on public.admin_action_logs
  for delete
  to authenticated
  using (public.current_user_is_admin());
