-- Enables voice messages in selection chats.
-- Apply this once before sending media_type = 'audio' messages.

do $$
declare
  v_constraint text;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.selection_chat_messages'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%media_type%'
  loop
    execute format(
      'alter table public.selection_chat_messages drop constraint if exists %I',
      v_constraint
    );
  end loop;

  alter table public.selection_chat_messages
    add constraint selection_chat_messages_media_type_check
    check (media_type in ('text', 'image', 'video', 'file', 'audio'));
end $$;
