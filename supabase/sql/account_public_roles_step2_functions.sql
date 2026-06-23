-- Step 2. Functions and policies.
-- Run after account_public_roles_step1_tables.sql.

create or replace function public.normalize_account_type(p_value text)
returns text
language sql
immutable
as $normalize_account_type$
  select case lower(btrim(coalesce(p_value, '')))
    when 'casting_director' then 'casting_director'
    when 'casting_agent' then 'casting_agent'
    when 'director_producer' then 'director_producer'
    when 'brand_client' then 'brand_client'
    when 'agency' then 'agency'
    when 'production_agency' then 'production_agency'
    when 'photo_video' then 'photo_video'
    when 'scout_booker' then 'scout_booker'
    when 'admin' then 'admin'
    when 'moderator' then 'moderator'
    when 'support' then 'support'
    else 'user'
  end;
$normalize_account_type$;

create or replace function public.role_for_account_type(p_account_type text)
returns text
language sql
immutable
as $role_for_account_type$
  select case public.normalize_account_type(p_account_type)
    when 'admin' then 'admin'
    when 'moderator' then 'admin'
    when 'support' then 'admin'
    when 'casting_director' then 'casting_agent'
    when 'casting_agent' then 'casting_agent'
    when 'director_producer' then 'casting_agent'
    when 'brand_client' then 'casting_agent'
    when 'agency' then 'casting_agent'
    when 'production_agency' then 'casting_agent'
    when 'photo_video' then 'casting_agent'
    when 'scout_booker' then 'casting_agent'
    else 'user'
  end;
$role_for_account_type$;

update public.casting_agent_applications
set requested_account_type = public.normalize_account_type(comment)
where requested_account_type = 'casting_agent'
  and public.role_for_account_type(comment) = 'casting_agent';

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $current_user_is_admin$
  select exists (
    select 1
    from public.user_roles
    where user_id = auth.uid()
      and lower(role) = 'admin'
  )
  or exists (
    select 1
    from public.user_profiles
    where user_id = auth.uid()
      and public.role_for_account_type(account_type) = 'admin'
  );
$current_user_is_admin$;

create or replace function public.current_user_can_create_selections()
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $current_user_can_create_selections$
  select exists (
    select 1
    from public.user_roles
    where user_id = auth.uid()
      and lower(role) in ('admin', 'casting_agent')
  );
$current_user_can_create_selections$;

grant execute on function public.current_user_is_admin() to authenticated;
grant execute on function public.current_user_can_create_selections()
  to authenticated;

create or replace function public.set_account_status(p_account_type text)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $set_account_status$
declare
  v_user_id uuid := auth.uid();
  v_account_type text := public.normalize_account_type(p_account_type);
  v_role text := public.role_for_account_type(p_account_type);
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_account_type in ('admin', 'moderator', 'support') then
    raise exception 'Staff statuses cannot be assigned here';
  end if;

  if v_role = 'casting_agent' and not public.current_user_can_create_selections() then
    raise exception 'Client status requires admin approval';
  end if;

  insert into public.user_profiles (
    user_id,
    account_type,
    updated_at,
    last_seen_at
  )
  values (
    v_user_id,
    v_account_type,
    now(),
    now()
  )
  on conflict (user_id)
  do update set
    account_type = excluded.account_type,
    updated_at = now(),
    last_seen_at = now();

  insert into public.user_roles (user_id, role, updated_at)
  values (v_user_id, v_role, now())
  on conflict (user_id)
  do update set role = excluded.role, updated_at = now()
  where public.user_roles.role <> 'admin';
end;
$set_account_status$;

grant execute on function public.set_account_status(text) to authenticated;

create or replace function public.request_account_status(p_account_type text)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $request_account_status$
declare
  v_user_id uuid := auth.uid();
  v_account_type text := public.normalize_account_type(p_account_type);
  v_role text := public.role_for_account_type(p_account_type);
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_role <> 'casting_agent' then
    raise exception 'Only client statuses can be requested';
  end if;

  if public.current_user_can_create_selections() then
    perform public.set_account_status(v_account_type);
    return;
  end if;

  insert into public.user_profiles (
    user_id,
    account_type,
    updated_at,
    last_seen_at
  )
  values (
    v_user_id,
    'user',
    now(),
    now()
  )
  on conflict (user_id)
  do update set
    account_type = 'user',
    updated_at = now(),
    last_seen_at = now();

  insert into public.user_roles (user_id, role, updated_at)
  values (v_user_id, 'user', now())
  on conflict (user_id)
  do update set role = 'user', updated_at = now()
  where public.user_roles.role <> 'admin';

  insert into public.casting_agent_applications (
    user_id,
    status,
    requested_account_type,
    updated_at
  )
  values (
    v_user_id,
    'pending',
    v_account_type,
    now()
  )
  on conflict (user_id) where status = 'pending'
  do update set
    requested_account_type = excluded.requested_account_type,
    updated_at = now();
end;
$request_account_status$;

grant execute on function public.request_account_status(text)
  to authenticated;

create or replace function public.save_account_profile(p_profile jsonb)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $save_account_profile$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.user_profiles (
    user_id,
    email,
    phone,
    avatar_url,
    full_name,
    company_name,
    position,
    city,
    country,
    website,
    social_url,
    bio,
    updated_at,
    last_seen_at
  )
  values (
    v_user_id,
    nullif(btrim(coalesce(p_profile ->> 'email', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'phone', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'avatar_url', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'full_name', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'company_name', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'position', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'city', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'country', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'website', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'social_url', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'bio', '')), ''),
    now(),
    now()
  )
  on conflict (user_id)
  do update set
    email = excluded.email,
    phone = excluded.phone,
    avatar_url = excluded.avatar_url,
    full_name = excluded.full_name,
    company_name = excluded.company_name,
    position = excluded.position,
    city = excluded.city,
    country = excluded.country,
    website = excluded.website,
    social_url = excluded.social_url,
    bio = excluded.bio,
    updated_at = now(),
    last_seen_at = now();
end;
$save_account_profile$;

grant execute on function public.save_account_profile(jsonb)
  to authenticated;

create or replace function public.get_selection_chat_participants(p_chat_id uuid)
returns table (
  user_id uuid,
  full_name text,
  avatar_url text
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $get_selection_chat_participants$
  select
    up.user_id,
    up.full_name,
    up.avatar_url
  from public.selection_chats sc
  join public.user_profiles up
    on up.user_id in (sc.model_user_id, sc.agent_user_id)
  where sc.id = p_chat_id
    and auth.uid() in (sc.model_user_id, sc.agent_user_id);
$get_selection_chat_participants$;

grant execute on function public.get_selection_chat_participants(uuid)
  to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $handle_new_user$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_account_type text;
  v_role text;
begin
  v_account_type := public.normalize_account_type(
    coalesce(
      v_meta ->> 'account_type',
      v_meta ->> 'requested_account_type',
      'user'
    )
  );
  v_role := public.role_for_account_type(v_account_type);
  if v_role = 'casting_agent' then
    v_role := 'user';
  end if;

  insert into public.user_profiles (
    user_id,
    email,
    phone,
    full_name,
    avatar_url,
    auth_provider,
    account_type,
    updated_at,
    last_seen_at
  )
  values (
    new.id,
    new.email,
    new.phone,
    nullif(
      btrim(
        coalesce(
          v_meta ->> 'full_name',
          v_meta ->> 'name',
          v_meta ->> 'display_name',
          ''
        )
      ),
      ''
    ),
    nullif(btrim(coalesce(v_meta ->> 'avatar_url', v_meta ->> 'picture', '')), ''),
    coalesce(new.raw_app_meta_data ->> 'provider', ''),
    case when public.role_for_account_type(v_account_type) = 'casting_agent'
      then 'user'
      else v_account_type
    end,
    now(),
    now()
  )
  on conflict (user_id)
  do update set
    email = excluded.email,
    phone = excluded.phone,
    full_name = coalesce(excluded.full_name, public.user_profiles.full_name),
    avatar_url = coalesce(excluded.avatar_url, public.user_profiles.avatar_url),
    auth_provider = coalesce(nullif(excluded.auth_provider, ''), public.user_profiles.auth_provider),
    account_type = excluded.account_type,
    updated_at = now(),
    last_seen_at = now();

  insert into public.user_roles (user_id, role, updated_at)
  values (new.id, v_role, now())
  on conflict (user_id)
  do update set role = excluded.role, updated_at = now()
  where public.user_roles.role <> 'admin';

  return new;
exception
  when others then
    raise warning 'handle_new_user failed for %: %', new.id, sqlerrm;
    return new;
end;
$handle_new_user$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

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
