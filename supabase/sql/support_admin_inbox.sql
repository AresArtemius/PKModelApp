-- Admin support inbox and notifications.
-- Apply after support_center_mvp.sql and push_notifications.sql.

create or replace function public.notify_support_ticket_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff record;
begin
  if to_regprocedure('public.enqueue_app_notification(uuid,text,text,text,text,jsonb)') is null then
    return new;
  end if;

  for v_staff in
    select distinct ur.user_id
    from public.user_roles ur
    where ur.role in ('admin', 'moderator', 'support')
      and ur.user_id <> new.user_id
  loop
    perform public.enqueue_app_notification(
      v_staff.user_id,
      'Новое обращение в поддержку',
      left(new.subject, 220),
      '/admin_support',
      'support_ticket_created',
      jsonb_build_object(
        'ticket_id', new.id,
        'category', new.category,
        'send_email', true,
        'email_subject', 'PK Management: новое обращение в поддержку'
      )
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists support_ticket_created_notify on public.support_tickets;
create trigger support_ticket_created_notify
after insert on public.support_tickets
for each row execute function public.notify_support_ticket_created();

create or replace function public.notify_support_admin_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket public.support_tickets%rowtype;
begin
  if new.author_kind <> 'admin' or new.is_internal then
    return new;
  end if;

  select * into v_ticket
  from public.support_tickets
  where id = new.ticket_id;

  if v_ticket.id is null then
    return new;
  end if;

  if to_regprocedure('public.enqueue_app_notification(uuid,text,text,text,text,jsonb)') is not null then
    perform public.enqueue_app_notification(
      v_ticket.user_id,
      'Ответ поддержки',
      left(new.body, 220),
      '/support',
      'support_reply',
      jsonb_build_object(
        'ticket_id', new.ticket_id,
        'send_email', true,
        'email_subject', 'PK Management: ответ поддержки'
      )
    );
  end if;

  update public.support_tickets
  set
    status = 'waiting_for_user',
    first_response_at = coalesce(first_response_at, now()),
    updated_at = now()
  where id = new.ticket_id;

  return new;
end;
$$;

drop trigger if exists support_admin_reply_notify on public.support_messages;
create trigger support_admin_reply_notify
after insert on public.support_messages
for each row execute function public.notify_support_admin_reply();

