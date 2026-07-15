-- Per-user unread state for support conversations.
-- One administrator reading a ticket must not clear it for another administrator.

create table if not exists public.support_message_reads (
  message_id uuid not null references public.support_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists support_message_reads_user_idx
  on public.support_message_reads (user_id, read_at desc);

alter table public.support_message_reads enable row level security;

drop policy if exists "support_message_reads_select_own" on public.support_message_reads;
create policy "support_message_reads_select_own"
  on public.support_message_reads for select to authenticated
  using (user_id = auth.uid());

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
      (v.is_staff and m.author_kind = 'user')
      or
      (not v.is_staff and t.user_id = v.user_id and m.author_kind in ('admin', 'bot', 'system'))
    )
    and not exists (
      select 1
      from public.support_message_reads r
      where r.message_id = m.id and r.user_id = v.user_id
    )
  group by m.ticket_id;
$$;

create or replace function public.mark_support_ticket_read(p_ticket_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_staff boolean := public.current_user_is_support_staff();
  v_owner_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select user_id into v_owner_id
  from public.support_tickets
  where id = p_ticket_id;

  if v_owner_id is null or (not v_is_staff and v_owner_id <> v_user_id) then
    raise exception 'Access denied';
  end if;

  insert into public.support_message_reads (message_id, user_id)
  select m.id, v_user_id
  from public.support_messages m
  where m.ticket_id = p_ticket_id
    and m.author_id is distinct from v_user_id
    and (
      (v_is_staff and m.author_kind = 'user')
      or
      (not v_is_staff and m.author_kind in ('admin', 'bot', 'system'))
    )
  on conflict (message_id, user_id) do nothing;
end;
$$;

revoke all on function public.support_unread_counts() from public;
revoke all on function public.mark_support_ticket_read(uuid) from public;
grant execute on function public.support_unread_counts() to authenticated;
grant execute on function public.mark_support_ticket_read(uuid) to authenticated;
