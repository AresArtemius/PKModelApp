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
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can change account access';
  end if;

  if p_user_id is null then
    raise exception 'User id is required';
  end if;

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
grant execute on function public.admin_delete_user_profile(uuid)
  to authenticated;
grant execute on function public.admin_delete_profile(uuid)
  to authenticated;
grant execute on function public.admin_delete_casting(uuid)
  to authenticated;
grant execute on function public.admin_delete_selection(uuid)
  to authenticated;

notify pgrst, 'reload schema';
