-- Adds manual focal point for profile cover photos.
-- x/y use Flutter Alignment coordinates: -1..1.
-- y = -1 means top, 0 center, 1 bottom.

alter table public.profiles
  add column if not exists cover_photo_focal_x double precision not null default 0,
  add column if not exists cover_photo_focal_y double precision not null default -0.72,
  add column if not exists pending_cover_photo_focal_x double precision not null default 0,
  add column if not exists pending_cover_photo_focal_y double precision not null default -0.72;

update public.profiles
set
  cover_photo_focal_x = greatest(-1, least(1, coalesce(cover_photo_focal_x, 0))),
  cover_photo_focal_y = greatest(-1, least(1, coalesce(cover_photo_focal_y, -0.72))),
  pending_cover_photo_focal_x = greatest(-1, least(1, coalesce(pending_cover_photo_focal_x, 0))),
  pending_cover_photo_focal_y = greatest(-1, least(1, coalesce(pending_cover_photo_focal_y, -0.72)));

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_cover_photo_focal_x_check'
  ) then
    alter table public.profiles
      add constraint profiles_cover_photo_focal_x_check
      check (cover_photo_focal_x between -1 and 1);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_cover_photo_focal_y_check'
  ) then
    alter table public.profiles
      add constraint profiles_cover_photo_focal_y_check
      check (cover_photo_focal_y between -1 and 1);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_pending_cover_photo_focal_x_check'
  ) then
    alter table public.profiles
      add constraint profiles_pending_cover_photo_focal_x_check
      check (pending_cover_photo_focal_x between -1 and 1);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_pending_cover_photo_focal_y_check'
  ) then
    alter table public.profiles
      add constraint profiles_pending_cover_photo_focal_y_check
      check (pending_cover_photo_focal_y between -1 and 1);
  end if;
end $$;
