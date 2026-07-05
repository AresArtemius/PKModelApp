-- Real push notification queue.
-- Run after planned_improvements.sql, selection_chats.sql, and profile tables.

create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null default 'unknown',
  apns_token text,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  route text not null default '',
  read_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.app_notifications
  add column if not exists type text not null default 'generic',
  add column if not exists data jsonb not null default '{}'::jsonb,
  add column if not exists profile_action_log_id uuid,
  add column if not exists push_status text not null default 'pending',
  add column if not exists push_attempts integer not null default 0,
  add column if not exists push_sent_at timestamptz,
  add column if not exists push_error text,
  add column if not exists email_status text not null default 'none',
  add column if not exists email_attempts integer not null default 0,
  add column if not exists email_sent_at timestamptz,
  add column if not exists email_delivered_at timestamptz,
  add column if not exists email_read_at timestamptz,
  add column if not exists email_error text,
  add column if not exists delivery_status text not null default 'created',
  add column if not exists delivery_updated_at timestamptz,
  add column if not exists deleted_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'app_notifications_push_status_check'
  ) then
    alter table public.app_notifications
      add constraint app_notifications_push_status_check
      check (push_status in ('pending', 'processing', 'sent', 'failed', 'skipped'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'app_notifications_email_status_check'
  ) then
    alter table public.app_notifications
      add constraint app_notifications_email_status_check
      check (email_status in ('none', 'pending', 'processing', 'sent', 'delivered', 'read', 'failed', 'skipped'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'app_notifications_delivery_status_check'
  ) then
    alter table public.app_notifications
      add constraint app_notifications_delivery_status_check
      check (delivery_status in ('created', 'queued', 'processing', 'sent', 'delivered', 'read', 'failed', 'skipped'));
  end if;
end $$;

create index if not exists app_notifications_push_status_created_idx
  on public.app_notifications (push_status, created_at);

create index if not exists app_notifications_type_created_idx
  on public.app_notifications (type, created_at desc);

create index if not exists app_notifications_profile_action_log_idx
  on public.app_notifications (profile_action_log_id)
  where profile_action_log_id is not null;

create index if not exists app_notifications_email_status_created_idx
  on public.app_notifications (email_status, created_at);

create index if not exists push_device_tokens_user_enabled_idx
  on public.push_device_tokens (user_id, enabled);

alter table public.push_device_tokens enable row level security;
alter table public.app_notifications enable row level security;

drop policy if exists "Users can view own push tokens"
  on public.push_device_tokens;

create policy "Users can view own push tokens"
  on public.push_device_tokens
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own push tokens"
  on public.push_device_tokens;

create policy "Users can insert own push tokens"
  on public.push_device_tokens
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own push tokens"
  on public.push_device_tokens;

create policy "Users can update own push tokens"
  on public.push_device_tokens
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own push tokens"
  on public.push_device_tokens;

create policy "Users can delete own push tokens"
  on public.push_device_tokens
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can view own app notifications"
  on public.app_notifications;

create policy "Users can view own app notifications"
  on public.app_notifications
  for select
  to authenticated
  using (auth.uid() = user_id and deleted_at is null);

drop policy if exists "Users can update own app notifications"
  on public.app_notifications;

create policy "Users can update own app notifications"
  on public.app_notifications
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own app notifications"
  on public.app_notifications;

create policy "Users can delete own app notifications"
  on public.app_notifications
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.enqueue_app_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_route text default '',
  p_type text default 'generic',
  p_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_profile_action_log_id uuid;
begin
  if p_user_id is null then
    return null;
  end if;

  begin
    v_profile_action_log_id :=
      nullif(btrim(coalesce(p_data ->> 'profile_action_log_id', '')), '')::uuid;
  exception
    when others then
      v_profile_action_log_id := null;
  end;

  insert into public.app_notifications (
    user_id,
    title,
    body,
    route,
    type,
    data,
    profile_action_log_id
  )
  values (
    p_user_id,
    coalesce(p_title, ''),
    coalesce(p_body, ''),
    coalesce(p_route, ''),
    coalesce(nullif(btrim(p_type), ''), 'generic'),
    coalesce(p_data, '{}'::jsonb),
    v_profile_action_log_id
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.enqueue_app_notification(
  uuid,
  text,
  text,
  text,
  text,
  jsonb
) to authenticated;

create or replace function public.mark_app_notification_push_attempt(
  p_notification_id uuid
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.app_notifications
  set push_status = 'processing',
      push_attempts = push_attempts + 1,
      push_error = null
  where id = p_notification_id;
$$;

grant execute on function public.mark_app_notification_push_attempt(uuid)
  to service_role;

create or replace function public.mark_app_notification_email_status(
  p_notification_id uuid,
  p_status text,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $mark_app_notification_email_status$
declare
  v_status text := lower(btrim(coalesce(p_status, '')));
  v_now timestamptz := now();
begin
  if p_notification_id is null then
    return;
  end if;

  if v_status not in ('none', 'pending', 'processing', 'sent', 'delivered', 'read', 'failed', 'skipped') then
    raise exception 'Unsupported email status: %', p_status;
  end if;

  update public.app_notifications
  set
    email_status = v_status,
    email_attempts = case
      when v_status = 'processing' then email_attempts + 1
      else email_attempts
    end,
    email_sent_at = case
      when v_status in ('sent', 'delivered', 'read') then coalesce(email_sent_at, v_now)
      else email_sent_at
    end,
    email_delivered_at = case
      when v_status in ('delivered', 'read') then coalesce(email_delivered_at, v_now)
      else email_delivered_at
    end,
    email_read_at = case
      when v_status = 'read' then coalesce(email_read_at, v_now)
      else email_read_at
    end,
    email_error = case
      when v_status = 'failed' then coalesce(p_error, '')
      else null
    end,
    delivery_status = case
      when v_status in ('none', 'pending') then 'queued'
      when v_status = 'processing' then 'processing'
      else v_status
    end,
    delivery_updated_at = v_now
  where id = p_notification_id;
end;
$mark_app_notification_email_status$;

grant execute on function public.mark_app_notification_email_status(
  uuid,
  text,
  text
) to service_role;

create or replace function public.sync_profile_action_log_from_app_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $sync_profile_action_log_from_app_notification$
declare
  v_log_id uuid;
begin
  v_log_id := new.profile_action_log_id;

  if v_log_id is null then
    begin
      v_log_id :=
        nullif(btrim(coalesce(new.data ->> 'profile_action_log_id', '')), '')::uuid;
    exception
      when others then
        v_log_id := null;
    end;
  end if;

  update public.app_notifications
  set
    delivery_status = case
      when new.read_at is not null
           or new.email_read_at is not null
           or new.email_status = 'read' then 'read'
      when new.email_delivered_at is not null
           or new.email_status = 'delivered' then 'delivered'
      when new.email_status = 'failed'
           or new.push_status = 'failed' then 'failed'
      when new.email_sent_at is not null
           or new.email_status = 'sent'
           or new.push_sent_at is not null
           or new.push_status = 'sent' then 'sent'
      when new.push_status = 'skipped'
           or new.email_status = 'skipped' then 'skipped'
      else delivery_status
    end,
    delivery_updated_at = case
      when new.read_at is not null
           or new.email_read_at is not null
           or new.email_status in ('read', 'delivered', 'failed', 'sent', 'skipped')
           or new.email_delivered_at is not null
           or new.email_sent_at is not null
           or new.push_status in ('sent', 'failed', 'skipped')
           or new.push_sent_at is not null then now()
      else delivery_updated_at
    end
  where id = new.id;

  if v_log_id is null then
    return new;
  end if;

  update public.profile_action_logs
  set push_notification_id = new.id
  where id = v_log_id
    and push_notification_id is null;

  if new.read_at is not null then
    perform public.set_profile_action_delivery_status(
      v_log_id,
      'app',
      'read',
      null
    );
  elsif new.email_read_at is not null or new.email_status = 'read' then
    perform public.set_profile_action_delivery_status(
      v_log_id,
      'email',
      'read',
      null
    );
  elsif new.email_delivered_at is not null or new.email_status = 'delivered' then
    perform public.set_profile_action_delivery_status(
      v_log_id,
      'email',
      'delivered',
      null
    );
  elsif new.email_status = 'failed' then
    perform public.set_profile_action_delivery_status(
      v_log_id,
      'email',
      'failed',
      new.email_error
    );
  elsif new.push_status = 'failed' then
    perform public.set_profile_action_delivery_status(
      v_log_id,
      'push',
      'failed',
      new.push_error
    );
  elsif new.email_sent_at is not null or new.email_status = 'sent' then
    perform public.set_profile_action_delivery_status(
      v_log_id,
      'email',
      'sent',
      null
    );
  elsif new.push_sent_at is not null or new.push_status in ('sent', 'skipped') then
    perform public.set_profile_action_delivery_status(
      v_log_id,
      'push',
      'sent',
      new.push_error
    );
  end if;

  return new;
end;
$sync_profile_action_log_from_app_notification$;

drop trigger if exists app_notification_profile_action_status_sync
  on public.app_notifications;

create trigger app_notification_profile_action_status_sync
after update of read_at, push_status, push_sent_at, push_error,
  email_status, email_sent_at, email_delivered_at, email_read_at, email_error
on public.app_notifications
for each row
execute function public.sync_profile_action_log_from_app_notification();

create or replace function public.notify_selection_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chat public.selection_chats%rowtype;
  v_recipient uuid;
  v_title text;
begin
  select * into v_chat
  from public.selection_chats
  where id = new.chat_id;

  if v_chat.id is null then
    return new;
  end if;

  if new.sender_id = v_chat.model_user_id then
    v_recipient := v_chat.agent_user_id;
  else
    v_recipient := v_chat.model_user_id;
  end if;

  if v_recipient is null or v_recipient = new.sender_id then
    return new;
  end if;

  select coalesce(title, 'Чат') into v_title
  from public.selections
  where id = v_chat.selection_id;

  perform public.enqueue_app_notification(
    v_recipient,
    coalesce(v_title, 'Чат'),
    left(
      coalesce(
        nullif(btrim(new.body), ''),
        case
          when new.media_type = 'image' then 'Фото'
          when new.media_type = 'video' then 'Видео'
          when new.media_type = 'file' then coalesce(nullif(new.file_name, ''), 'Файл')
          else 'Новое сообщение'
        end
      ),
      180
    ),
    '/chat/' || new.chat_id::text,
    'chat_message',
    jsonb_build_object(
      'chat_id', new.chat_id,
      'selection_id', v_chat.selection_id,
      'profile_id', v_chat.profile_id,
      'media_type', new.media_type,
      'file_name', new.file_name,
      'file_size', new.file_size,
      'file_mime', new.file_mime
    )
  );

  return new;
end;
$$;

drop trigger if exists selection_chat_message_notify
  on public.selection_chat_messages;

create trigger selection_chat_message_notify
after insert on public.selection_chat_messages
for each row
execute function public.notify_selection_chat_message();

create or replace function public.notify_selection_invitation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_selection record;
  v_body text;
begin
  select user_id into v_user_id
  from public.profiles
  where id = new.profile_id;

  if v_user_id is null then
    return new;
  end if;

  select
    id,
    coalesce(title, 'Кастинг') as title,
    coalesce(request_video_intro, false) as request_video_intro,
    coalesce(video_intro_requirements, '') as video_intro_requirements
  into v_selection
  from public.selections
  where id = new.selection_id;

  if v_selection.id is null then
    return new;
  end if;

  v_body := 'Вас рассматривают на кастинг "' || v_selection.title || '".';

  if v_selection.request_video_intro then
    v_body := v_body || ' Требуется видео-визитка.';
  end if;

  perform public.enqueue_app_notification(
    v_user_id,
    v_selection.title,
    v_body,
    '/invitations',
    case
      when v_selection.request_video_intro then 'video_intro_request'
      else 'selection_invitation'
    end,
    jsonb_build_object(
      'selection_id', new.selection_id,
      'profile_id', new.profile_id,
      'request_video_intro', v_selection.request_video_intro,
      'video_intro_requirements', v_selection.video_intro_requirements
    )
  );

  return new;
end;
$$;

drop trigger if exists selection_item_invitation_notify
  on public.selection_items;

create trigger selection_item_invitation_notify
after insert on public.selection_items
for each row
execute function public.notify_selection_invitation();

create or replace function public.notify_profile_moderation_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
begin
  if new.user_id is null
     or coalesce(old.status::text, '') = coalesce(new.status::text, '') then
    return new;
  end if;

  if new.status::text = 'approved' then
    v_title := 'Анкета одобрена';
    v_body := 'Ваша анкета прошла модерацию.';
  elsif new.status::text = 'rejected' then
    v_title := 'Анкета отклонена';
    v_body := coalesce(nullif(btrim(new.moderation_comment), ''), 'Анкета не прошла модерацию.');
  else
    return new;
  end if;

  perform public.enqueue_app_notification(
    new.user_id,
    v_title,
    v_body,
    '/me',
    'profile_moderation',
    jsonb_build_object('profile_id', new.id, 'status', new.status::text)
  );

  return new;
end;
$$;

drop trigger if exists profile_moderation_status_notify
  on public.profiles;

create trigger profile_moderation_status_notify
after update of status on public.profiles
for each row
execute function public.notify_profile_moderation_status();

create or replace function public.notify_casting_agent_application_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
begin
  if coalesce(old.status::text, '') = coalesce(new.status::text, '') then
    return new;
  end if;

  if new.status::text = 'approved' then
    v_title := 'Заявка кастинг-агента одобрена';
    v_body := 'Теперь вы можете создавать подборки для кастингов.';
  elsif new.status::text = 'rejected' then
    v_title := 'Заявка кастинг-агента отклонена';
    v_body := coalesce(nullif(btrim(new.comment), ''), 'Заявка не прошла модерацию.');
  else
    return new;
  end if;

  perform public.enqueue_app_notification(
    new.user_id,
    v_title,
    v_body,
    '/me',
    'casting_agent_moderation',
    jsonb_build_object('application_id', new.id, 'status', new.status::text)
  );

  return new;
end;
$$;

do $$
begin
  if to_regclass('public.casting_agent_applications') is not null then
    execute '
      drop trigger if exists casting_agent_application_status_notify
      on public.casting_agent_applications
    ';

    execute '
      create trigger casting_agent_application_status_notify
      after update of status on public.casting_agent_applications
      for each row
      execute function public.notify_casting_agent_application_status()
    ';
  end if;
end $$;
