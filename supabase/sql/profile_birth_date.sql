-- Adds birth date for professional profiles.
-- Run this whole file in Supabase SQL Editor.

alter table public.profiles
  add column if not exists birth_date date;
