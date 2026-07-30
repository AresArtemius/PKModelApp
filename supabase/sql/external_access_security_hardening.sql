-- Hardens public and authenticated entry points outside the admin UI.
-- Apply after account_merge_requests.sql, push_notifications.sql,
-- selection_chats.sql and public_selection_client_feedback.sql.

create extension if not exists pgcrypto;

-- A phone number must never be usable as an anonymous email lookup.
revoke all on function public.resolve_auth_email_by_phone(text) from public;
revoke all on function public.resolve_auth_email_by_phone(text) from anon;
revoke all on function public.resolve_auth_email_by_phone(text) from authenticated;

-- The generic notification primitive is for trusted database code only.
revoke all on function public.enqueue_app_notification(
  uuid, text, text, text, text, jsonb
) from public;
revoke all on function public.enqueue_app_notification(
  uuid, text, text, text, text, jsonb
) from anon;
revoke all on function public.enqueue_app_notification(
  uuid, text, text, text, text, jsonb
) from authenticated;
grant execute on function public.enqueue_app_notification(
  uuid, text, text, text, text, jsonb
) to service_role;

create or replace function public.enqueue_my_security_notification(
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user_id uuid := auth.uid();
  v_type text := lower(btrim(coalesce(p_type, '')));
  v_data jsonb := coalesce(p_data, '{}'::jsonb) - 'email_to';
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if v_type not in (
    'security_new_login',
    'security_password_changed',
    'security_email_change_requested',
    'security_phone_changed'
  ) then
    raise exception 'Unsupported security notification type';
  end if;

  v_data := v_data || jsonb_build_object('send_email', true);

  return public.enqueue_app_notification(
    v_user_id,
    left(coalesce(p_title, ''), 160),
    left(coalesce(p_body, ''), 1000),
    '/notifications',
    v_type,
    v_data
  );
end;
$$;

revoke all on function public.enqueue_my_security_notification(
  text, text, text, jsonb
) from public;
grant execute on function public.enqueue_my_security_notification(
  text, text, text, jsonb
) to authenticated;

create or replace function public.enqueue_selection_chat_mention(
  p_chat_id uuid,
  p_body text,
  p_mention_tag text
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_sender_id uuid := auth.uid();
  v_target_id uuid;
  v_tag text := lower(btrim(coalesce(p_mention_tag, '')));
begin
  if v_sender_id is null then
    raise exception 'Authentication required';
  end if;

  select case
    when sc.model_user_id = v_sender_id then sc.agent_user_id
    when sc.agent_user_id = v_sender_id then sc.model_user_id
    else null
  end
  into v_target_id
  from public.selection_chats sc
  join public.user_profiles up
    on up.user_id = case
      when sc.model_user_id = v_sender_id then sc.agent_user_id
      when sc.agent_user_id = v_sender_id then sc.model_user_id
      else null
    end
  where sc.id = p_chat_id
    and v_sender_id in (sc.model_user_id, sc.agent_user_id)
    and lower(btrim(coalesce(up.account_tag, ''))) = v_tag
    and lower(coalesce(up.account_tag_visibility, 'public')) <> 'hidden'
  limit 1;

  if v_target_id is null then
    raise exception 'Mention target is not a visible chat participant';
  end if;

  return public.enqueue_app_notification(
    v_target_id,
    'Вас упомянули в чате',
    left(coalesce(p_body, ''), 120),
    '/chat/' || p_chat_id::text,
    'chat_message',
    jsonb_build_object(
      'chat_id', p_chat_id,
      'mention_tag', v_tag,
      'sender_id', v_sender_id
    )
  );
end;
$$;

revoke all on function public.enqueue_selection_chat_mention(
  uuid, text, text
) from public;
grant execute on function public.enqueue_selection_chat_mention(
  uuid, text, text
) to authenticated;

-- Public feedback requires a selection-specific access token. The browser key
-- remains a separate identifier so several client browsers can leave feedback.
create table if not exists public.selection_feedback_access_tokens (
  id uuid primary key default gen_random_uuid(),
  selection_id uuid not null
    references public.selections(id) on delete cascade,
  token_hash text not null unique,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index if not exists selection_feedback_access_tokens_selection_idx
  on public.selection_feedback_access_tokens(selection_id, created_at desc);

alter table public.selection_feedback_access_tokens enable row level security;

create or replace function public.create_selection_feedback_access_token(
  p_selection_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_token text := encode(gen_random_bytes(32), 'hex');
begin
  if not exists (
    select 1
    from public.selections s
    where s.id = p_selection_id
      and (
        s.created_by = auth.uid()
        or public.current_user_is_admin()
      )
  ) then
    raise exception 'Selection not found or access denied';
  end if;

  insert into public.selection_feedback_access_tokens (
    selection_id,
    token_hash,
    created_by
  )
  values (
    p_selection_id,
    encode(digest(v_token, 'sha256'), 'hex'),
    auth.uid()
  );

  return v_token;
end;
$$;

revoke all on function public.create_selection_feedback_access_token(uuid)
  from public;
grant execute on function public.create_selection_feedback_access_token(uuid)
  to authenticated;

create or replace function public.selection_feedback_token_is_valid(
  p_selection_id uuid,
  p_access_token text
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.selections s
    join public.selection_feedback_access_tokens t
      on t.selection_id = s.id
    where s.id = p_selection_id
      and s.is_public
      and t.revoked_at is null
      and t.token_hash =
        encode(digest(btrim(coalesce(p_access_token, '')), 'sha256'), 'hex')
  );
$$;

revoke all on function public.selection_feedback_token_is_valid(uuid, text)
  from public;

create or replace function public.revoke_selection_feedback_tokens_on_unpublish()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if old.is_public and not new.is_public then
    update public.selection_feedback_access_tokens
    set revoked_at = coalesce(revoked_at, now())
    where selection_id = new.id
      and revoked_at is null;
  end if;
  return new;
end;
$$;

drop trigger if exists revoke_selection_feedback_tokens_on_unpublish
  on public.selections;
create trigger revoke_selection_feedback_tokens_on_unpublish
after update of is_public on public.selections
for each row
execute function public.revoke_selection_feedback_tokens_on_unpublish();

drop policy if exists "Public clients can create feedback"
  on public.selection_client_feedback;
drop policy if exists "Public clients can update feedback"
  on public.selection_client_feedback;

drop function if exists public.save_selection_client_feedback(
  uuid, uuid, text, text, text
);
drop function if exists public.get_selection_client_feedback(uuid, text);

create function public.save_selection_client_feedback(
  p_selection_id uuid,
  p_profile_id uuid,
  p_client_key text,
  p_access_token text,
  p_vote text default null,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_key text := btrim(coalesce(p_client_key, ''));
  v_vote text := nullif(lower(btrim(coalesce(p_vote, ''))), '');
begin
  if length(v_key) < 20 then
    raise exception 'Client key is required';
  end if;

  if not public.selection_feedback_token_is_valid(
    p_selection_id,
    p_access_token
  ) then
    raise exception 'Invalid or expired selection access token';
  end if;

  if v_vote in ('liked', 'like', 'chosen') then
    v_vote := 'selected';
  end if;

  if v_vote is not null
     and v_vote not in ('selected', 'reserve', 'rejected') then
    raise exception 'Unsupported vote';
  end if;

  if not exists (
    select 1
    from public.selection_items si
    where si.selection_id = p_selection_id
      and si.profile_id = p_profile_id
  ) then
    raise exception 'Profile is not in this selection';
  end if;

  insert into public.selection_client_feedback (
    selection_id,
    profile_id,
    client_key,
    vote,
    comment,
    updated_at
  )
  values (
    p_selection_id,
    p_profile_id,
    v_key,
    v_vote,
    left(btrim(coalesce(p_comment, '')), 2000),
    now()
  )
  on conflict (selection_id, profile_id, client_key)
  do update set
    vote = excluded.vote,
    comment = excluded.comment,
    updated_at = now();

  if v_vote = 'selected' then
    update public.selections
    set status = 'selected'
    where id = p_selection_id
      and status in ('sent_to_client', 'client_viewed', 'draft', 'rejected');
  elsif v_vote = 'rejected'
    and not exists (
      select 1
      from public.selection_client_feedback f
      where f.selection_id = p_selection_id
        and f.vote in ('selected', 'reserve')
    )
    and (
      select count(*)
      from public.selection_client_feedback f
      where f.selection_id = p_selection_id
        and f.vote = 'rejected'
    ) >= (
      select count(*)
      from public.selection_items si
      where si.selection_id = p_selection_id
    )
  then
    update public.selections
    set status = 'rejected'
    where id = p_selection_id
      and status in ('sent_to_client', 'client_viewed', 'draft');
  end if;
end;
$$;

revoke all on function public.save_selection_client_feedback(
  uuid, uuid, text, text, text, text
) from public;
grant execute on function public.save_selection_client_feedback(
  uuid, uuid, text, text, text, text
) to anon, authenticated;

create function public.get_selection_client_feedback(
  p_selection_id uuid,
  p_client_key text,
  p_access_token text
)
returns table (
  profile_id uuid,
  client_key text,
  vote text,
  comment text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    f.profile_id,
    f.client_key,
    f.vote,
    f.comment,
    f.updated_at
  from public.selection_client_feedback f
  where f.selection_id = p_selection_id
    and f.client_key = btrim(coalesce(p_client_key, ''))
    and public.selection_feedback_token_is_valid(
      p_selection_id,
      p_access_token
    )
  order by f.updated_at desc;
$$;

revoke all on function public.get_selection_client_feedback(
  uuid, text, text
) from public;
grant execute on function public.get_selection_client_feedback(
  uuid, text, text
) to anon, authenticated;

notify pgrst, 'reload schema';
