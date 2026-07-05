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

create or replace function public.ensure_admin_task_assignment(
  p_target_table text,
  p_target_id text,
  p_priority text,
  p_due_interval interval
)
returns void
language plpgsql
security definer
set search_path = public
as $ensure_admin_task_assignment$
begin
  if nullif(btrim(coalesce(p_target_table, '')), '') is null
     or nullif(btrim(coalesce(p_target_id, '')), '') is null then
    return;
  end if;

  insert into public.admin_task_assignments (
    target_table,
    target_id,
    priority,
    due_at,
    assigned_at,
    updated_at
  )
  values (
    p_target_table,
    p_target_id,
    case
      when p_priority in ('normal', 'urgent', 'critical') then p_priority
      else 'normal'
    end,
    case
      when p_due_interval is null then null
      else now() + p_due_interval
    end,
    now(),
    now()
  )
  on conflict (target_table, target_id) do nothing;
end;
$ensure_admin_task_assignment$;

create or replace function public.admin_task_assignment_profiles_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $admin_task_assignment_profiles_trigger$
begin
  if coalesce(new.status::text, '') = 'pending' then
    perform public.ensure_admin_task_assignment(
      'profiles',
      new.id::text,
      'normal',
      interval '48 hours'
    );
  else
    delete from public.admin_task_assignments
    where target_table = 'profiles'
      and target_id = new.id::text;
  end if;
  return new;
end;
$admin_task_assignment_profiles_trigger$;

create or replace function public.admin_task_assignment_agent_applications_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $admin_task_assignment_agent_applications_trigger$
begin
  if coalesce(new.status::text, '') = 'pending' then
    perform public.ensure_admin_task_assignment(
      'casting_agent_applications',
      new.id::text,
      'urgent',
      interval '24 hours'
    );
  else
    delete from public.admin_task_assignments
    where target_table = 'casting_agent_applications'
      and target_id = new.id::text;
  end if;
  return new;
end;
$admin_task_assignment_agent_applications_trigger$;

create or replace function public.admin_task_assignment_merge_requests_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $admin_task_assignment_merge_requests_trigger$
begin
  if coalesce(new.status::text, '') = 'pending' then
    perform public.ensure_admin_task_assignment(
      'account_merge_requests',
      new.id::text,
      'urgent',
      interval '48 hours'
    );
  else
    delete from public.admin_task_assignments
    where target_table = 'account_merge_requests'
      and target_id = new.id::text;
  end if;
  return new;
end;
$admin_task_assignment_merge_requests_trigger$;

create or replace function public.admin_task_assignment_profile_reports_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $admin_task_assignment_profile_reports_trigger$
begin
  if coalesce(new.status::text, '') in ('open', 'reviewing', 'in_review') then
    perform public.ensure_admin_task_assignment(
      'profile_reports',
      new.id::text,
      'critical',
      interval '24 hours'
    );
  else
    delete from public.admin_task_assignments
    where target_table = 'profile_reports'
      and target_id = new.id::text;
  end if;
  return new;
end;
$admin_task_assignment_profile_reports_trigger$;

do $admin_task_assignment_triggers$
begin
  if to_regclass('public.profiles') is not null then
    drop trigger if exists admin_task_assignment_profiles_on_status
      on public.profiles;
    create trigger admin_task_assignment_profiles_on_status
      after insert or update of status on public.profiles
      for each row
      execute function public.admin_task_assignment_profiles_trigger();

    insert into public.admin_task_assignments (
      target_table,
      target_id,
      priority,
      due_at,
      assigned_at,
      updated_at
    )
    select
      'profiles',
      p.id::text,
      'normal',
      coalesce(p.updated_at, p.created_at, now()) + interval '48 hours',
      now(),
      now()
    from public.profiles p
    where p.status::text = 'pending'
    on conflict (target_table, target_id) do nothing;

    delete from public.admin_task_assignments t
    using public.profiles p
    where t.target_table = 'profiles'
      and t.target_id = p.id::text
      and p.status::text <> 'pending';
  end if;

  if to_regclass('public.casting_agent_applications') is not null then
    drop trigger if exists admin_task_assignment_agent_applications_on_status
      on public.casting_agent_applications;
    create trigger admin_task_assignment_agent_applications_on_status
      after insert or update of status on public.casting_agent_applications
      for each row
      execute function public.admin_task_assignment_agent_applications_trigger();

    insert into public.admin_task_assignments (
      target_table,
      target_id,
      priority,
      due_at,
      assigned_at,
      updated_at
    )
    select
      'casting_agent_applications',
      a.id::text,
      'urgent',
      coalesce(a.updated_at, a.created_at, now()) + interval '24 hours',
      now(),
      now()
    from public.casting_agent_applications a
    where a.status = 'pending'
    on conflict (target_table, target_id) do nothing;

    delete from public.admin_task_assignments t
    using public.casting_agent_applications a
    where t.target_table = 'casting_agent_applications'
      and t.target_id = a.id::text
      and a.status <> 'pending';
  end if;

  if to_regclass('public.account_merge_requests') is not null then
    drop trigger if exists admin_task_assignment_merge_requests_on_status
      on public.account_merge_requests;
    create trigger admin_task_assignment_merge_requests_on_status
      after insert or update of status on public.account_merge_requests
      for each row
      execute function public.admin_task_assignment_merge_requests_trigger();

    insert into public.admin_task_assignments (
      target_table,
      target_id,
      priority,
      due_at,
      assigned_at,
      updated_at
    )
    select
      'account_merge_requests',
      m.id::text,
      'urgent',
      coalesce(m.updated_at, m.created_at, now()) + interval '48 hours',
      now(),
      now()
    from public.account_merge_requests m
    where m.status = 'pending'
    on conflict (target_table, target_id) do nothing;

    delete from public.admin_task_assignments t
    using public.account_merge_requests m
    where t.target_table = 'account_merge_requests'
      and t.target_id = m.id::text
      and m.status <> 'pending';
  end if;

  if to_regclass('public.profile_reports') is not null then
    drop trigger if exists admin_task_assignment_profile_reports_on_status
      on public.profile_reports;
    create trigger admin_task_assignment_profile_reports_on_status
      after insert or update of status on public.profile_reports
      for each row
      execute function public.admin_task_assignment_profile_reports_trigger();

    insert into public.admin_task_assignments (
      target_table,
      target_id,
      priority,
      due_at,
      assigned_at,
      updated_at
    )
    select
      'profile_reports',
      r.id::text,
      'critical',
      coalesce(r.updated_at, r.created_at, now()) + interval '24 hours',
      now(),
      now()
    from public.profile_reports r
    where coalesce(r.status, '') in ('open', 'reviewing', 'in_review')
    on conflict (target_table, target_id) do nothing;

    delete from public.admin_task_assignments t
    using public.profile_reports r
    where t.target_table = 'profile_reports'
      and t.target_id = r.id::text
      and coalesce(r.status, '') not in ('open', 'reviewing', 'in_review');
  end if;
end;
$admin_task_assignment_triggers$;

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
