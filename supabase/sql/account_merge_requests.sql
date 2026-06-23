-- Account merge requests.
-- Use this when a user tries to link a phone/email that already belongs to
-- another auth account. The actual merge must be handled later by an admin
-- service-role function after verification.

create table if not exists public.account_merge_requests (
  id uuid primary key default gen_random_uuid(),
  requester_user_id uuid not null references auth.users(id) on delete cascade,
  requested_phone text not null,
  requester_email text,
  requester_phone text,
  requester_full_name text,
  requester_company_name text,
  requester_note text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  admin_note text not null default '',
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.account_merge_requests
  add column if not exists requester_user_id uuid references auth.users(id) on delete cascade,
  add column if not exists requested_phone text,
  add column if not exists requester_email text,
  add column if not exists requester_phone text,
  add column if not exists requester_full_name text,
  add column if not exists requester_company_name text,
  add column if not exists requester_note text not null default '',
  add column if not exists status text not null default 'pending',
  add column if not exists admin_note text not null default '',
  add column if not exists decided_at timestamptz,
  add column if not exists decided_by uuid references auth.users(id) on delete set null,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.account_merge_requests enable row level security;

drop index if exists account_merge_requests_one_pending_phone_idx;
create unique index if not exists account_merge_requests_one_pending_phone_idx
  on public.account_merge_requests (requester_user_id, requested_phone)
  where status = 'pending';

drop policy if exists "Users and admins can view account merge requests"
  on public.account_merge_requests;
create policy "Users and admins can view account merge requests"
  on public.account_merge_requests
  for select
  using (
    requester_user_id = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Users can create own account merge requests"
  on public.account_merge_requests;
create policy "Users can create own account merge requests"
  on public.account_merge_requests
  for insert
  with check (requester_user_id = auth.uid());

drop policy if exists "Admins can update account merge requests"
  on public.account_merge_requests;
create policy "Admins can update account merge requests"
  on public.account_merge_requests
  for update
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

create or replace function public.request_account_merge(p_request jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $request_account_merge$
declare
  v_user_id uuid := auth.uid();
  v_request_id uuid;
  v_requested_phone text := nullif(btrim(coalesce(p_request ->> 'requested_phone', '')), '');
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_requested_phone is null then
    raise exception 'Requested phone is required';
  end if;

  insert into public.account_merge_requests (
    requester_user_id,
    requested_phone,
    requester_email,
    requester_phone,
    requester_full_name,
    requester_company_name,
    requester_note,
    status,
    updated_at
  )
  values (
    v_user_id,
    v_requested_phone,
    nullif(btrim(coalesce(p_request ->> 'requester_email', '')), ''),
    nullif(btrim(coalesce(p_request ->> 'requester_phone', '')), ''),
    nullif(btrim(coalesce(p_request ->> 'requester_full_name', '')), ''),
    nullif(btrim(coalesce(p_request ->> 'requester_company_name', '')), ''),
    coalesce(p_request ->> 'requester_note', ''),
    'pending',
    now()
  )
  returning id into v_request_id;

  return v_request_id;
end;
$request_account_merge$;

grant execute on function public.request_account_merge(jsonb)
  to authenticated;

create or replace function public.admin_decide_account_merge_request(
  p_request_id uuid,
  p_approved boolean,
  p_admin_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $admin_decide_account_merge_request$
declare
  v_request public.account_merge_requests%rowtype;
  v_requested_phone text;
  v_requested_phone_digits text;
  v_source_user_id uuid;
  v_target_phone text;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can decide account merge requests';
  end if;

  select *
  into v_request
  from public.account_merge_requests
  where id = p_request_id;

  if v_request.id is null then
    raise exception 'Account merge request not found';
  end if;

  v_requested_phone := nullif(btrim(coalesce(v_request.requested_phone, '')), '');
  v_requested_phone_digits := regexp_replace(coalesce(v_requested_phone, ''), '[^0-9]', '', 'g');

  if p_approved and v_requested_phone is null then
    raise exception 'Requested phone is empty';
  end if;

  update public.account_merge_requests
  set status = case when p_approved then 'approved' else 'rejected' end,
      admin_note = coalesce(p_admin_note, ''),
      decided_at = now(),
      decided_by = auth.uid(),
      updated_at = now()
  where id = p_request_id;

  if p_approved then
    select id
    into v_source_user_id
    from auth.users u
    where u.id <> v_request.requester_user_id
      and (
        regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g') = v_requested_phone_digits
        or exists (
          select 1
          from public.user_profiles up
          where up.user_id = u.id
            and regexp_replace(coalesce(up.phone, ''), '[^0-9]', '', 'g') = v_requested_phone_digits
        )
      )
    limit 1;

    select phone
    into v_target_phone
    from auth.users
    where id = v_request.requester_user_id;

    if nullif(btrim(coalesce(v_target_phone, '')), '') is not null
       and regexp_replace(coalesce(v_target_phone, ''), '[^0-9]', '', 'g') <> v_requested_phone_digits then
      raise exception 'Target account already has another phone';
    end if;

    if v_source_user_id is not null then
      update auth.users
      set phone = null,
          phone_confirmed_at = null,
          updated_at = now()
      where id = v_source_user_id;
    end if;

    update auth.users
    set phone = v_requested_phone,
        phone_confirmed_at = coalesce(phone_confirmed_at, now()),
        updated_at = now()
    where id = v_request.requester_user_id;

    if to_regclass('auth.identities') is not null then
      insert into auth.identities (
        user_id,
        provider_id,
        provider,
        identity_data,
        last_sign_in_at,
        created_at,
        updated_at
      )
      values (
        v_request.requester_user_id,
        v_requested_phone,
        'phone',
        jsonb_build_object(
          'sub', v_requested_phone,
          'phone', v_requested_phone,
          'phone_verified', true
        ),
        now(),
        now(),
        now()
      )
      on conflict (provider_id, provider)
      do update set
        user_id = excluded.user_id,
        identity_data = excluded.identity_data,
        updated_at = now();
    end if;

    insert into public.user_profiles (
      user_id,
      email,
      phone,
      full_name,
      company_name,
      updated_at,
      last_seen_at
    )
    values (
      v_request.requester_user_id,
      nullif(btrim(coalesce(v_request.requester_email, '')), ''),
      v_requested_phone,
      nullif(btrim(coalesce(v_request.requester_full_name, '')), ''),
      nullif(btrim(coalesce(v_request.requester_company_name, '')), ''),
      now(),
      now()
    )
    on conflict (user_id)
    do update set
      phone = excluded.phone,
      email = coalesce(public.user_profiles.email, excluded.email),
      full_name = coalesce(public.user_profiles.full_name, excluded.full_name),
      company_name = coalesce(public.user_profiles.company_name, excluded.company_name),
      updated_at = now(),
      last_seen_at = now();

    if v_source_user_id is not null then
      if to_regclass('public.profiles') is not null then
        execute 'update public.profiles set user_id = $1 where user_id = $2'
          using v_request.requester_user_id, v_source_user_id;
      end if;

      if to_regclass('public.selection_chats') is not null then
        execute 'update public.selection_chats set model_user_id = $1 where model_user_id = $2'
          using v_request.requester_user_id, v_source_user_id;
        execute 'update public.selection_chats set agent_user_id = $1 where agent_user_id = $2'
          using v_request.requester_user_id, v_source_user_id;
      end if;

      if to_regclass('public.selection_chat_messages') is not null then
        execute 'update public.selection_chat_messages set sender_id = $1 where sender_id = $2'
          using v_request.requester_user_id, v_source_user_id;
      end if;

      if to_regclass('public.app_notifications') is not null then
        execute 'update public.app_notifications set user_id = $1 where user_id = $2'
          using v_request.requester_user_id, v_source_user_id;
      end if;

      if to_regclass('public.push_device_tokens') is not null then
        execute 'delete from public.push_device_tokens where user_id = $1'
          using v_source_user_id;
      end if;

      if to_regclass('public.user_profiles') is not null then
        execute 'delete from public.user_profiles where user_id = $1'
          using v_source_user_id;
      end if;

      if to_regclass('public.user_roles') is not null then
        execute 'delete from public.user_roles where user_id = $1'
          using v_source_user_id;
      end if;

      if to_regclass('auth.identities') is not null then
        delete from auth.identities
        where user_id = v_source_user_id;
      end if;

      delete from auth.users
      where id = v_source_user_id;
    end if;
  end if;
end;
$admin_decide_account_merge_request$;

grant execute on function public.admin_decide_account_merge_request(
  uuid,
  boolean,
  text
) to authenticated;

create or replace function public.admin_merge_phone_into_email_account(
  p_target_email text,
  p_phone text
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $admin_merge_phone_into_email_account$
declare
  v_target_user_id uuid;
  v_source_user_id uuid;
  v_target_phone text;
  v_phone text := nullif(btrim(coalesce(p_phone, '')), '');
  v_phone_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
begin
  if auth.uid() is not null and not public.current_user_is_admin() then
    raise exception 'Only admins can merge accounts';
  end if;

  if nullif(btrim(coalesce(p_target_email, '')), '') is null then
    raise exception 'Target email is required';
  end if;

  if v_phone is null or v_phone_digits = '' then
    raise exception 'Phone is required';
  end if;

  select id, phone
  into v_target_user_id, v_target_phone
  from auth.users
  where lower(email) = lower(btrim(p_target_email))
  limit 1;

  if v_target_user_id is null then
    raise exception 'Target account not found';
  end if;

  if nullif(btrim(coalesce(v_target_phone, '')), '') is not null
     and regexp_replace(coalesce(v_target_phone, ''), '[^0-9]', '', 'g') <> v_phone_digits then
    raise exception 'Target account already has another phone';
  end if;

  select id
  into v_source_user_id
  from auth.users u
  where u.id <> v_target_user_id
    and (
      regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g') = v_phone_digits
      or exists (
        select 1
        from public.user_profiles up
        where up.user_id = u.id
          and regexp_replace(coalesce(up.phone, ''), '[^0-9]', '', 'g') = v_phone_digits
      )
    )
  limit 1;

  if v_source_user_id is not null then
    update auth.users
    set phone = null,
        phone_confirmed_at = null,
        updated_at = now()
    where id = v_source_user_id;
  end if;

  update auth.users
  set phone = v_phone,
      phone_confirmed_at = coalesce(phone_confirmed_at, now()),
      updated_at = now()
  where id = v_target_user_id;

  if to_regclass('auth.identities') is not null then
    insert into auth.identities (
      user_id,
      provider_id,
      provider,
      identity_data,
      last_sign_in_at,
      created_at,
      updated_at
    )
    values (
      v_target_user_id,
      v_phone,
      'phone',
      jsonb_build_object(
        'sub', v_phone,
        'phone', v_phone,
        'phone_verified', true
      ),
      now(),
      now(),
      now()
    )
    on conflict (provider_id, provider)
    do update set
      user_id = excluded.user_id,
      identity_data = excluded.identity_data,
      updated_at = now();
  end if;

  if to_regclass('public.user_profiles') is not null then
    insert into public.user_profiles (
      user_id,
      email,
      phone,
      updated_at,
      last_seen_at
    )
    values (
      v_target_user_id,
      lower(btrim(p_target_email)),
      v_phone,
      now(),
      now()
    )
    on conflict (user_id)
    do update set
      phone = excluded.phone,
      email = coalesce(public.user_profiles.email, excluded.email),
      updated_at = now(),
      last_seen_at = now();
  end if;

  if v_source_user_id is not null then
    if to_regclass('public.profiles') is not null then
      execute 'update public.profiles set user_id = $1 where user_id = $2'
        using v_target_user_id, v_source_user_id;
    end if;

    if to_regclass('public.selection_chats') is not null then
      execute 'update public.selection_chats set model_user_id = $1 where model_user_id = $2'
        using v_target_user_id, v_source_user_id;
      execute 'update public.selection_chats set agent_user_id = $1 where agent_user_id = $2'
        using v_target_user_id, v_source_user_id;
    end if;

    if to_regclass('public.selection_chat_messages') is not null then
      execute 'update public.selection_chat_messages set sender_id = $1 where sender_id = $2'
        using v_target_user_id, v_source_user_id;
    end if;

    if to_regclass('public.app_notifications') is not null then
      execute 'update public.app_notifications set user_id = $1 where user_id = $2'
        using v_target_user_id, v_source_user_id;
    end if;

    if to_regclass('public.push_device_tokens') is not null then
      execute 'delete from public.push_device_tokens where user_id = $1'
        using v_source_user_id;
    end if;

    if to_regclass('public.user_profiles') is not null then
      execute 'delete from public.user_profiles where user_id = $1'
        using v_source_user_id;
    end if;

    if to_regclass('public.user_roles') is not null then
      execute 'delete from public.user_roles where user_id = $1'
        using v_source_user_id;
    end if;

    if to_regclass('auth.identities') is not null then
      delete from auth.identities
      where user_id = v_source_user_id;
    end if;

    delete from auth.users
    where id = v_source_user_id;
  end if;
end;
$admin_merge_phone_into_email_account$;

grant execute on function public.admin_merge_phone_into_email_account(text, text)
  to authenticated;

create or replace function public.resolve_auth_email_by_phone(p_phone text)
returns text
language plpgsql
security definer
set search_path = public
set row_security = off
as $resolve_auth_email_by_phone$
declare
  v_phone_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_email text;
begin
  if v_phone_digits = '' then
    return null;
  end if;

  select lower(u.email)
  into v_email
  from auth.users u
  where u.phone_confirmed_at is not null
    and nullif(btrim(coalesce(u.email, '')), '') is not null
    and regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g') = v_phone_digits
  limit 1;

  return v_email;
end;
$resolve_auth_email_by_phone$;

grant execute on function public.resolve_auth_email_by_phone(text)
  to anon, authenticated;

notify pgrst, 'reload schema';
