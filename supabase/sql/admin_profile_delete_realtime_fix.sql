-- Keep an owner's profile list in sync when an administrator deletes a
-- profile on another device. Safe to run repeatedly.

create or replace function public.admin_delete_profile(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_owner_user_id uuid;
  v_profile_name text;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can delete profiles';
  end if;

  select
    user_id,
    coalesce(nullif(btrim(full_name), ''), 'Без названия')
  into v_owner_user_id, v_profile_name
  from public.profiles
  where id = p_profile_id
  limit 1;

  if not found then
    raise exception 'Profile not found';
  end if;

  perform public.admin_record_backoffice_action(
    'profile_deleted',
    'Удалена анкета',
    'Админ удалил анкету из back-office таблицы.',
    'profiles',
    p_profile_id,
    v_profile_name,
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

  begin
    if v_owner_user_id is not null
       and to_regprocedure(
         'public.enqueue_app_notification(uuid,text,text,text,text,jsonb)'
       ) is not null then
      perform public.enqueue_app_notification(
        v_owner_user_id,
        'Анкета удалена',
        format(
          'Анкета «%s» была удалена администратором.',
          v_profile_name
        ),
        '/me',
        'profile_moderation',
        jsonb_build_object(
          'profile_id', p_profile_id,
          'profile_name', v_profile_name,
          'status', 'deleted',
          'action', 'deleted'
        )
      );
    end if;
  exception
    when others then
      raise warning 'Could not enqueue profile deletion notification: %', sqlerrm;
  end;
end;
$$;

revoke all on function public.admin_delete_profile(uuid) from public;
revoke all on function public.admin_delete_profile(uuid) from anon;
grant execute on function public.admin_delete_profile(uuid) to authenticated;
