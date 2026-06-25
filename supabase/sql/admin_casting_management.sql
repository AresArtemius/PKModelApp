-- Admin tools for castings.
-- Run this whole file in Supabase SQL Editor.

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

grant execute on function public.admin_delete_casting(uuid) to authenticated;
