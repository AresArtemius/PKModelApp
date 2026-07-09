-- Admin back-office actions used by the Web-first admin tables.
-- Run this whole file in Supabase SQL Editor after account_public_roles.sql.

alter table public.user_roles
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.user_roles
  drop constraint if exists user_roles_role_check;

alter table public.user_roles
  add constraint user_roles_role_check
  check (lower(role) in ('user', 'admin', 'casting_agent'))
  not valid;

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

create or replace function public.admin_record_backoffice_action(
  p_action_type text,
  p_title text,
  p_description text default '',
  p_target_table text default '',
  p_target_id uuid default null,
  p_target_text text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_name text := '';
  v_actor_company text := '';
begin
  if v_actor_id is null then
    return;
  end if;

  if not public.current_user_is_admin() then
    return;
  end if;

  select
    coalesce(full_name, ''),
    coalesce(company_name, '')
  into v_actor_name, v_actor_company
  from public.user_profiles
  where user_id = v_actor_id
  limit 1;

  insert into public.admin_action_logs (
    actor_user_id,
    actor_name,
    actor_company,
    action_type,
    title,
    description,
    target_table,
    target_id,
    target_text,
    status,
    metadata
  )
  values (
    v_actor_id,
    coalesce(v_actor_name, ''),
    coalesce(v_actor_company, ''),
    coalesce(p_action_type, ''),
    coalesce(p_title, ''),
    coalesce(p_description, ''),
    coalesce(p_target_table, ''),
    p_target_id,
    coalesce(p_target_text, ''),
    'done',
    coalesce(p_metadata, '{}'::jsonb)
  );
exception
  when others then
    return;
end;
$$;

create or replace function public.admin_set_user_account_access(
  p_user_id uuid,
  p_account_type text
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_account_type text := public.normalize_account_type(p_account_type);
  v_role text := public.role_for_account_type(p_account_type);
  v_previous_account_type text := '';
  v_previous_role text := '';
  v_target_text text := '';
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can change account access';
  end if;

  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  select
    coalesce(up.account_type, ''),
    coalesce(
      nullif(up.full_name, ''),
      nullif(up.company_name, ''),
      nullif(up.email, ''),
      nullif(up.phone, ''),
      p_user_id::text
    )
  into v_previous_account_type, v_target_text
  from public.user_profiles up
  where up.user_id = p_user_id
  limit 1;

  select coalesce(role, '')
  into v_previous_role
  from public.user_roles
  where user_id = p_user_id
  limit 1;

  v_target_text := coalesce(nullif(v_target_text, ''), p_user_id::text);

  perform public.admin_record_backoffice_action(
    'account_access_changed',
    'Изменена роль аккаунта',
    concat(
      'Роль: ',
      coalesce(nullif(v_previous_role, ''), '—'),
      ' → ',
      v_role,
      '; статус аккаунта: ',
      coalesce(nullif(v_previous_account_type, ''), '—'),
      ' → ',
      v_account_type
    ),
    'user_profiles',
    p_user_id,
    v_target_text,
    jsonb_build_object(
      'user_id', p_user_id,
      'previous_role', v_previous_role,
      'new_role', v_role,
      'previous_account_type', v_previous_account_type,
      'new_account_type', v_account_type
    )
  );

  insert into public.user_roles (user_id, role, updated_at)
  values (p_user_id, v_role, now())
  on conflict (user_id)
  do update set role = excluded.role, updated_at = now();

  update public.user_profiles
  set account_type = v_account_type,
      updated_at = now()
  where user_id = p_user_id;
end;
$$;

create or replace function public.admin_delete_user_profile(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can delete account profiles';
  end if;

  perform public.admin_record_backoffice_action(
    'account_profile_deleted',
    'Удален профиль аккаунта',
    'Админ удалил профиль аккаунта. Auth-пользователь не удаляется.',
    'user_profiles',
    p_user_id,
    coalesce((
      select coalesce(nullif(full_name, ''), nullif(company_name, ''), nullif(email, ''), nullif(phone, ''), p_user_id::text)
      from public.user_profiles
      where user_id = p_user_id
      limit 1
    ), p_user_id::text),
    coalesce((
      select to_jsonb(up)
      from (
        select user_id, email, phone, account_tag, full_name, company_name, account_type, city, country
        from public.user_profiles
        where user_id = p_user_id
        limit 1
      ) up
    ), '{}'::jsonb)
  );

  delete from public.user_profiles
  where user_id = p_user_id;

  if not found then
    raise exception 'Account profile not found';
  end if;
end;
$$;

create or replace function public.admin_delete_profile(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can delete profiles';
  end if;

  perform public.admin_record_backoffice_action(
    'profile_deleted',
    'Удалена анкета',
    'Админ удалил анкету из back-office таблицы.',
    'profiles',
    p_profile_id,
    coalesce((
      select coalesce(nullif(full_name, ''), p_profile_id::text)
      from public.profiles
      where id = p_profile_id
      limit 1
    ), p_profile_id::text),
    coalesce((
      select to_jsonb(p)
      from (
        select id, user_id, full_name, profile_type, status, city, country
        from public.profiles
        where id = p_profile_id
        limit 1
      ) p
    ), '{}'::jsonb)
  );

  if to_regclass('public.selection_items') is not null then
    delete from public.selection_items
    where profile_id = p_profile_id;
  end if;

  if to_regclass('public.casting_responses') is not null then
    delete from public.casting_responses
    where profile_id = p_profile_id;
  end if;

  if to_regclass('public.casting_agent_folder_items') is not null then
    delete from public.casting_agent_folder_items
    where profile_id = p_profile_id;
  end if;

  if to_regclass('public.casting_agent_model_notes') is not null then
    delete from public.casting_agent_model_notes
    where profile_id = p_profile_id;
  end if;

  if to_regclass('public.casting_chats') is not null then
    delete from public.casting_chats
    where profile_id = p_profile_id;
  end if;

  delete from public.profiles
  where id = p_profile_id;

  if not found then
    raise exception 'Profile not found';
  end if;
end;
$$;

create or replace function public.admin_delete_casting(p_casting_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can delete castings';
  end if;

  perform public.admin_record_backoffice_action(
    'casting_deleted',
    'Удален кастинг',
    'Админ удалил кастинг из back-office таблицы.',
    'castings',
    p_casting_id,
    coalesce((
      select coalesce(nullif(title, ''), p_casting_id::text)
      from public.castings
      where id = p_casting_id
      limit 1
    ), p_casting_id::text),
    coalesce((
      select to_jsonb(c)
      from (
        select id, title, project_stage, created_by, created_at
        from public.castings
        where id = p_casting_id
        limit 1
      ) c
    ), '{}'::jsonb)
  );

  if to_regclass('public.casting_chat_messages') is not null
     and to_regclass('public.casting_chats') is not null then
    delete from public.casting_chat_messages m
    using public.casting_chats c
    where m.chat_id = c.id
      and c.casting_id = p_casting_id;
  end if;

  if to_regclass('public.casting_chats') is not null then
    delete from public.casting_chats
    where casting_id = p_casting_id;
  end if;

  if to_regclass('public.casting_responses') is not null then
    delete from public.casting_responses
    where casting_id = p_casting_id;
  end if;

  delete from public.castings
  where id = p_casting_id;

  if not found then
    raise exception 'Casting not found';
  end if;
end;
$$;

create or replace function public.admin_delete_selection(p_selection_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can delete selections';
  end if;

  perform public.admin_record_backoffice_action(
    'selection_deleted',
    'Удалена подборка',
    'Админ удалил подборку из back-office таблицы.',
    'selections',
    p_selection_id,
    coalesce((
      select coalesce(nullif(title, ''), p_selection_id::text)
      from public.selections
      where id = p_selection_id
      limit 1
    ), p_selection_id::text),
    coalesce((
      select to_jsonb(s)
      from (
        select id, title, status, is_public, client_name, brand_name, created_by, created_at
        from public.selections
        where id = p_selection_id
        limit 1
      ) s
    ), '{}'::jsonb)
  );

  if to_regclass('public.selection_chat_messages') is not null
     and to_regclass('public.selection_chats') is not null then
    delete from public.selection_chat_messages m
    using public.selection_chats c
    where m.chat_id = c.id
      and c.selection_id = p_selection_id;
  end if;

  if to_regclass('public.selection_chat_typing_states') is not null
     and to_regclass('public.selection_chats') is not null then
    delete from public.selection_chat_typing_states t
    using public.selection_chats c
    where t.chat_id = c.id
      and c.selection_id = p_selection_id;
  end if;

  if to_regclass('public.selection_chat_read_states') is not null
     and to_regclass('public.selection_chats') is not null then
    delete from public.selection_chat_read_states r
    using public.selection_chats c
    where r.chat_id = c.id
      and c.selection_id = p_selection_id;
  end if;

  if to_regclass('public.selection_chats') is not null then
    delete from public.selection_chats
    where selection_id = p_selection_id;
  end if;

  if to_regclass('public.selection_items') is not null then
    delete from public.selection_items
    where selection_id = p_selection_id;
  end if;

  delete from public.selections
  where id = p_selection_id;

  if not found then
    raise exception 'Selection not found';
  end if;
end;
$$;

grant execute on function public.admin_set_user_account_access(uuid, text)
  to authenticated;
revoke execute on function public.admin_record_backoffice_action(
  text,
  text,
  text,
  text,
  uuid,
  text,
  jsonb
) from public, anon, authenticated;
grant execute on function public.admin_delete_user_profile(uuid)
  to authenticated;
grant execute on function public.admin_delete_profile(uuid)
  to authenticated;
grant execute on function public.admin_delete_casting(uuid)
  to authenticated;
grant execute on function public.admin_delete_selection(uuid)
  to authenticated;

notify pgrst, 'reload schema';
