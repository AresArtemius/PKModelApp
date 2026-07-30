-- PK Management admin access hardening.
-- Apply once in the Supabase SQL editor. Safe to apply repeatedly.

-- Authorization has one source of truth: the protected user_roles table.
create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = auth.uid()
      and lower(role) = 'admin'
  );
$$;

revoke all on function public.current_user_is_admin() from public;
grant execute on function public.current_user_is_admin() to authenticated;

-- A user may edit their profile, but may never assign a staff account type.
drop policy if exists "Users can create own account profile"
  on public.user_profiles;
create policy "Users can create own account profile"
  on public.user_profiles
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and (
      lower(coalesce(account_type, 'user'))
        not in ('admin', 'moderator', 'support')
      or public.current_user_is_admin()
    )
  );

drop policy if exists "Users can update own account profile"
  on public.user_profiles;
create policy "Users can update own account profile"
  on public.user_profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and (
      lower(coalesce(account_type, 'user'))
        not in ('admin', 'moderator', 'support')
      or public.current_user_is_admin()
    )
  );

notify pgrst, 'reload schema';
