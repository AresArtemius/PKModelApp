-- Folder cover: the profile whose photo represents the folder in lists.
-- Safe to run multiple times.
alter table public.casting_agent_folders
  add column if not exists cover_profile_id uuid
    references public.profiles (id) on delete set null;
