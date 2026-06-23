-- Professional profile types and role-specific portfolio fields.
-- Run this before expecting non-model profile fields to persist.

alter table public.profiles
  add column if not exists profile_type text not null default 'model',
  add column if not exists experience text not null default '',
  add column if not exists skills text not null default '',
  add column if not exists services text not null default '',
  add column if not exists genres text not null default '',
  add column if not exists equipment text not null default '';

update public.profiles
set profile_type = 'model'
where profile_type is null or btrim(profile_type) = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_profile_type_check'
  ) then
    alter table public.profiles
      add constraint profiles_profile_type_check
      check (
        profile_type in (
          'model',
          'actor',
          'photographer',
          'videographer',
          'stylist',
          'makeup_artist',
          'hair_stylist'
        )
      );
  end if;
end $$;

create index if not exists profiles_status_profile_type_idx
  on public.profiles (status, profile_type);
