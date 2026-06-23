-- Step 1 basic indexes: no DO blocks, no dollar-quoted strings.
-- Run this if Supabase SQL Editor breaks long DO/function blocks.

create extension if not exists pg_trgm;

create index if not exists profiles_user_id_id_idx
  on public.profiles (user_id, id);

create index if not exists profiles_status_full_name_id_idx
  on public.profiles (status, full_name, id);

create index if not exists profiles_status_full_name_trgm_idx
  on public.profiles using gin (full_name gin_trgm_ops);

create index if not exists profiles_status_city_trgm_idx
  on public.profiles using gin (city gin_trgm_ops);

create index if not exists profiles_status_country_trgm_idx
  on public.profiles using gin (country gin_trgm_ops);

create index if not exists profiles_status_age_idx
  on public.profiles (status, age);

create index if not exists profiles_status_height_idx
  on public.profiles (status, height);

create index if not exists profiles_status_shoe_size_idx
  on public.profiles (status, shoe_size);

create index if not exists selection_items_profile_id_idx
  on public.selection_items (profile_id);

create index if not exists selection_items_selection_id_idx
  on public.selection_items (selection_id);

create index if not exists selection_chats_profile_created_idx
  on public.selection_chats (profile_id, created_at desc);

create index if not exists selection_chat_messages_chat_created_desc_idx
  on public.selection_chat_messages (chat_id, created_at desc);

create index if not exists selection_chat_reactions_chat_updated_idx
  on public.selection_chat_message_reactions (chat_id, updated_at desc);

create index if not exists app_notifications_user_created_idx
  on public.app_notifications (user_id, created_at desc);

create index if not exists castings_created_at_idx
  on public.castings (created_at desc);

create index if not exists casting_responses_user_created_idx
  on public.casting_responses (user_id, created_at desc);

create index if not exists casting_agent_applications_status_created_idx
  on public.casting_agent_applications (status, created_at desc);
