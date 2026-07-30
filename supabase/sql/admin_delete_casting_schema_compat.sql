-- Fixes admin casting deletion for databases where castings.created_by
-- is not present. Safe to apply repeatedly in the Supabase SQL editor.

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
        select id, title, project_stage, created_at
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

revoke all on function public.admin_delete_casting(uuid) from public;
grant execute on function public.admin_delete_casting(uuid) to authenticated;
