-- Self-service account deletion.
-- Run in Supabase SQL Editor after the core tables exist.
-- Important: run the whole file at once, not a selected fragment.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $delete_my_account$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if to_regclass('public.push_device_tokens') is not null then
    execute 'delete from public.push_device_tokens where user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.app_notifications') is not null then
    execute 'delete from public.app_notifications where user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.casting_agent_folder_items') is not null then
    execute 'delete from public.casting_agent_folder_items where user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.casting_agent_folders') is not null then
    execute 'delete from public.casting_agent_folders where user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.profile_reports') is not null then
    execute 'delete from public.profile_reports where reporter_user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.blocked_users') is not null then
    execute 'delete from public.blocked_users where blocker_user_id = $1 or blocked_user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.profile_analytics_events') is not null then
    execute 'update public.profile_analytics_events set actor_user_id = null where actor_user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.casting_responses') is not null then
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'casting_responses'
        and column_name = 'model_user_id'
    ) then
      execute 'delete from public.casting_responses where model_user_id = $1'
        using v_user_id;
    end if;
  end if;

  if to_regclass('public.selection_chat_messages') is not null then
    execute 'delete from public.selection_chat_messages where sender_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.casting_chat_messages') is not null then
    execute 'delete from public.casting_chat_messages where sender_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.user_billing_profiles') is not null then
    execute 'delete from public.user_billing_profiles where user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.casting_agent_applications') is not null then
    execute 'update public.casting_agent_applications set decided_by = null where decided_by = $1'
      using v_user_id;
    execute 'delete from public.casting_agent_applications where user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.user_roles') is not null then
    execute 'delete from public.user_roles where user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.user_profiles') is not null then
    execute 'delete from public.user_profiles where user_id = $1'
      using v_user_id;
  end if;

  if to_regclass('public.selections') is not null then
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'selections'
        and column_name = 'created_by'
    ) then
      execute 'delete from public.selections where created_by = $1'
        using v_user_id;
    end if;
  end if;

  if to_regclass('public.castings') is not null then
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'castings'
        and column_name = 'created_by'
    ) then
      execute 'delete from public.castings where created_by = $1'
        using v_user_id;
    end if;
  end if;

  if to_regclass('public.profiles') is not null then
    execute 'delete from public.profiles where user_id = $1'
      using v_user_id;
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'verified_by'
    ) then
      execute 'update public.profiles set verified_by = null where verified_by = $1'
        using v_user_id;
    end if;
  end if;

  delete from auth.users
  where id = v_user_id;
end;
$delete_my_account$;

grant execute on function public.delete_my_account() to authenticated;

notify pgrst, 'reload schema';
