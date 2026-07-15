-- Exclusive assignment of support tickets to one staff member.
-- Apply after support_center_mvp.sql, support_admin_inbox.sql,
-- support_user_replies.sql and support_unread_messages.sql.

create or replace function public.claim_support_ticket(p_ticket_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_claimed_id uuid;
begin
  if v_user_id is null or not public.current_user_is_support_staff() then
    raise exception 'Access denied';
  end if;

  update public.support_tickets
  set assigned_to = v_user_id,
      status = case when status = 'queued_for_admin' then 'in_progress' else status end,
      updated_at = now()
  where id = p_ticket_id
    and (assigned_to is null or assigned_to = v_user_id)
  returning id into v_claimed_id;

  return v_claimed_id is not null;
end;
$$;

revoke all on function public.claim_support_ticket(uuid) from public;
grant execute on function public.claim_support_ticket(uuid) to authenticated;

-- A public reply may only be sent by the assigned staff member.
drop policy if exists "Support staff can add messages" on public.support_messages;
drop policy if exists "Assigned support staff can add messages" on public.support_messages;
create policy "Assigned support staff can add messages"
  on public.support_messages for insert
  with check (
    public.current_user_is_support_staff()
    and author_id = auth.uid()
    and author_kind in ('admin', 'system')
    and exists (
      select 1
      from public.support_tickets t
      where t.id = ticket_id
        and t.assigned_to = auth.uid()
    )
  );

-- Unassigned tickets appear in the shared queue. We do not send the same
-- push/email to every administrator; notifications start after assignment.
create or replace function public.notify_support_ticket_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.assigned_to is not null
     and new.assigned_to <> new.user_id
     and to_regprocedure('public.enqueue_app_notification(uuid,text,text,text,text,jsonb)') is not null then
    perform public.enqueue_app_notification(
      new.assigned_to,
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
  end if;
  return new;
end;
$$;

-- A user's follow-up is delivered only to the assigned administrator.
create or replace function public.handle_support_user_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket public.support_tickets%rowtype;
  v_message_count bigint;
begin
  if new.author_kind <> 'user' or new.is_internal then
    return new;
  end if;

  select * into v_ticket from public.support_tickets where id = new.ticket_id;
  if v_ticket.id is null then return new; end if;

  select count(*) into v_message_count
  from public.support_messages
  where ticket_id = new.ticket_id;

  if v_message_count = 1 then return new; end if;

  update public.support_tickets
  set status = 'queued_for_admin', resolved_at = null, closed_at = null, updated_at = now()
  where id = new.ticket_id;

  if v_ticket.assigned_to is not null
     and to_regprocedure('public.enqueue_app_notification(uuid,text,text,text,text,jsonb)') is not null then
    perform public.enqueue_app_notification(
      v_ticket.assigned_to,
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
  end if;

  return new;
end;
$$;

-- Queue unread items are visible to everyone until claimed. After claiming,
-- only the assigned staff member receives the unread counter.
create or replace function public.support_unread_counts()
returns table(ticket_id uuid, unread_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  with viewer as (
    select auth.uid() as user_id, public.current_user_is_support_staff() as is_staff
  )
  select m.ticket_id, count(*)::bigint
  from public.support_messages m
  join public.support_tickets t on t.id = m.ticket_id
  cross join viewer v
  where v.user_id is not null
    and m.author_id is distinct from v.user_id
    and (
      (v.is_staff and m.author_kind = 'user'
        and (t.assigned_to is null or t.assigned_to = v.user_id))
      or
      (not v.is_staff and t.user_id = v.user_id
        and m.author_kind in ('admin', 'bot', 'system'))
    )
    and not exists (
      select 1 from public.support_message_reads r
      where r.message_id = m.id and r.user_id = v.user_id
    )
  group by m.ticket_id;
$$;

revoke all on function public.support_unread_counts() from public;
grant execute on function public.support_unread_counts() to authenticated;
