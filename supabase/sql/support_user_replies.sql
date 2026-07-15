-- User replies in existing support tickets.
-- Apply after support_center_mvp.sql and support_admin_inbox.sql.

create or replace function public.handle_support_user_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket public.support_tickets%rowtype;
  v_staff record;
  v_message_count bigint;
begin
  if new.author_kind <> 'user' or new.is_internal then
    return new;
  end if;

  select * into v_ticket
  from public.support_tickets
  where id = new.ticket_id;

  if v_ticket.id is null then
    return new;
  end if;

  select count(*) into v_message_count
  from public.support_messages
  where ticket_id = new.ticket_id;

  -- The first message is already covered by the new-ticket notification.
  if v_message_count = 1 then
    return new;
  end if;

  update public.support_tickets
  set
    status = 'queued_for_admin',
    resolved_at = null,
    closed_at = null,
    updated_at = now()
  where id = new.ticket_id;

  if to_regprocedure('public.enqueue_app_notification(uuid,text,text,text,text,jsonb)') is not null then
    for v_staff in
      select distinct ur.user_id
      from public.user_roles ur
      where ur.role in ('admin', 'moderator', 'support')
        and ur.user_id <> v_ticket.user_id
    loop
      perform public.enqueue_app_notification(
        v_staff.user_id,
        'Новый ответ в поддержке',
        left(new.body, 220),
        '/admin_support',
        'support_user_reply',
        jsonb_build_object(
          'ticket_id', new.ticket_id,
          'send_email', true,
          'email_subject', 'PK Management: новый ответ пользователя'
        )
      );
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists support_user_reply_notify on public.support_messages;
create trigger support_user_reply_notify
after insert on public.support_messages
for each row execute function public.handle_support_user_reply();
