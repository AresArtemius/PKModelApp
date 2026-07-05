-- Profile action audit log.
-- Stores a durable event timeline for profile quick actions: invitations,
-- selections/folders, chat messages and future delivery/read states.

create table if not exists public.profile_action_logs (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  target_user_id uuid references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_name text not null default '',
  actor_company text not null default '',
  actor_avatar_url text not null default '',
  action_type text not null check (
    action_type in ('invite', 'selection', 'folder', 'message')
  ),
  title text not null default '',
  description text not null default '',
  template_key text not null default '',
  template_body text not null default '',
  status text not null default 'created' check (
    status in ('created', 'sent', 'delivered', 'read', 'failed', 'archived')
  ),
  related_table text not null default '',
  related_id uuid,
  related_text text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  push_notification_id uuid,
  delivery_channel text not null default 'in_app',
  delivery_error text not null default '',
  status_updated_at timestamptz not null default now(),
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.profile_action_logs
  add column if not exists target_user_id uuid references auth.users(id) on delete cascade,
  add column if not exists actor_user_id uuid references auth.users(id) on delete set null,
  add column if not exists actor_name text not null default '',
  add column if not exists actor_company text not null default '',
  add column if not exists actor_avatar_url text not null default '',
  add column if not exists description text not null default '',
  add column if not exists template_key text not null default '',
  add column if not exists template_body text not null default '',
  add column if not exists status text not null default 'created',
  add column if not exists related_table text not null default '',
  add column if not exists related_id uuid,
  add column if not exists related_text text not null default '',
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists push_notification_id uuid,
  add column if not exists delivery_channel text not null default 'in_app',
  add column if not exists delivery_error text not null default '',
  add column if not exists status_updated_at timestamptz not null default now(),
  add column if not exists delivered_at timestamptz,
  add column if not exists read_at timestamptz;

create index if not exists profile_action_logs_profile_created_idx
  on public.profile_action_logs (profile_id, created_at desc);

create index if not exists profile_action_logs_actor_created_idx
  on public.profile_action_logs (actor_user_id, created_at desc);

create index if not exists profile_action_logs_target_created_idx
  on public.profile_action_logs (target_user_id, created_at desc);

create index if not exists profile_action_logs_related_idx
  on public.profile_action_logs (related_table, related_id);

create index if not exists profile_action_logs_delivery_status_idx
  on public.profile_action_logs (status, delivery_channel, status_updated_at desc);

create index if not exists profile_action_logs_push_notification_idx
  on public.profile_action_logs (push_notification_id)
  where push_notification_id is not null;

create or replace function public.set_profile_action_delivery_status(
  p_action_log_id uuid,
  p_channel text,
  p_status text,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $set_profile_action_delivery_status$
declare
  v_channel text := coalesce(nullif(btrim(p_channel), ''), 'server');
  v_status text := lower(btrim(coalesce(p_status, '')));
  v_now timestamptz := now();
begin
  if p_action_log_id is null then
    return;
  end if;

  if v_status not in ('created', 'sent', 'delivered', 'read', 'failed', 'archived') then
    return;
  end if;

  update public.profile_action_logs
  set
    status = case
      when status = 'archived' then status
      when status = 'read' and v_status <> 'archived' then status
      when v_status = 'delivered' and status = 'failed' then 'delivered'
      when v_status = 'sent' and status in ('created', 'failed') then 'sent'
      else v_status
    end,
    delivery_channel = v_channel,
    delivery_error = case
      when v_status = 'failed' then coalesce(p_error, '')
      else ''
    end,
    delivered_at = case
      when v_status in ('delivered', 'read') then coalesce(delivered_at, v_now)
      else delivered_at
    end,
    read_at = case
      when v_status = 'read' then coalesce(read_at, v_now)
      else read_at
    end,
    status_updated_at = v_now,
    metadata = jsonb_set(
      jsonb_set(
        jsonb_set(
          coalesce(metadata, '{}'::jsonb),
          '{delivery_channel}',
          to_jsonb(v_channel),
          true
        ),
        '{delivery_status}',
        to_jsonb(v_status),
        true
      ),
      '{delivery_error}',
      to_jsonb(coalesce(p_error, '')),
      true
    )
  where id = p_action_log_id;
end;
$set_profile_action_delivery_status$;

grant execute on function public.set_profile_action_delivery_status(
  uuid,
  text,
  text,
  text
) to service_role;

alter table public.profile_action_logs enable row level security;

drop policy if exists "Profile action participants can view" on public.profile_action_logs;
create policy "Profile action participants can view"
  on public.profile_action_logs
  for select
  to authenticated
  using (
    actor_user_id = auth.uid()
    or target_user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = profile_action_logs.profile_id
        and p.user_id = auth.uid()
    )
    or public.current_user_is_admin()
  );

drop policy if exists "Users can insert own profile action logs" on public.profile_action_logs;
create policy "Users can insert own profile action logs"
  on public.profile_action_logs
  for insert
  to authenticated
  with check (
    actor_user_id = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Participants can update profile action read state" on public.profile_action_logs;
create policy "Participants can update profile action read state"
  on public.profile_action_logs
  for update
  to authenticated
  using (
    actor_user_id = auth.uid()
    or target_user_id = auth.uid()
    or public.current_user_is_admin()
  )
  with check (
    actor_user_id = auth.uid()
    or target_user_id = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Admins can delete profile action logs" on public.profile_action_logs;
create policy "Admins can delete profile action logs"
  on public.profile_action_logs
  for delete
  to authenticated
  using (public.current_user_is_admin());
