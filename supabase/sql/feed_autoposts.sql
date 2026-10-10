-- Step 43. Autoposts for the feed. Run after feed_mvp.sql. Idempotent.
--
--   • profile media approved (moderation adds photos to photo_urls)  → post kind 'media'
--   • casting created / opened for applications                       → post kind 'casting'
--   • model approved for a casting (casting_responses.status=approved) → post kind 'booked',
--     only when BOTH the model's account and the casting owner agree
--   • «не публиковать автоматически»: notification_preferences.autopost_enabled
--
-- Autoposts carry auto = true; the author can delete them like any post.

alter table public.notification_preferences
  add column if not exists autopost_enabled boolean not null default true;

create or replace function public.feed_autopost_allowed(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_user_id is not null and coalesce(
    (select np.autopost_enabled from public.notification_preferences np where np.user_id = p_user_id),
    true
  );
$$;

-- ---------------------------------------------------------------------------
-- media: new photos in an approved profile
-- ---------------------------------------------------------------------------

create or replace function public.feed_autopost_profile_media()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new text[];
  v_post uuid;
  v_url text;
  v_pos integer := 0;
  v_city text;
begin
  if new.status is distinct from 'approved' then
    return new;
  end if;
  if new.user_id is null or not public.feed_autopost_allowed(new.user_id) then
    return new;
  end if;

  -- Photos that were not there before this update.
  select coalesce(array_agg(x order by n), '{}') into v_new
  from unnest(coalesce(new.photo_urls, '{}')) with ordinality as u(x, n)
  where btrim(x) <> ''
    and not (x = any (coalesce(old.photo_urls, '{}')));

  if coalesce(array_length(v_new, 1), 0) = 0 then
    return new;
  end if;

  -- One media post per profile per hour: later approvals extend it.
  select p.id into v_post
  from public.posts p
  where p.author_id = new.user_id
    and p.profile_id = new.id
    and p.kind = 'media'
    and p.auto
    and p.deleted_at is null
    and p.created_at > now() - interval '1 hour'
  order by p.created_at desc
  limit 1;

  v_city := coalesce(nullif(btrim(new.city), ''), '');

  if v_post is null then
    insert into public.posts (author_id, kind, body, visibility, profile_id, city, auto)
    values (new.user_id, 'media', '', 'public', new.id, v_city, true)
    returning id into v_post;
  else
    select coalesce(max(m.position), -1) + 1 into v_pos
    from public.post_media m where m.post_id = v_post;
  end if;

  foreach v_url in array v_new loop
    exit when v_pos >= 10;
    insert into public.post_media (post_id, position, media_type, url)
    values (v_post, v_pos, 'image', v_url);
    v_pos := v_pos + 1;
  end loop;

  return new;
end;
$$;

drop trigger if exists profiles_feed_autopost_media on public.profiles;
create trigger profiles_feed_autopost_media
  after update of photo_urls, status on public.profiles
  for each row execute function public.feed_autopost_profile_media();

-- ---------------------------------------------------------------------------
-- casting: created, or moved to «accepting applications»
-- ---------------------------------------------------------------------------

create or replace function public.feed_autopost_casting()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_stage text := coalesce(new.project_stage, 'intake');
  v_fire boolean := false;
begin
  begin
    v_owner := new.created_by;
  exception when undefined_column then
    v_owner := null;
  end;
  if v_owner is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_fire := v_stage in ('intake', 'accepting_applications');
  elsif tg_op = 'UPDATE' then
    v_fire := v_stage = 'accepting_applications'
      and coalesce(old.project_stage, 'intake') <> 'accepting_applications';
  end if;
  if not v_fire or not public.feed_autopost_allowed(v_owner) then
    return new;
  end if;

  -- One casting post per casting.
  if exists (
    select 1 from public.posts p
    where p.casting_id = new.id and p.kind = 'casting' and p.auto and p.deleted_at is null
  ) then
    return new;
  end if;

  insert into public.posts (author_id, kind, body, visibility, casting_id, auto)
  values (v_owner, 'casting', coalesce(new.title, ''), 'public', new.id, true);
  return new;
end;
$$;

drop trigger if exists castings_feed_autopost on public.castings;
create trigger castings_feed_autopost
  after insert or update of project_stage on public.castings
  for each row execute function public.feed_autopost_casting();

-- ---------------------------------------------------------------------------
-- booked: a response approved — both sides must allow autoposts
-- ---------------------------------------------------------------------------

create or replace function public.feed_autopost_booked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_model uuid;
  v_owner uuid;
  v_title text;
begin
  if coalesce(new.status, '') <> 'approved'
     or (tg_op = 'UPDATE' and coalesce(old.status, '') = 'approved') then
    return new;
  end if;

  select pr.user_id into v_model from public.profiles pr where pr.id = new.profile_id;
  begin
    select c.created_by, c.title into v_owner, v_title
    from public.castings c where c.id = new.casting_id;
  exception when undefined_column then
    v_owner := null;
  end;

  if v_model is null or v_owner is null then
    return new;
  end if;
  if not public.feed_autopost_allowed(v_model) or not public.feed_autopost_allowed(v_owner) then
    return new;
  end if;
  if exists (
    select 1 from public.posts p
    where p.kind = 'booked' and p.auto and p.deleted_at is null
      and p.casting_id = new.casting_id and p.profile_id = new.profile_id
  ) then
    return new;
  end if;

  insert into public.posts (author_id, kind, body, visibility, profile_id, casting_id, auto)
  values (v_model, 'booked', coalesce(v_title, ''), 'public', new.profile_id, new.casting_id, true);
  return new;
end;
$$;

drop trigger if exists casting_responses_feed_autopost on public.casting_responses;
create trigger casting_responses_feed_autopost
  after insert or update of status on public.casting_responses
  for each row execute function public.feed_autopost_booked();

-- Rollback:
-- drop trigger if exists profiles_feed_autopost_media on public.profiles;
-- drop trigger if exists castings_feed_autopost on public.castings;
-- drop trigger if exists casting_responses_feed_autopost on public.casting_responses;
-- drop function if exists public.feed_autopost_profile_media();
-- drop function if exists public.feed_autopost_casting();
-- drop function if exists public.feed_autopost_booked();
-- drop function if exists public.feed_autopost_allowed(uuid);
-- alter table public.notification_preferences drop column if exists autopost_enabled;
