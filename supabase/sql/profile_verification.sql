-- Model profile verification.
-- Run after base profiles table and roles_and_agent_approval.sql exist.

alter table public.profiles
  add column if not exists is_verified boolean not null default false;

alter table public.profiles
  add column if not exists verification_status text not null default 'none'
  check (verification_status in ('none', 'pending', 'verified', 'rejected'));

alter table public.profiles
  add column if not exists verification_requested_at timestamptz;

alter table public.profiles
  add column if not exists verified_at timestamptz;

alter table public.profiles
  add column if not exists verified_by uuid references auth.users(id)
  on delete set null;

create index if not exists profiles_status_verified_full_name_id_idx
  on public.profiles (status, is_verified desc, full_name, id);

create index if not exists profiles_verification_status_idx
  on public.profiles (verification_status);

create or replace function public.admin_set_profile_verification(
  p_profile_id uuid,
  p_verified boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can verify profiles';
  end if;

  update public.profiles
  set is_verified = coalesce(p_verified, false),
      verification_status = case
        when coalesce(p_verified, false) then 'verified'
        else 'rejected'
      end,
      verified_at = case
        when coalesce(p_verified, false) then now()
        else null
      end,
      verified_by = case
        when coalesce(p_verified, false) then auth.uid()
        else null
      end
  where id = p_profile_id;

  if not found then
    raise exception 'Profile not found';
  end if;
end;
$$;

grant execute on function public.admin_set_profile_verification(uuid, boolean)
  to authenticated;
