-- Step 1. Tables and RLS only.
-- Run this first in Supabase SQL Editor.

alter table public.user_profiles
  add column if not exists account_type text not null default 'user',
  add column if not exists avatar_url text,
  add column if not exists company_name text,
  add column if not exists position text,
  add column if not exists city text,
  add column if not exists country text,
  add column if not exists website text,
  add column if not exists social_url text,
  add column if not exists bio text;

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
  requested_account_type text not null default 'casting_agent',
  comment text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null
);

alter table public.casting_agent_applications
  add column if not exists requested_account_type text not null default 'casting_agent';

alter table public.user_roles enable row level security;
alter table public.casting_agent_applications enable row level security;

create unique index if not exists casting_agent_applications_one_pending_idx
  on public.casting_agent_applications (user_id)
  where status = 'pending';

notify pgrst, 'reload schema';
