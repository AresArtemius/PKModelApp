-- Smoke 12.10, batch 4: two server-side fixes.
--
-- 1. Reposts failed with «new row violates row-level security policy»:
--    inside the policy subquery `repost_of` resolved to src.repost_of
--    (src.id = src.repost_of is never true). Qualified as posts.repost_of.
-- 2. Phone + password sign-in: GoTrue stores phones as digits only
--    («79255078693»), our merge SQL wrote them with «+». Normalise the data
--    and the function that writes them.

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own"
  on public.posts for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and (
      profile_id is null
      or exists (
        select 1 from public.profiles pr
        where pr.id = profile_id and pr.user_id = auth.uid()
      )
      or public.current_user_is_admin()
      or (
        kind = 'repost'
        and exists (
          select 1 from public.profiles pr
          where pr.id = profile_id and pr.status = 'approved'
        )
      )
    )
    -- a repost of a post must point at a post the author can see
    and (
      repost_of is null
      or exists (
        select 1 from public.posts src
        where src.id = posts.repost_of
          and src.deleted_at is null
          and public.feed_post_visible(src)
      )
    )
  );

-- Existing accounts: strip «+» and spaces from stored phones.
update auth.users
set phone = regexp_replace(phone, '[^0-9]', '', 'g')
where phone is not null and phone ~ '[^0-9]';

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
  set phone = regexp_replace(v_phone, '[^0-9]', '', 'g'),
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


