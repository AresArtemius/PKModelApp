-- Pinned and archived state for chat list.
-- Run after selection_chats.sql.

alter table public.selection_chats
  add column if not exists model_pinned_at timestamptz,
  add column if not exists agent_pinned_at timestamptz,
  add column if not exists model_archived_at timestamptz,
  add column if not exists agent_archived_at timestamptz;

create index if not exists selection_chats_model_pinned_idx
  on public.selection_chats (model_user_id, model_pinned_at desc);

create index if not exists selection_chats_agent_pinned_idx
  on public.selection_chats (agent_user_id, agent_pinned_at desc);

create or replace function public.set_selection_chat_pinned(
  p_chat_id uuid,
  p_pinned boolean
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $set_selection_chat_pinned$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.selection_chats
  set
    model_pinned_at = case
      when model_user_id = v_user_id then
        case when coalesce(p_pinned, false) then now() else null end
      else model_pinned_at
    end,
    agent_pinned_at = case
      when agent_user_id = v_user_id then
        case when coalesce(p_pinned, false) then now() else null end
      else agent_pinned_at
    end,
    updated_at = now()
  where id = p_chat_id
    and (model_user_id = v_user_id or agent_user_id = v_user_id);
end;
$set_selection_chat_pinned$;

grant execute on function public.set_selection_chat_pinned(uuid, boolean)
  to authenticated;

create or replace function public.set_selection_chat_archived(
  p_chat_id uuid,
  p_archived boolean
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $set_selection_chat_archived$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.selection_chats
  set
    model_archived_at = case
      when model_user_id = v_user_id then
        case when coalesce(p_archived, false) then now() else null end
      else model_archived_at
    end,
    agent_archived_at = case
      when agent_user_id = v_user_id then
        case when coalesce(p_archived, false) then now() else null end
      else agent_archived_at
    end,
    updated_at = now()
  where id = p_chat_id
    and (model_user_id = v_user_id or agent_user_id = v_user_id);
end;
$set_selection_chat_archived$;

grant execute on function public.set_selection_chat_archived(uuid, boolean)
  to authenticated;
