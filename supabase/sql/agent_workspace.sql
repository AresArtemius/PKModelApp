-- Casting-agent folders and private notes.
-- Run after roles_and_agent_approval.sql and after profiles exist.

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
