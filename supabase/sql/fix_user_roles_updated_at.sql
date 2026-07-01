-- Compatibility fix for older projects where user_roles was created before
-- updated_at was added. Apply this in Supabase SQL Editor if approving agent
-- applications fails with: column "updated_at" of relation "user_roles" does not exist.

alter table public.user_roles
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- Older projects can still have a legacy CHECK constraint on user_roles.role
-- that allows only old role values and rejects casting_agent approvals.
alter table public.user_roles
  drop constraint if exists user_roles_role_check;

alter table public.user_roles
  add constraint user_roles_role_check
  check (lower(role) in ('user', 'admin', 'casting_agent'))
  not valid;

alter table public.casting_agent_applications
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists requested_account_type text not null default 'casting_agent',
  add column if not exists decided_at timestamptz,
  add column if not exists decided_by uuid references auth.users(id) on delete set null;

create or replace function public.admin_decide_casting_agent_application(
  p_application_id uuid,
  p_approved boolean,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $admin_decide_casting_agent_application$
declare
  v_user_id uuid;
  v_requested_account_type text;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can decide casting agent applications';
  end if;

  select
    user_id,
    public.normalize_account_type(requested_account_type)
  into v_user_id, v_requested_account_type
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
    set account_type = v_requested_account_type, updated_at = now()
    where user_id = v_user_id;
  end if;
end;
$admin_decide_casting_agent_application$;

grant execute on function public.admin_decide_casting_agent_application(
  uuid,
  boolean,
  text
) to authenticated;

notify pgrst, 'reload schema';
