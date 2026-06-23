-- Run these blocks one by one in Supabase SQL Editor.
-- Do not select partial lines inside a create function ... $$ block.

-- STEP 1. Billing tables and policies.
create table if not exists public.user_billing_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'free'
    check (plan in ('free', 'model_pro', 'casting_agent_pro', 'agency_admin')),
  status text not null default 'inactive'
    check (status in ('inactive', 'trialing', 'active', 'past_due', 'canceled')),
  provider text not null default '',
  provider_customer_id text not null default '',
  provider_subscription_id text not null default '',
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_billing_profiles_plan_status_idx
  on public.user_billing_profiles (plan, status);

create index if not exists user_billing_profiles_provider_subscription_idx
  on public.user_billing_profiles (provider, provider_subscription_id);

alter table public.user_billing_profiles enable row level security;

drop policy if exists "Users can view own billing profile"
  on public.user_billing_profiles;

create policy "Users can view own billing profile"
  on public.user_billing_profiles
  for select
  to authenticated
  using (user_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "Admins can manage billing profiles"
  on public.user_billing_profiles;

create policy "Admins can manage billing profiles"
  on public.user_billing_profiles
  for all
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

create table if not exists public.billing_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (provider, provider_event_id)
);

alter table public.billing_events enable row level security;

drop policy if exists "Admins can view billing events"
  on public.billing_events;

create policy "Admins can view billing events"
  on public.billing_events
  for select
  to authenticated
  using (public.current_user_is_admin());

-- STEP 2. Current billing plan function.
create or replace function public.current_user_billing_plan()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select plan
    from public.user_billing_profiles
    where user_id = auth.uid()
      and status in ('trialing', 'active')
      and (
        current_period_end is null
        or current_period_end > now()
      )
    limit 1
  ), 'free');
$$;

grant execute on function public.current_user_billing_plan()
  to authenticated;

-- STEP 3. Selection limits function.
create or replace function public.current_user_selection_limits()
returns table (
  max_profiles_per_selection int,
  max_selections int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_plan text;
begin
  if public.current_user_is_admin() then
    return query select null::int, null::int;
    return;
  end if;

  v_plan := public.current_user_billing_plan();

  if v_plan in ('casting_agent_pro', 'agency_admin') then
    return query select null::int, null::int;
    return;
  end if;

  return query select 10::int, 3::int;
end;
$$;

grant execute on function public.current_user_selection_limits()
  to authenticated;

-- STEP 4. Agent workspace entitlement function.
create or replace function public.current_user_can_use_agent_workspace()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_is_admin()
    or public.current_user_billing_plan() in ('casting_agent_pro', 'agency_admin');
$$;

grant execute on function public.current_user_can_use_agent_workspace()
  to authenticated;

-- STEP 5. Selection creation with limits.
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
  v_profile_count int;
  v_existing_count int;
  v_max_profiles int;
  v_max_selections int;
begin
  if not public.current_user_can_create_selections() then
    raise exception 'Only casting agents and admins can create selections';
  end if;

  if btrim(coalesce(p_title, '')) = '' then
    raise exception 'Selection title is required';
  end if;

  select count(*)
  into v_profile_count
  from (
    select distinct unnest(coalesce(p_profile_ids, array[]::uuid[]))
      as distinct_profile_id
  ) ids
  where distinct_profile_id is not null;

  select max_profiles_per_selection, max_selections
  into v_max_profiles, v_max_selections
  from public.current_user_selection_limits()
  limit 1;

  if v_max_profiles is not null and v_profile_count > v_max_profiles then
    raise exception 'Free plan allows up to % models in one selection',
      v_max_profiles;
  end if;

  if v_max_selections is not null then
    select count(*)
    into v_existing_count
    from public.selections
    where created_by = auth.uid();

    if v_existing_count >= v_max_selections then
      raise exception 'Free plan allows up to % selections', v_max_selections;
    end if;
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

-- STEP 6. Pro-only agent workspace policies.
do $$
begin
  if to_regclass('public.casting_agent_folders') is not null then
    drop policy if exists "Agents manage own folders"
      on public.casting_agent_folders;

    create policy "Agents manage own folders"
      on public.casting_agent_folders
      for all
      to authenticated
      using (
        user_id = auth.uid()
        and public.current_user_can_create_selections()
        and public.current_user_can_use_agent_workspace()
      )
      with check (
        user_id = auth.uid()
        and public.current_user_can_create_selections()
        and public.current_user_can_use_agent_workspace()
      );
  end if;

  if to_regclass('public.casting_agent_folder_items') is not null then
    drop policy if exists "Agents manage own folder items"
      on public.casting_agent_folder_items;

    create policy "Agents manage own folder items"
      on public.casting_agent_folder_items
      for all
      to authenticated
      using (
        user_id = auth.uid()
        and public.current_user_can_create_selections()
        and public.current_user_can_use_agent_workspace()
      )
      with check (
        user_id = auth.uid()
        and public.current_user_can_create_selections()
        and public.current_user_can_use_agent_workspace()
        and exists (
          select 1
          from public.casting_agent_folders f
          where f.id = casting_agent_folder_items.folder_id
            and f.user_id = auth.uid()
        )
      );
  end if;

  if to_regclass('public.casting_agent_model_notes') is not null then
    drop policy if exists "Agents manage own model notes"
      on public.casting_agent_model_notes;

    create policy "Agents manage own model notes"
      on public.casting_agent_model_notes
      for all
      to authenticated
      using (
        user_id = auth.uid()
        and public.current_user_can_create_selections()
        and public.current_user_can_use_agent_workspace()
      )
      with check (
        user_id = auth.uid()
        and public.current_user_can_create_selections()
        and public.current_user_can_use_agent_workspace()
      );
  end if;
end;
$$;

-- STEP 7. Reload PostgREST schema cache.
notify pgrst, 'reload schema';
