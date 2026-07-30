-- Edit own text messages and permanently delete a chat for both participants.
-- Apply after selection_chats.sql.

alter table public.selection_chat_messages
  add column if not exists edited_at timestamptz;

create or replace function public.delete_selection_chat_for_everyone(
  p_chat_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $delete_selection_chat_for_everyone$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.selection_chats
  where id = p_chat_id
    and (
      model_user_id = v_user_id
      or agent_user_id = v_user_id
      or public.current_user_is_admin()
    );

  if not found then
    raise exception 'Chat not found or access denied';
  end if;
end;
$delete_selection_chat_for_everyone$;

revoke all on function public.delete_selection_chat_for_everyone(uuid)
  from public;
grant execute on function public.delete_selection_chat_for_everyone(uuid)
  to authenticated;
