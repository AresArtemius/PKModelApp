-- Account-scoped saved catalog searches.
-- Run once in production before relying on cross-device saved search sync.

create table if not exists public.catalog_saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) > 0),
  filters jsonb not null default '{}'::jsonb,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.catalog_saved_searches
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists title text not null default '',
  add column if not exists filters jsonb not null default '{}'::jsonb,
  add column if not exists position integer not null default 0,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.catalog_saved_searches
  alter column user_id set default auth.uid();

create index if not exists catalog_saved_searches_user_position_idx
  on public.catalog_saved_searches (user_id, position, created_at desc);

create or replace function public.touch_catalog_saved_searches_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists catalog_saved_searches_touch_updated_at
  on public.catalog_saved_searches;

create trigger catalog_saved_searches_touch_updated_at
before update on public.catalog_saved_searches
for each row
execute function public.touch_catalog_saved_searches_updated_at();

alter table public.catalog_saved_searches enable row level security;

drop policy if exists "catalog saved searches select own"
  on public.catalog_saved_searches;
drop policy if exists "catalog saved searches insert own"
  on public.catalog_saved_searches;
drop policy if exists "catalog saved searches update own"
  on public.catalog_saved_searches;
drop policy if exists "catalog saved searches delete own"
  on public.catalog_saved_searches;

create policy "catalog saved searches select own"
  on public.catalog_saved_searches
  for select
  using (user_id = auth.uid());

create policy "catalog saved searches insert own"
  on public.catalog_saved_searches
  for insert
  with check (user_id = auth.uid());

create policy "catalog saved searches update own"
  on public.catalog_saved_searches
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "catalog saved searches delete own"
  on public.catalog_saved_searches
  for delete
  using (user_id = auth.uid());
