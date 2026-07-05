-- Profile action audit log.
-- Stores a durable event timeline for profile quick actions: invitations,
-- selections/folders, chat messages and future delivery/read states.

create table if not exists public.profile_action_logs (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  target_user_id uuid references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_name text not null default '',
  actor_company text not null default '',
  actor_avatar_url text not null default '',
  action_type text not null check (
    action_type in ('invite', 'selection', 'folder', 'message')
  ),
  title text not null default '',
  description text not null default '',
  template_key text not null default '',
  template_body text not null default '',
  status text not null default 'created' check (
    status in ('created', 'sent', 'delivered', 'read', 'failed', 'archived')
  ),
  related_table text not null default '',
  related_id uuid,
  related_text text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.profile_action_logs
  add column if not exists target_user_id uuid references auth.users(id) on delete cascade,
  add column if not exists actor_user_id uuid references auth.users(id) on delete set null,
  add column if not exists actor_name text not null default '',
  add column if not exists actor_company text not null default '',
  add column if not exists actor_avatar_url text not null default '',
  add column if not exists description text not null default '',
  add column if not exists template_key text not null default '',
  add column if not exists template_body text not null default '',
  add column if not exists status text not null default 'created',
  add column if not exists related_table text not null default '',
  add column if not exists related_id uuid,
  add column if not exists related_text text not null default '',
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists delivered_at timestamptz,
  add column if not exists read_at timestamptz;

create index if not exists profile_action_logs_profile_created_idx
  on public.profile_action_logs (profile_id, created_at desc);

create index if not exists profile_action_logs_actor_created_idx
  on public.profile_action_logs (actor_user_id, created_at desc);

create index if not exists profile_action_logs_target_created_idx
  on public.profile_action_logs (target_user_id, created_at desc);

create index if not exists profile_action_logs_related_idx
  on public.profile_action_logs (related_table, related_id);

alter table public.profile_action_logs enable row level security;

drop policy if exists "Profile action participants can view" on public.profile_action_logs;
create policy "Profile action participants can view"
  on public.profile_action_logs
  for select
  to authenticated
  using (
    actor_user_id = auth.uid()
    or target_user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = profile_action_logs.profile_id
        and p.user_id = auth.uid()
    )
    or public.current_user_is_admin()
  );

drop policy if exists "Users can insert own profile action logs" on public.profile_action_logs;
create policy "Users can insert own profile action logs"
  on public.profile_action_logs
  for insert
  to authenticated
  with check (
    actor_user_id = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Participants can update profile action read state" on public.profile_action_logs;
create policy "Participants can update profile action read state"
  on public.profile_action_logs
  for update
  to authenticated
  using (
    actor_user_id = auth.uid()
    or target_user_id = auth.uid()
    or public.current_user_is_admin()
  )
  with check (
    actor_user_id = auth.uid()
    or target_user_id = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Admins can delete profile action logs" on public.profile_action_logs;
create policy "Admins can delete profile action logs"
  on public.profile_action_logs
  for delete
  to authenticated
  using (public.current_user_is_admin());
