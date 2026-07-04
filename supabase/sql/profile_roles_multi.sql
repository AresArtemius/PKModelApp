-- Multi-role profiles: one profile can be Model + Actor + Photographer, etc.
-- Run this file as one piece in Supabase SQL Editor.

alter table public.profiles
  add column if not exists profile_roles text[] not null default array['model']::text[];

update public.profiles
set profile_roles = array[
  coalesce(nullif(btrim(profile_type), ''), 'model')
]
where coalesce(array_length(profile_roles, 1), 0) = 0;

update public.profiles
set profile_roles = (
  select array_agg(role order by first_pos)
  from (
    select role, min(pos) as first_pos
    from unnest(profile_roles) with ordinality as roles(role, pos)
    where role in (
      'model',
      'actor',
      'photographer',
      'videographer',
      'stylist',
      'makeup_artist',
      'hair_stylist'
    )
    group by role
  ) as cleaned
)
where exists (
  select 1
  from unnest(profile_roles) as role
  where role not in (
    'model',
    'actor',
    'photographer',
    'videographer',
    'stylist',
    'makeup_artist',
    'hair_stylist'
  )
);

update public.profiles
set profile_roles = array[
  coalesce(nullif(btrim(profile_type), ''), 'model')
]
where coalesce(array_length(profile_roles, 1), 0) = 0;

update public.profiles
set profile_type = profile_roles[1]
where profile_roles[1] is not null
  and profile_type is distinct from profile_roles[1];

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_profile_roles_check'
  ) then
    alter table public.profiles
      add constraint profiles_profile_roles_check
      check (
        array_length(profile_roles, 1) > 0
        and profile_roles <@ array[
          'model',
          'actor',
          'photographer',
          'videographer',
          'stylist',
          'makeup_artist',
          'hair_stylist'
        ]::text[]
      );
  end if;
end $$;

create index if not exists profiles_profile_roles_gin_idx
  on public.profiles using gin (profile_roles);
