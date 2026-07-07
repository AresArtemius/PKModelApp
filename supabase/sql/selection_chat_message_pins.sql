-- Pinned messages inside selection chats.
-- Apply this once in Supabase SQL editor or through the Supabase CLI.

alter table public.selection_chat_messages
  add column if not exists pinned_at timestamptz,
  add column if not exists pinned_by uuid references auth.users(id) on delete set null;

create index if not exists selection_chat_messages_chat_pinned_idx
  on public.selection_chat_messages (chat_id, pinned_at desc)
  where pinned_at is not null and deleted_at is null;

create or replace function public.set_selection_chat_message_pinned(
  p_message_id uuid,
  p_pinned boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $set_selection_chat_message_pinned$
declare
  v_chat_id uuid;
begin
  select m.chat_id
  into v_chat_id
  from public.selection_chat_messages m
  join public.selection_chats sc on sc.id = m.chat_id
  where m.id = p_message_id
    and m.deleted_at is null
    and (
      auth.uid() = sc.model_user_id
      or auth.uid() = sc.agent_user_id
      or public.current_user_is_admin()
    );

  if v_chat_id is null then
    raise exception 'Message not found or access denied' using errcode = '42501';
  end if;

  update public.selection_chat_messages
  set
    pinned_at = case when coalesce(p_pinned, false) then now() else null end,
    pinned_by = case when coalesce(p_pinned, false) then auth.uid() else null end
  where id = p_message_id;
end;
$set_selection_chat_message_pinned$;

grant execute on function public.set_selection_chat_message_pinned(uuid, boolean)
  to authenticated;
