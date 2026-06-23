-- Planned performance and admin maintenance helpers for ModelApp.
-- Safe to run multiple times in Supabase SQL Editor.

create or replace function public.catalog_filter_bounds()
returns table (
  age_min int,
  age_max int,
  height_min int,
  height_max int,
  shoe_min int,
  shoe_max int,
  bust_min int,
  bust_max int,
  waist_min int,
  waist_max int,
  hips_min int,
  hips_max int,
  min_hourly_rate_min int,
  min_hourly_rate_max int,
  min_daily_fee_min int,
  min_daily_fee_max int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    min(age)::int,
    max(age)::int,
    min(height)::int,
    max(height)::int,
    min(shoe_size)::int,
    max(shoe_size)::int,
    min(bust)::int,
    max(bust)::int,
    min(waist)::int,
    max(waist)::int,
    min(hips)::int,
    max(hips)::int,
    min(min_hourly_rate)::int,
    max(min_hourly_rate)::int,
    min(min_daily_fee)::int,
    max(min_daily_fee)::int
  from public.profiles
  where status = 'approved';
$$;

grant execute on function public.catalog_filter_bounds() to authenticated, anon;

create index if not exists profiles_status_full_name_id_idx
  on public.profiles (status, full_name, id);

create index if not exists profiles_status_age_idx
  on public.profiles (status, age);

create index if not exists profiles_status_height_idx
  on public.profiles (status, height);

create index if not exists profiles_status_shoe_size_idx
  on public.profiles (status, shoe_size);

create index if not exists profiles_status_rates_idx
  on public.profiles (status, min_hourly_rate, min_daily_fee);

create index if not exists selection_items_selection_id_idx
  on public.selection_items (selection_id);

create index if not exists selection_items_profile_id_idx
  on public.selection_items (profile_id);

create index if not exists casting_responses_casting_id_idx
  on public.casting_responses (casting_id);

create index if not exists casting_responses_profile_id_idx
  on public.casting_responses (profile_id);

alter table public.casting_responses
  add column if not exists status text not null default 'submitted';

update public.casting_responses
set status = 'submitted'
where status is null or btrim(status) = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'casting_responses_status_check'
  ) then
    alter table public.casting_responses
      add constraint casting_responses_status_check
      check (status in ('submitted', 'viewed', 'invited', 'rejected'));
  end if;
end $$;

create index if not exists casting_responses_status_idx
  on public.casting_responses (status);

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

create index if not exists push_device_tokens_user_id_idx
  on public.push_device_tokens (user_id);

create index if not exists push_device_tokens_enabled_idx
  on public.push_device_tokens (enabled);

alter table public.push_device_tokens enable row level security;

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

alter table public.profiles
  add column if not exists is_pro boolean not null default false;

alter table public.profiles
  add column if not exists pro_until timestamptz;

create index if not exists profiles_status_is_pro_full_name_id_idx
  on public.profiles (status, is_pro desc, full_name, id);

create index if not exists profiles_pro_until_idx
  on public.profiles (pro_until)
  where is_pro = true;

alter table public.profiles
  add column if not exists is_verified boolean not null default false;

alter table public.profiles
  add column if not exists verification_status text not null default 'none'
  check (verification_status in ('none', 'pending', 'verified', 'rejected'));

alter table public.profiles
  add column if not exists verification_requested_at timestamptz;

alter table public.profiles
  add column if not exists verified_at timestamptz;

alter table public.profiles
  add column if not exists verified_by uuid references auth.users(id)
  on delete set null;

create index if not exists profiles_status_verified_full_name_id_idx
  on public.profiles (status, is_verified desc, full_name, id);

create index if not exists profiles_verification_status_idx
  on public.profiles (verification_status);

create or replace function public.admin_set_profile_verification(
  p_profile_id uuid,
  p_verified boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can verify profiles';
  end if;

  update public.profiles
  set is_verified = coalesce(p_verified, false),
      verification_status = case
        when coalesce(p_verified, false) then 'verified'
        else 'rejected'
      end,
      verified_at = case
        when coalesce(p_verified, false) then now()
        else null
      end,
      verified_by = case
        when coalesce(p_verified, false) then auth.uid()
        else null
      end
  where id = p_profile_id;

  if not found then
    raise exception 'Profile not found';
  end if;
end;
$$;

grant execute on function public.admin_set_profile_verification(uuid, boolean)
  to authenticated;

alter table public.selections
  add column if not exists is_public boolean not null default false;

alter table public.selections
  add column if not exists request_video_intro boolean not null default false,
  add column if not exists video_intro_requirements text not null default '';

create index if not exists selections_is_public_created_at_idx
  on public.selections (is_public, created_at desc);

drop policy if exists "Public can view published selections"
  on public.selections;

create policy "Public can view published selections"
  on public.selections
  for select
  to anon, authenticated
  using (
    is_public = true
    or exists (
      select 1
      from public.selection_items si
      join public.profiles p on p.id = si.profile_id
      where si.selection_id = selections.id
        and p.user_id = auth.uid()
    )
  );

drop policy if exists "Public can view published selection items"
  on public.selection_items;

create policy "Public can view published selection items"
  on public.selection_items
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = selection_items.profile_id
        and p.user_id = auth.uid()
    )
    or
    exists (
      select 1
      from public.selections s
      where s.id = selection_items.selection_id
        and s.is_public = true
    )
);

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.casting_agent_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  comment text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null
);

create unique index if not exists casting_agent_applications_one_pending_idx
  on public.casting_agent_applications (user_id)
  where status = 'pending';

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id::text = auth.uid()::text
      and lower(role) = 'admin'
  );
$$;

grant execute on function public.current_user_is_admin() to authenticated;

alter table public.user_roles enable row level security;

drop policy if exists "Users can view own role"
  on public.user_roles;

create policy "Users can view own role"
  on public.user_roles
  for select
  to authenticated
  using (
    user_id::text = auth.uid()::text
    or public.current_user_is_admin()
  );

drop policy if exists "Users can create own non-admin role"
  on public.user_roles;

create policy "Users can create own non-admin role"
  on public.user_roles
  for insert
  to authenticated
  with check (
    user_id::text = auth.uid()::text
    and lower(role) = 'user'
  );

drop policy if exists "Users can update own non-admin role"
  on public.user_roles;

create policy "Users can update own non-admin role"
  on public.user_roles
  for update
  to authenticated
  using (user_id::text = auth.uid()::text)
  with check (
    user_id::text = auth.uid()::text
    and lower(role) = 'user'
  );

alter table public.casting_agent_applications enable row level security;

drop policy if exists "Users and admins can view casting agent applications"
  on public.casting_agent_applications;

create policy "Users and admins can view casting agent applications"
  on public.casting_agent_applications
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Users can create own casting agent applications"
  on public.casting_agent_applications;

create policy "Users can create own casting agent applications"
  on public.casting_agent_applications
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and status = 'pending'
  );

create or replace function public.admin_decide_casting_agent_application(
  p_application_id uuid,
  p_approved boolean,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can decide casting agent applications';
  end if;

  select user_id
    into v_user_id
  from public.casting_agent_applications
  where id = p_application_id;

  if v_user_id is null then
    raise exception 'Casting agent application not found';
  end if;

  update public.casting_agent_applications
  set status = case when p_approved then 'approved' else 'rejected' end,
      comment = coalesce(p_comment, ''),
      decided_at = now(),
      decided_by = auth.uid(),
      updated_at = now()
  where id = p_application_id;

  if p_approved then
    insert into public.user_roles (user_id, role, updated_at)
    values (v_user_id, 'casting_agent', now())
    on conflict (user_id)
    do update set role = 'casting_agent', updated_at = now();

    update public.user_profiles
    set account_type = 'casting_agent', updated_at = now()
    where user_id = v_user_id;
  end if;
end;
$$;

grant execute on function public.admin_decide_casting_agent_application(
  uuid,
  boolean,
  text
) to authenticated;

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  phone text,
  full_name text,
  avatar_url text,
  auth_provider text,
  account_type text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

alter table public.user_profiles
  add column if not exists account_type text not null default 'user';

create index if not exists user_profiles_email_idx
  on public.user_profiles (email);

create index if not exists user_profiles_phone_idx
  on public.user_profiles (phone);

alter table public.user_profiles enable row level security;

drop policy if exists "Users and admins can view account profiles"
  on public.user_profiles;

create policy "Users and admins can view account profiles"
  on public.user_profiles
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or public.current_user_is_admin()
  );

drop policy if exists "Users can create own account profile"
  on public.user_profiles;

create policy "Users can create own account profile"
  on public.user_profiles
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own account profile"
  on public.user_profiles;

create policy "Users can update own account profile"
  on public.user_profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.current_user_can_create_selections()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id::text = auth.uid()::text
      and lower(role) in ('admin', 'casting_agent')
  )
  or exists (
    select 1
    from public.user_profiles
    where user_id::text = auth.uid()::text
      and lower(account_type) = 'admin'
  );
$$;

grant execute on function public.current_user_can_create_selections()
  to authenticated;

alter table public.selections
  add column if not exists created_by uuid references auth.users(id) on delete set null;

drop policy if exists "Casting agents and admins can create selections"
  on public.selections;

create policy "Casting agents and admins can create selections"
  on public.selections
  for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.current_user_can_create_selections()
  );

drop policy if exists "Selection owners and admins can view selections"
  on public.selections;

create policy "Selection owners and admins can view selections"
  on public.selections
  for select
  to authenticated
  using (
    created_by = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Selection owners and admins can create selection items"
  on public.selection_items;

create policy "Selection owners and admins can create selection items"
  on public.selection_items
  for insert
  to authenticated
  with check (
    public.current_user_can_create_selections()
    and exists (
      select 1
      from public.selections s
      where s.id = selection_items.selection_id
        and (
          s.created_by = auth.uid()
          or public.current_user_is_admin()
        )
    )
  );

create or replace function public.create_selection_with_items(
  p_title text,
  p_profile_ids uuid[],
  p_request_video_intro boolean default false,
  p_video_intro_requirements text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_selection_id uuid;
begin
  if not public.current_user_can_create_selections() then
    raise exception 'Only casting agents and admins can create selections';
  end if;

  if btrim(coalesce(p_title, '')) = '' then
    raise exception 'Selection title is required';
  end if;

  insert into public.selections (
    title,
    created_by,
    request_video_intro,
    video_intro_requirements
  )
  values (
    btrim(p_title),
    auth.uid(),
    coalesce(p_request_video_intro, false),
    btrim(coalesce(p_video_intro_requirements, ''))
  )
  returning id into v_selection_id;

  insert into public.selection_items (selection_id, profile_id)
  select v_selection_id, distinct_profile_id
  from (
    select distinct unnest(coalesce(p_profile_ids, array[]::uuid[]))
      as distinct_profile_id
  ) ids
  where distinct_profile_id is not null;

  return v_selection_id;
end;
$$;

grant execute on function public.create_selection_with_items(
  text,
  uuid[],
  boolean,
  text
) to authenticated;

create table if not exists public.casting_agent_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.casting_agent_folder_items (
  folder_id uuid not null references public.casting_agent_folders(id)
    on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (folder_id, profile_id)
);

create table if not exists public.casting_agent_model_notes (
  user_id uuid not null references auth.users(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, profile_id)
);

create index if not exists casting_agent_folders_user_title_idx
  on public.casting_agent_folders (user_id, title);

create index if not exists casting_agent_folder_items_profile_idx
  on public.casting_agent_folder_items (profile_id);

alter table public.casting_agent_folders enable row level security;
alter table public.casting_agent_folder_items enable row level security;
alter table public.casting_agent_model_notes enable row level security;

drop policy if exists "Agents manage own folders"
  on public.casting_agent_folders;

create policy "Agents manage own folders"
  on public.casting_agent_folders
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and public.current_user_can_create_selections()
  )
  with check (
    user_id = auth.uid()
    and public.current_user_can_create_selections()
  );

drop policy if exists "Agents manage own folder items"
  on public.casting_agent_folder_items;

create policy "Agents manage own folder items"
  on public.casting_agent_folder_items
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and public.current_user_can_create_selections()
  )
  with check (
    user_id = auth.uid()
    and public.current_user_can_create_selections()
    and exists (
      select 1
      from public.casting_agent_folders f
      where f.id = casting_agent_folder_items.folder_id
        and f.user_id = auth.uid()
    )
  );

drop policy if exists "Agents manage own model notes"
  on public.casting_agent_model_notes;

create policy "Agents manage own model notes"
  on public.casting_agent_model_notes
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and public.current_user_can_create_selections()
  )
  with check (
    user_id = auth.uid()
    and public.current_user_can_create_selections()
  );

create table if not exists public.casting_chats (
  id uuid primary key default gen_random_uuid(),
  casting_id uuid not null references public.castings(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  model_user_id uuid not null references auth.users(id) on delete cascade,
  admin_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (casting_id, profile_id)
);

create table if not exists public.casting_chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.casting_chats(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (length(btrim(body)) > 0 and length(body) <= 2000),
  created_at timestamptz not null default now()
);

create index if not exists casting_chats_model_user_id_idx
  on public.casting_chats (model_user_id);

create index if not exists casting_chats_admin_user_id_idx
  on public.casting_chats (admin_user_id);

create index if not exists casting_chat_messages_chat_created_idx
  on public.casting_chat_messages (chat_id, created_at);

alter table public.casting_chats enable row level security;
alter table public.casting_chat_messages enable row level security;

drop policy if exists "Chat participants can view chats"
  on public.casting_chats;

create policy "Chat participants can view chats"
  on public.casting_chats
  for select
  to authenticated
  using (
    auth.uid() = model_user_id
    or auth.uid() = admin_user_id
    or public.current_user_is_admin()
  );

drop policy if exists "Invited models and admins can create chats"
  on public.casting_chats;

create policy "Invited models and admins can create chats"
  on public.casting_chats
  for insert
  to authenticated
  with check (
    public.current_user_is_admin()
    or (
      auth.uid() = model_user_id
      and exists (
        select 1
        from public.casting_responses cr
        where cr.casting_id = casting_chats.casting_id
          and cr.profile_id = casting_chats.profile_id
          and cr.user_id = auth.uid()
          and cr.status = 'invited'
      )
    )
  );

drop policy if exists "Chat participants can update chats"
  on public.casting_chats;

create policy "Chat participants can update chats"
  on public.casting_chats
  for update
  to authenticated
  using (
    auth.uid() = model_user_id
    or auth.uid() = admin_user_id
    or public.current_user_is_admin()
  )
  with check (
    auth.uid() = model_user_id
    or auth.uid() = admin_user_id
    or public.current_user_is_admin()
  );

drop policy if exists "Chat participants can view messages"
  on public.casting_chat_messages;

create policy "Chat participants can view messages"
  on public.casting_chat_messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.casting_chats cc
      where cc.id = casting_chat_messages.chat_id
        and (
          auth.uid() = cc.model_user_id
          or auth.uid() = cc.admin_user_id
          or public.current_user_is_admin()
        )
    )
  );

drop policy if exists "Chat participants can send messages"
  on public.casting_chat_messages;

create policy "Chat participants can send messages"
  on public.casting_chat_messages
  for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and exists (
      select 1
      from public.casting_chats cc
      where cc.id = casting_chat_messages.chat_id
        and (
          auth.uid() = cc.model_user_id
          or auth.uid() = cc.admin_user_id
          or public.current_user_is_admin()
      )
    )
  );

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'casting_chat_messages'
  ) then
    alter publication supabase_realtime
      add table public.casting_chat_messages;
  end if;
end $$;
