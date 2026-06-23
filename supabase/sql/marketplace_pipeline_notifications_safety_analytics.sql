-- Adds the missing marketplace foundation:
-- campaign metadata, in-app notifications, reports/blocks, and profile analytics.

alter table public.selections
  add column if not exists client_name text,
  add column if not exists brand_name text,
  add column if not exists budget text,
  add column if not exists location text,
  add column if not exists project_dates text,
  add column if not exists project_roles text;

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  route text not null default '',
  read_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.app_notifications
  add column if not exists deleted_at timestamptz;

create index if not exists app_notifications_user_created_idx
  on public.app_notifications(user_id, created_at desc);

create table if not exists public.profile_reports (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  comment text not null default '',
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profile_reports_status_created_idx
  on public.profile_reports(status, created_at desc);

create table if not exists public.blocked_users (
  blocker_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (blocker_user_id, blocked_user_id),
  check (blocker_user_id <> blocked_user_id)
);

create table if not exists public.profile_analytics_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null
    check (event_type in ('profile_view', 'selection_add', 'invitation')),
  actor_user_id uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists profile_analytics_profile_created_idx
  on public.profile_analytics_events(profile_id, created_at desc);

alter table public.app_notifications enable row level security;
alter table public.profile_reports enable row level security;
alter table public.blocked_users enable row level security;
alter table public.profile_analytics_events enable row level security;

drop policy if exists "notifications_read_own" on public.app_notifications;
create policy "notifications_read_own"
on public.app_notifications for select
using (auth.uid() = user_id and deleted_at is null);

drop policy if exists "notifications_update_own" on public.app_notifications;
create policy "notifications_update_own"
on public.app_notifications for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "notifications_delete_own" on public.app_notifications;
create policy "notifications_delete_own"
on public.app_notifications for delete
using (auth.uid() = user_id);

drop policy if exists "reports_insert_own" on public.profile_reports;
create policy "reports_insert_own"
on public.profile_reports for insert
with check (auth.uid() = reporter_user_id);

drop policy if exists "reports_admin_all" on public.profile_reports;
create policy "reports_admin_all"
on public.profile_reports for all
using (
  exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid()
      and r.role = 'admin'
  )
)
with check (
  exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid()
      and r.role = 'admin'
  )
);

drop policy if exists "blocks_manage_own" on public.blocked_users;
create policy "blocks_manage_own"
on public.blocked_users for all
using (auth.uid() = blocker_user_id)
with check (auth.uid() = blocker_user_id);

drop policy if exists "analytics_insert_any_auth" on public.profile_analytics_events;
create policy "analytics_insert_any_auth"
on public.profile_analytics_events for insert
with check (auth.uid() is not null);

drop policy if exists "analytics_profile_owner_read" on public.profile_analytics_events;
create policy "analytics_profile_owner_read"
on public.profile_analytics_events for select
using (
  exists (
    select 1 from public.profiles p
    where p.id = profile_analytics_events.profile_id
      and p.user_id = auth.uid()
  )
);

create or replace function public.create_app_notification(
  p_user_id uuid,
  p_title text,
  p_body text default '',
  p_route text default ''
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.app_notifications(user_id, title, body, route)
  values (p_user_id, coalesce(p_title, ''), coalesce(p_body, ''), coalesce(p_route, ''))
  returning id into v_id;

  return v_id;
end;
$$;
