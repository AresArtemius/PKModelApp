-- Step 1: safe indexes only.
-- Run this file first in Supabase SQL Editor.
-- It checks tables/columns before creating optional indexes.

create extension if not exists pg_trgm;

do $$
begin
  if to_regclass('public.profiles') is not null then
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'user_id'
    ) then
      execute 'create index if not exists profiles_user_id_id_idx on public.profiles (user_id, id)';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'status'
    ) and exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'profile_type'
    ) then
      execute 'create index if not exists profiles_status_profile_type_id_idx on public.profiles (status, profile_type, id)';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'status'
    ) and exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'full_name'
    ) then
      execute 'create index if not exists profiles_status_full_name_trgm_idx on public.profiles using gin (full_name gin_trgm_ops) where status = ''approved''';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'status'
    ) and exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'city'
    ) then
      execute 'create index if not exists profiles_status_city_trgm_idx on public.profiles using gin (city gin_trgm_ops) where status = ''approved''';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'status'
    ) and exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'country'
    ) then
      execute 'create index if not exists profiles_status_country_trgm_idx on public.profiles using gin (country gin_trgm_ops) where status = ''approved''';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'status'
    ) and exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'eye_color'
    ) then
      execute 'create index if not exists profiles_status_eye_color_trgm_idx on public.profiles using gin (eye_color gin_trgm_ops) where status = ''approved''';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'status'
    ) and exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'hair_color'
    ) then
      execute 'create index if not exists profiles_status_hair_color_trgm_idx on public.profiles using gin (hair_color gin_trgm_ops) where status = ''approved''';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name in ('status', 'age', 'height')
      group by table_name
      having count(*) = 3
    ) then
      execute 'create index if not exists profiles_status_age_height_idx on public.profiles (status, age, height)';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name in ('status', 'shoe_size', 'bust', 'waist', 'hips')
      group by table_name
      having count(*) = 5
    ) then
      execute 'create index if not exists profiles_status_body_sizes_idx on public.profiles (status, shoe_size, bust, waist, hips)';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name in ('status', 'min_hourly_rate', 'min_daily_fee')
      group by table_name
      having count(*) = 3
    ) then
      execute 'create index if not exists profiles_status_rates_idx on public.profiles (status, min_hourly_rate, min_daily_fee)';
    end if;
  end if;

  if to_regclass('public.profile_analytics_events') is not null then
    execute 'create index if not exists profile_analytics_profile_event_created_idx on public.profile_analytics_events (profile_id, event_type, created_at desc)';
  end if;

  if to_regclass('public.selection_items') is not null then
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'selection_items'
        and column_name = 'model_hidden_at'
    ) then
      execute 'create index if not exists selection_items_profile_created_visible_idx on public.selection_items (profile_id, created_at desc) where model_hidden_at is null';
    else
      execute 'create index if not exists selection_items_profile_created_idx on public.selection_items (profile_id, created_at desc)';
    end if;
  end if;

  if to_regclass('public.selection_chats') is not null then
    execute 'create index if not exists selection_chats_profile_created_idx on public.selection_chats (profile_id, created_at desc)';
  end if;

  if to_regclass('public.selection_chat_messages') is not null then
    execute 'create index if not exists selection_chat_messages_chat_created_desc_idx on public.selection_chat_messages (chat_id, created_at desc)';
  end if;

  if to_regclass('public.selection_chat_message_reactions') is not null then
    execute 'create index if not exists selection_chat_reactions_chat_updated_idx on public.selection_chat_message_reactions (chat_id, updated_at desc)';
  end if;

  if to_regclass('public.app_notifications') is not null then
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'app_notifications'
        and column_name = 'deleted_at'
    ) then
      execute 'create index if not exists app_notifications_user_visible_created_idx on public.app_notifications (user_id, created_at desc) where deleted_at is null';
    else
      execute 'create index if not exists app_notifications_user_created_idx on public.app_notifications (user_id, created_at desc)';
    end if;
  end if;

  if to_regclass('public.castings') is not null then
    execute 'create index if not exists castings_created_at_idx on public.castings (created_at desc)';
  end if;

  if to_regclass('public.casting_responses') is not null then
    execute 'create index if not exists casting_responses_user_created_idx on public.casting_responses (user_id, created_at desc)';
  end if;

  if to_regclass('public.casting_agent_applications') is not null then
    execute 'create index if not exists casting_agent_applications_status_created_idx on public.casting_agent_applications (status, created_at desc)';
  end if;
end;
$$;
