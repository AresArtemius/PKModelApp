-- PK Management support center MVP.
-- Apply once in Supabase SQL Editor before enabling production tickets.

create extension if not exists pgcrypto;

create or replace function public.current_user_is_support_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('admin', 'moderator', 'support')
  );
$$;

revoke all on function public.current_user_is_support_staff() from public;
grant execute on function public.current_user_is_support_staff() to authenticated;

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  channel text not null default 'in_app'
    check (channel in ('in_app', 'telegram', 'email', 'admin')),
  category text not null
    check (category in ('account', 'profile', 'moderation', 'billing', 'casting', 'security', 'other')),
  subject text not null check (char_length(trim(subject)) between 3 and 160),
  status text not null default 'new'
    check (status in ('new', 'bot_answered', 'waiting_for_user', 'queued_for_admin', 'in_progress', 'resolved', 'closed')),
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'urgent')),
  assigned_to uuid references auth.users(id) on delete set null,
  related_type text,
  related_id text,
  first_response_at timestamptz,
  resolved_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  author_id uuid references auth.users(id) on delete set null,
  author_kind text not null
    check (author_kind in ('user', 'bot', 'admin', 'system')),
  body text not null check (char_length(trim(body)) between 1 and 5000),
  source text not null default 'in_app'
    check (source in ('in_app', 'telegram', 'email', 'admin', 'system')),
  is_internal boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists support_tickets_user_created_idx
  on public.support_tickets (user_id, created_at desc);
create index if not exists support_tickets_queue_idx
  on public.support_tickets (status, priority, updated_at desc);
create index if not exists support_messages_ticket_created_idx
  on public.support_messages (ticket_id, created_at);

alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;

drop policy if exists "Users can read own support tickets" on public.support_tickets;
create policy "Users can read own support tickets"
  on public.support_tickets for select
  using (user_id = auth.uid() or public.current_user_is_support_staff());

drop policy if exists "Users can create own support tickets" on public.support_tickets;
create policy "Users can create own support tickets"
  on public.support_tickets for insert
  with check (user_id = auth.uid());

drop policy if exists "Support staff can update tickets" on public.support_tickets;
create policy "Support staff can update tickets"
  on public.support_tickets for update
  using (public.current_user_is_support_staff())
  with check (public.current_user_is_support_staff());

drop policy if exists "Users can delete own support tickets" on public.support_tickets;
create policy "Users can delete own support tickets"
  on public.support_tickets for delete
  using (user_id = auth.uid());

drop policy if exists "Support staff can delete tickets" on public.support_tickets;
create policy "Support staff can delete tickets"
  on public.support_tickets for delete
  using (public.current_user_is_support_staff());

drop policy if exists "Ticket participants can read messages" on public.support_messages;
create policy "Ticket participants can read messages"
  on public.support_messages for select
  using (
    exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id
        and (t.user_id = auth.uid() or public.current_user_is_support_staff())
    )
    and (not is_internal or public.current_user_is_support_staff())
  );

drop policy if exists "Users can add messages to own tickets" on public.support_messages;
create policy "Users can add messages to own tickets"
  on public.support_messages for insert
  with check (
    author_id = auth.uid()
    and author_kind = 'user'
    and not is_internal
    and exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.user_id = auth.uid()
    )
  );

drop policy if exists "Support staff can add messages" on public.support_messages;
create policy "Support staff can add messages"
  on public.support_messages for insert
  with check (
    public.current_user_is_support_staff()
    and author_kind in ('admin', 'system')
  );

create or replace function public.create_support_ticket(
  p_category text,
  p_subject text,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.support_tickets (user_id, category, subject, status)
  values (auth.uid(), trim(p_category), trim(p_subject), 'queued_for_admin')
  returning id into v_ticket_id;

  insert into public.support_messages (
    ticket_id, author_id, author_kind, body, source
  ) values (
    v_ticket_id, auth.uid(), 'user', trim(p_message), 'in_app'
  );

  return v_ticket_id;
end;
$$;

revoke all on function public.create_support_ticket(text, text, text) from public;
grant execute on function public.create_support_ticket(text, text, text)
  to authenticated;

grant select on public.support_tickets to authenticated;
grant select, insert on public.support_messages to authenticated;
grant update on public.support_tickets to authenticated;
grant delete on public.support_tickets to authenticated;
