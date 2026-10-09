-- Step 35. Direct chats: a conversation between two accounts that is not
-- tied to a casting (the «Написать» button on a public account page /@tag).
-- Run this whole file in the Supabase SQL Editor after selection_chats.sql
-- and selection_chat_backend_v2.sql. Safe to run multiple times.
--
-- What it does:
--   1. selection_chats / selection_chat_contexts accept rows without a
--      casting (selection_id, profile_id become nullable); `kind` tells
--      'selection' from 'direct'; `created_by` remembers who started it.
--   2. ensure_direct_chat(other_user) returns the one chat for the account
--      pair (reusing a casting chat if there already is one), creating a
--      direct one otherwise. Refused when either side blocked the other.
--   3. direct_chat_states() lets the client build the «Запросы» folder: a
--      direct chat started by someone else that I have not answered yet.
--   4. Messages: a blocked pair cannot write to each other.

alter table public.selection_chats
  alter column selection_id drop not null,
  alter column profile_id drop not null,
  add column if not exists kind text not null default 'selection',
  add column if not exists created_by uuid references auth.users(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'selection_chats_kind_check'
  ) then
    alter table public.selection_chats
      add constraint selection_chats_kind_check
      check (kind in ('selection', 'direct'));
  end if;
end $$;

alter table public.selection_chat_contexts
  alter column selection_id drop not null,
  alter column profile_id drop not null,
  add column if not exists kind text not null default 'selection';

create index if not exists selection_chats_kind_idx
  on public.selection_chats (kind)
  where kind = 'direct';

-- ---------------------------------------------------------------------------
-- Blocked pairs cannot write to each other (either direction).
-- ---------------------------------------------------------------------------

create or replace function public.chat_pair_is_blocked(p_chat_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.selection_chats sc
    join public.blocked_users b
      on (b.blocker_user_id = sc.model_user_id and b.blocked_user_id = sc.agent_user_id)
      or (b.blocker_user_id = sc.agent_user_id and b.blocked_user_id = sc.model_user_id)
    where sc.id = p_chat_id
  );
$$;

grant execute on function public.chat_pair_is_blocked(uuid) to authenticated;

drop policy if exists "Selection chat participants can send messages"
  on public.selection_chat_messages;

create policy "Selection chat participants can send messages"
  on public.selection_chat_messages
  for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and exists (
      select 1
      from public.selection_chats sc
      where sc.id = selection_chat_messages.chat_id
        and (
          auth.uid() = sc.model_user_id
          or auth.uid() = sc.agent_user_id
          or public.current_user_is_admin()
        )
    )
    and (
      public.current_user_is_admin()
      or not public.chat_pair_is_blocked(selection_chat_messages.chat_id)
    )
  );

-- ---------------------------------------------------------------------------
-- ensure_direct_chat(other): one chat per account pair.
-- ---------------------------------------------------------------------------

create or replace function public.ensure_direct_chat(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_chat uuid;
  v_i_am_model boolean;
begin
  if v_me is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_other_user_id is null or p_other_user_id = v_me then
    raise exception 'invalid counterpart' using errcode = '22023';
  end if;
  if not exists (select 1 from public.user_profiles up where up.user_id = p_other_user_id) then
    raise exception 'account not found' using errcode = 'P0002';
  end if;
  if exists (
    select 1
    from public.blocked_users b
    where (b.blocker_user_id = v_me and b.blocked_user_id = p_other_user_id)
       or (b.blocker_user_id = p_other_user_id and b.blocked_user_id = v_me)
  ) then
    raise exception 'chat blocked' using errcode = '42501';
  end if;

  -- The pair already talks somewhere (a casting chat or an earlier direct
  -- one): reuse it and bring it back if I had deleted it.
  select sc.id into v_chat
  from public.selection_chats sc
  where (sc.model_user_id = v_me and sc.agent_user_id = p_other_user_id)
     or (sc.model_user_id = p_other_user_id and sc.agent_user_id = v_me)
  order by sc.updated_at desc
  limit 1;

  if v_chat is not null then
    update public.selection_chats
    set
      model_deleted_at = case when model_user_id = v_me then null else model_deleted_at end,
      agent_deleted_at = case when agent_user_id = v_me then null else agent_deleted_at end
    where id = v_chat;
    return v_chat;
  end if;

  -- Orientation: whoever has a professional profile is the «model» side so
  -- the rest of the chat code (roles, filters) keeps working; the other
  -- becomes the «agent» side.
  v_i_am_model :=
    exists (select 1 from public.profiles p where p.user_id = v_me)
    and not exists (select 1 from public.profiles p where p.user_id = p_other_user_id);

  insert into public.selection_chats (
    selection_id, profile_id, model_user_id, agent_user_id, kind, created_by
  )
  values (
    null,
    null,
    case when v_i_am_model then v_me else p_other_user_id end,
    case when v_i_am_model then p_other_user_id else v_me end,
    'direct',
    v_me
  )
  returning id into v_chat;

  insert into public.selection_chat_contexts (
    chat_id, selection_id, profile_id, created_by, kind
  )
  values (v_chat, null, null, v_me, 'direct');

  return v_chat;
end;
$$;

grant execute on function public.ensure_direct_chat(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- direct_chat_states(): for the «Запросы» folder.
-- ---------------------------------------------------------------------------

drop function if exists public.direct_chat_states();

create or replace function public.direct_chat_states()
returns table (
  chat_id uuid,
  created_by uuid,
  i_replied boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    sc.id as chat_id,
    sc.created_by,
    exists (
      select 1
      from public.selection_chat_messages m
      where m.chat_id = sc.id
        and m.sender_id = auth.uid()
        and m.deleted_at is null
    ) as i_replied
  from public.selection_chats sc
  where sc.kind = 'direct'
    and auth.uid() is not null
    and (sc.model_user_id = auth.uid() or sc.agent_user_id = auth.uid());
$$;

grant execute on function public.direct_chat_states() to authenticated;
