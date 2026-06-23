-- Roles and casting-agent approval flow.
-- Run after base auth/profile tables exist.

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.casting_agent_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  comment text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null
);

create unique index if not exists casting_agent_applications_one_pending_idx
  on public.casting_agent_applications (user_id)
  where status = 'pending';

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id::text = auth.uid()::text
      and lower(role) = 'admin'
  );
$$;

create or replace function public.current_user_can_create_selections()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id::text = auth.uid()::text
      and lower(role) in ('admin', 'casting_agent')
  );
$$;

grant execute on function public.current_user_is_admin() to authenticated;
grant execute on function public.current_user_can_create_selections()
  to authenticated;

alter table public.user_roles enable row level security;
alter table public.casting_agent_applications enable row level security;

drop policy if exists "Users can view own role" on public.user_roles;
create policy "Users can view own role"
  on public.user_roles
  for select
  to authenticated
  using (user_id::text = auth.uid()::text or public.current_user_is_admin());

drop policy if exists "Users can create own user role" on public.user_roles;
create policy "Users can create own user role"
  on public.user_roles
  for insert
  to authenticated
  with check (user_id::text = auth.uid()::text and lower(role) = 'user');

drop policy if exists "Users can update own user role" on public.user_roles;
create policy "Users can update own user role"
  on public.user_roles
  for update
  to authenticated
  using (user_id::text = auth.uid()::text)
  with check (user_id::text = auth.uid()::text and lower(role) = 'user');

drop policy if exists "Users and admins can view casting agent applications"
  on public.casting_agent_applications;
create policy "Users and admins can view casting agent applications"
  on public.casting_agent_applications
  for select
  to authenticated
  using (user_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "Users can create own casting agent applications"
  on public.casting_agent_applications;
create policy "Users can create own casting agent applications"
  on public.casting_agent_applications
  for insert
  to authenticated
  with check (user_id = auth.uid() and status = 'pending');

create or replace function public.admin_decide_casting_agent_application(
  p_application_id uuid,
  p_approved boolean,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can decide casting agent applications';
  end if;

  select user_id into v_user_id
  from public.casting_agent_applications
  where id = p_application_id;

  if v_user_id is null then
    raise exception 'Casting agent application not found';
  end if;

  update public.casting_agent_applications
  set status = case when p_approved then 'approved' else 'rejected' end,
      comment = coalesce(p_comment, ''),
      decided_at = now(),
      decided_by = auth.uid(),
      updated_at = now()
  where id = p_application_id;

  if p_approved then
    insert into public.user_roles (user_id, role, updated_at)
    values (v_user_id, 'casting_agent', now())
    on conflict (user_id)
    do update set role = 'casting_agent', updated_at = now();

    update public.user_profiles
    set account_type = 'casting_agent', updated_at = now()
    where user_id = v_user_id;
  end if;
end;
$$;

grant execute on function public.admin_decide_casting_agent_application(
  uuid,
  boolean,
  text
) to authenticated;
