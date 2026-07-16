-- One paid placement belongs to one profile. Profile creation is not tied to
-- subscription plans: every account gets four profiles, and admins can grant
-- additional slots on request.

create table if not exists public.profile_slot_allowances (
  user_id uuid primary key references auth.users(id) on delete cascade,
  extra_slots integer not null default 0 check (extra_slots >= 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

create table if not exists public.profile_slot_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  requested_slots integer not null default 1 check (requested_slots between 1 and 20),
  admin_comment text not null default '',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists profile_slot_requests_one_pending_idx
  on public.profile_slot_requests (user_id) where status = 'pending';

alter table public.profile_slot_allowances enable row level security;
alter table public.profile_slot_requests enable row level security;
grant select on public.profile_slot_allowances to authenticated;
grant select on public.profile_slot_requests to authenticated;

drop policy if exists "Users read own profile slot allowance" on public.profile_slot_allowances;
create policy "Users read own profile slot allowance"
  on public.profile_slot_allowances for select
  using (user_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "Users and admins read profile slot requests" on public.profile_slot_requests;
create policy "Users and admins read profile slot requests"
  on public.profile_slot_requests for select
  using (user_id = auth.uid() or public.current_user_is_admin());

create or replace function public.my_profile_creation_capacity()
returns table (
  current_count integer,
  profile_limit integer,
  has_pending_request boolean
)
language sql
security definer
set search_path = public
set row_security = off
stable
as $$
  select
    (select count(*)::integer from public.profiles p where p.user_id = auth.uid()),
    4 + coalesce((select a.extra_slots from public.profile_slot_allowances a where a.user_id = auth.uid()), 0),
    exists(select 1 from public.profile_slot_requests r where r.user_id = auth.uid() and r.status = 'pending');
$$;

revoke all on function public.my_profile_creation_capacity() from public, anon;
grant execute on function public.my_profile_creation_capacity() to authenticated;

create or replace function public.request_extra_profile_slot()
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user_id uuid := auth.uid();
  v_capacity record;
  v_id uuid;
begin
  if v_user_id is null then raise exception 'Not authenticated'; end if;
  select * into v_capacity from public.my_profile_creation_capacity();
  if v_capacity.current_count < v_capacity.profile_limit then
    raise exception 'Profile limit has not been reached';
  end if;
  select id into v_id from public.profile_slot_requests
    where user_id = v_user_id and status = 'pending' limit 1;
  if v_id is not null then return v_id; end if;
  insert into public.profile_slot_requests (user_id)
    values (v_user_id) returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.request_extra_profile_slot() from public, anon;
grant execute on function public.request_extra_profile_slot() to authenticated;

create or replace function public.admin_decide_profile_slot_request(
  p_request_id uuid,
  p_approved boolean,
  p_slots integer default 1,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare v_request public.profile_slot_requests%rowtype;
begin
  if not public.current_user_is_admin() then raise exception 'Admin only'; end if;
  if p_slots < 1 or p_slots > 20 then raise exception 'Invalid slots count'; end if;
  select * into v_request from public.profile_slot_requests where id = p_request_id for update;
  if v_request.id is null or v_request.status <> 'pending' then
    raise exception 'Pending request not found';
  end if;
  if p_approved then
    insert into public.profile_slot_allowances (user_id, extra_slots, updated_by)
      values (v_request.user_id, p_slots, auth.uid())
    on conflict (user_id) do update set
      extra_slots = public.profile_slot_allowances.extra_slots + excluded.extra_slots,
      updated_at = now(), updated_by = auth.uid();
  end if;
  update public.profile_slot_requests set
    status = case when p_approved then 'approved' else 'rejected' end,
    requested_slots = p_slots, admin_comment = coalesce(p_comment, ''),
    reviewed_by = auth.uid(), reviewed_at = now(), updated_at = now()
  where id = p_request_id;
end;
$$;

revoke all on function public.admin_decide_profile_slot_request(uuid, boolean, integer, text)
  from public, anon;
grant execute on function public.admin_decide_profile_slot_request(uuid, boolean, integer, text)
  to authenticated;

create or replace function public.enforce_profile_creation_limit()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare v_limit integer;
begin
  -- Service-role processes have no auth.uid(). Admins are not limited.
  if auth.uid() is null or public.current_user_is_admin() then return new; end if;
  if new.user_id <> auth.uid() then return new; end if;
  select 4 + coalesce(a.extra_slots, 0) into v_limit
    from (select new.user_id as user_id) u
    left join public.profile_slot_allowances a on a.user_id = u.user_id;
  if (select count(*) from public.profiles p where p.user_id = new.user_id) >= v_limit then
    raise exception using errcode = 'P0001', message = 'profile_creation_limit_reached';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_profile_creation_limit() from public, anon, authenticated;

drop trigger if exists enforce_profile_creation_limit_trigger on public.profiles;
create trigger enforce_profile_creation_limit_trigger
before insert on public.profiles
for each row execute function public.enforce_profile_creation_limit();
