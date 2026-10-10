-- Step 41. Feed MVP: follows, posts, media, likes, saves; counters kept by
-- triggers; RLS by visibility, blocks and profile status; get_feed() with
-- keyset pagination.
--
-- Run this whole file in the Supabase SQL Editor after
-- marketplace_pipeline_notifications_safety_analytics.sql (blocked_users)
-- and account_profile_tags.sql (user_profiles.account_tag). Idempotent.
-- A rollback block is at the end of the file (commented out).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followee_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create index if not exists follows_followee_idx
  on public.follows (followee_id, created_at desc);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  -- text | media | casting | booked | repost (autoposts come from step 43)
  kind text not null default 'text',
  body text not null default '',
  -- public | followers | private
  visibility text not null default 'public',
  profile_id uuid references public.profiles(id) on delete set null,
  casting_id uuid references public.castings(id) on delete set null,
  repost_of uuid references public.posts(id) on delete set null,
  city text not null default '',
  comments_enabled boolean not null default true,
  auto boolean not null default false,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  repost_count integer not null default 0,
  save_count integer not null default 0,
  media_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (kind in ('text', 'media', 'casting', 'booked', 'repost')),
  check (visibility in ('public', 'followers', 'private')),
  check (length(body) <= 4000)
);

create index if not exists posts_author_created_idx
  on public.posts (author_id, created_at desc, id desc)
  where deleted_at is null;
create index if not exists posts_created_idx
  on public.posts (created_at desc, id desc)
  where deleted_at is null;
create index if not exists posts_city_idx
  on public.posts (lower(city))
  where deleted_at is null and kind = 'casting';

create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  position integer not null default 0,
  media_type text not null default 'image',
  url text not null,
  thumbnail_url text not null default '',
  width integer,
  height integer,
  created_at timestamptz not null default now(),
  check (media_type in ('image', 'video'))
);

create index if not exists post_media_post_idx
  on public.post_media (post_id, position);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists post_likes_user_idx
  on public.post_likes (user_id, created_at desc);

create table if not exists public.post_saves (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists post_saves_user_idx
  on public.post_saves (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Counters by triggers
-- ---------------------------------------------------------------------------

create or replace function public.feed_bump_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set like_count = like_count + 1 where id = new.post_id;
    return new;
  else
    update public.posts
    set like_count = greatest(like_count - 1, 0)
    where id = old.post_id;
    return old;
  end if;
end;
$$;

drop trigger if exists post_likes_count on public.post_likes;
create trigger post_likes_count
  after insert or delete on public.post_likes
  for each row execute function public.feed_bump_like_count();

create or replace function public.feed_bump_save_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set save_count = save_count + 1 where id = new.post_id;
    return new;
  else
    update public.posts
    set save_count = greatest(save_count - 1, 0)
    where id = old.post_id;
    return old;
  end if;
end;
$$;

drop trigger if exists post_saves_count on public.post_saves;
create trigger post_saves_count
  after insert or delete on public.post_saves
  for each row execute function public.feed_bump_save_count();

create or replace function public.feed_bump_media_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post uuid := coalesce(new.post_id, old.post_id);
begin
  update public.posts p
  set media_count = (select count(*) from public.post_media m where m.post_id = p.id)
  where p.id = v_post;
  return coalesce(new, old);
end;
$$;

drop trigger if exists post_media_count on public.post_media;
create trigger post_media_count
  after insert or delete on public.post_media
  for each row execute function public.feed_bump_media_count();

create or replace function public.feed_bump_repost_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.repost_of is not null then
    update public.posts set repost_count = repost_count + 1 where id = new.repost_of;
  elsif tg_op = 'UPDATE' and new.repost_of is not null
      and new.deleted_at is not null and old.deleted_at is null then
    update public.posts
    set repost_count = greatest(repost_count - 1, 0)
    where id = new.repost_of;
  elsif tg_op = 'DELETE' and old.repost_of is not null and old.deleted_at is null then
    update public.posts
    set repost_count = greatest(repost_count - 1, 0)
    where id = old.repost_of;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists posts_repost_count on public.posts;
create trigger posts_repost_count
  after insert or update of deleted_at or delete on public.posts
  for each row execute function public.feed_bump_repost_count();

create or replace function public.feed_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists posts_touch_updated_at on public.posts;
create trigger posts_touch_updated_at
  before update on public.posts
  for each row execute function public.feed_touch_updated_at();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

/** True when either side blocked the other. */
create or replace function public.feed_pair_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select a is not null and b is not null and a <> b and exists (
    select 1 from public.blocked_users x
    where (x.blocker_user_id = a and x.blocked_user_id = b)
       or (x.blocker_user_id = b and x.blocked_user_id = a)
  );
$$;

/** Can the current user see this post? Used by RLS and get_feed. */
create or replace function public.feed_post_visible(p public.posts)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p.deleted_at is null
    and (
      p.author_id = auth.uid()
      or public.current_user_is_admin()
      or (
        not public.feed_pair_blocked(auth.uid(), p.author_id)
        -- a post about a profile shows only while that profile is approved
        and (
          p.profile_id is null
          or exists (
            select 1 from public.profiles pr
            where pr.id = p.profile_id and pr.status = 'approved'
          )
        )
        and (
          p.visibility = 'public'
          or (
            p.visibility = 'followers'
            and auth.uid() is not null
            and exists (
              select 1 from public.follows f
              where f.follower_id = auth.uid() and f.followee_id = p.author_id
            )
          )
        )
      )
    );
$$;

grant execute on function public.feed_pair_blocked(uuid, uuid) to anon, authenticated;
grant execute on function public.feed_post_visible(public.posts) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.follows enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_saves enable row level security;

drop policy if exists "follows_read" on public.follows;
create policy "follows_read"
  on public.follows for select
  to authenticated
  using (true);

drop policy if exists "follows_manage_own" on public.follows;
create policy "follows_manage_own"
  on public.follows for all
  to authenticated
  using (follower_id = auth.uid())
  with check (
    follower_id = auth.uid()
    and not public.feed_pair_blocked(follower_id, followee_id)
  );

drop policy if exists "posts_read" on public.posts;
create policy "posts_read"
  on public.posts for select
  to anon, authenticated
  using (public.feed_post_visible(posts));

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own"
  on public.posts for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and (
      profile_id is null
      or exists (
        select 1 from public.profiles pr
        where pr.id = profile_id and pr.user_id = auth.uid()
      )
      or public.current_user_is_admin()
    )
  );

drop policy if exists "posts_update_own" on public.posts;
create policy "posts_update_own"
  on public.posts for update
  to authenticated
  using (author_id = auth.uid() or public.current_user_is_admin())
  with check (author_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own"
  on public.posts for delete
  to authenticated
  using (author_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "post_media_read" on public.post_media;
create policy "post_media_read"
  on public.post_media for select
  to anon, authenticated
  using (exists (
    select 1 from public.posts p
    where p.id = post_media.post_id and public.feed_post_visible(p)
  ));

drop policy if exists "post_media_manage_own" on public.post_media;
create policy "post_media_manage_own"
  on public.post_media for all
  to authenticated
  using (exists (
    select 1 from public.posts p
    where p.id = post_media.post_id
      and (p.author_id = auth.uid() or public.current_user_is_admin())
  ))
  with check (exists (
    select 1 from public.posts p
    where p.id = post_media.post_id
      and (p.author_id = auth.uid() or public.current_user_is_admin())
  ));

drop policy if exists "post_likes_read" on public.post_likes;
create policy "post_likes_read"
  on public.post_likes for select
  to authenticated
  using (true);

drop policy if exists "post_likes_manage_own" on public.post_likes;
create policy "post_likes_manage_own"
  on public.post_likes for all
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.posts p
      where p.id = post_likes.post_id and public.feed_post_visible(p)
    )
  );

drop policy if exists "post_saves_read_own" on public.post_saves;
create policy "post_saves_read_own"
  on public.post_saves for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "post_saves_manage_own" on public.post_saves;
create policy "post_saves_manage_own"
  on public.post_saves for all
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.posts p
      where p.id = post_saves.post_id and public.feed_post_visible(p)
    )
  );

-- ---------------------------------------------------------------------------
-- Follow counts (step 42 reads them)
-- ---------------------------------------------------------------------------

create or replace function public.follow_counts(p_user_id uuid)
returns table (followers integer, following integer, i_follow boolean)
language sql
stable
security definer
set search_path = public
as $$
  select
    (select count(*)::int from public.follows f where f.followee_id = p_user_id),
    (select count(*)::int from public.follows f where f.follower_id = p_user_id),
    exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.followee_id = p_user_id
    );
$$;

grant execute on function public.follow_counts(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- get_feed(cursor, limit): keyset pagination over (created_at, id)
-- ---------------------------------------------------------------------------
-- Sources: my own posts, posts of people I follow, and public casting posts
-- (filtered to my city when my account has one). The cursor is the
-- (created_at, id) of the last row of the previous page.

drop function if exists public.get_feed(timestamptz, uuid, integer, text);

create or replace function public.get_feed(
  p_cursor_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 20,
  p_scope text default 'home'   -- home | saved | author:<uuid>
)
returns table (
  id uuid,
  author_id uuid,
  author_name text,
  author_avatar_url text,
  author_tag text,
  author_account_type text,
  kind text,
  body text,
  visibility text,
  profile_id uuid,
  profile_name text,
  profile_photo_url text,
  casting_id uuid,
  casting_title text,
  repost_of uuid,
  repost_author_name text,
  repost_body text,
  city text,
  comments_enabled boolean,
  auto boolean,
  like_count integer,
  comment_count integer,
  repost_count integer,
  save_count integer,
  media jsonb,
  liked boolean,
  saved boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_city text;
  v_author uuid;
begin
  select lower(nullif(btrim(coalesce(up.city, '')), '')) into v_city
  from public.user_profiles up where up.user_id = v_me;

  if p_scope like 'author:%' then
    v_author := substring(p_scope from 8)::uuid;
  end if;

  return query
  with candidates as (
    select p.*
    from public.posts p
    where p.deleted_at is null
      and (
        case
          when p_scope = 'saved' then
            v_me is not null and exists (
              select 1 from public.post_saves s
              where s.post_id = p.id and s.user_id = v_me
            )
          when v_author is not null then p.author_id = v_author
          else
            p.author_id = v_me
            or exists (
              select 1 from public.follows f
              where f.follower_id = v_me and f.followee_id = p.author_id
            )
            or (
              p.kind = 'casting'
              and p.visibility = 'public'
              and (v_city is null or p.city = '' or lower(p.city) = v_city)
            )
        end
      )
      and public.feed_post_visible(p)
      and (
        p_cursor_at is null
        or (p.created_at, p.id) < (p_cursor_at, coalesce(p_cursor_id, '00000000-0000-0000-0000-000000000000'::uuid))
      )
    order by p.created_at desc, p.id desc
    limit v_limit
  )
  select
    c.id,
    c.author_id,
    coalesce(nullif(btrim(up.full_name), ''), nullif(btrim(up.company_name), ''), '') as author_name,
    coalesce(up.avatar_url, '') as author_avatar_url,
    case
      when lower(coalesce(up.account_tag_visibility, 'public')) = 'hidden' then ''
      else coalesce(up.account_tag, '')
    end as author_tag,
    coalesce(up.account_type, '') as author_account_type,
    c.kind,
    c.body,
    c.visibility,
    c.profile_id,
    coalesce(pr.full_name, '') as profile_name,
    coalesce(
      nullif(btrim(pr.cover_photo_url), ''),
      (
        select x from unnest(pr.photo_urls) with ordinality as u(x, n)
        where btrim(x) <> '' order by n limit 1
      ),
      ''
    ) as profile_photo_url,
    c.casting_id,
    coalesce(cs.title, '') as casting_title,
    c.repost_of,
    coalesce(nullif(btrim(rup.full_name), ''), nullif(btrim(rup.company_name), ''), '') as repost_author_name,
    coalesce(rp.body, '') as repost_body,
    c.city,
    c.comments_enabled,
    c.auto,
    c.like_count,
    c.comment_count,
    c.repost_count,
    c.save_count,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', m.id,
            'type', m.media_type,
            'url', m.url,
            'thumbnail_url', m.thumbnail_url,
            'width', m.width,
            'height', m.height
          )
          order by m.position
        )
        from public.post_media m where m.post_id = c.id
      ),
      '[]'::jsonb
    ) as media,
    exists (
      select 1 from public.post_likes l where l.post_id = c.id and l.user_id = v_me
    ) as liked,
    exists (
      select 1 from public.post_saves s where s.post_id = c.id and s.user_id = v_me
    ) as saved,
    c.created_at
  from candidates c
  left join public.user_profiles up on up.user_id = c.author_id
  left join public.profiles pr on pr.id = c.profile_id
  left join public.castings cs on cs.id = c.casting_id
  left join public.posts rp on rp.id = c.repost_of
  left join public.user_profiles rup on rup.user_id = rp.author_id
  order by c.created_at desc, c.id desc;
end;
$$;

grant execute on function public.get_feed(timestamptz, uuid, integer, text)
  to anon, authenticated;

-- Realtime: posts for live updates of the feed (optional).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'posts'
     ) then
    alter publication supabase_realtime add table public.posts;
  end if;
end $$;


-- ---------------------------------------------------------------------------
-- Step 42. Who I follow / who follows me (user_profiles is not readable
-- across accounts, so the lists come through security-definer RPCs).
-- ---------------------------------------------------------------------------

drop function if exists public.list_follow_accounts(text, uuid, integer);

create or replace function public.list_follow_accounts(
  p_direction text default 'following',   -- following | followers
  p_user_id uuid default null,            -- whose list; null = mine
  p_limit integer default 200
)
returns table (
  user_id uuid,
  full_name text,
  avatar_url text,
  account_tag text,
  account_type text,
  followed_at timestamptz,
  i_follow boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with target as (select coalesce(p_user_id, auth.uid()) as uid),
  pairs as (
    select
      case when p_direction = 'followers' then f.follower_id else f.followee_id end as other_id,
      f.created_at
    from public.follows f, target t
    where case when p_direction = 'followers'
      then f.followee_id = t.uid else f.follower_id = t.uid end
  )
  select
    pr.other_id,
    coalesce(nullif(btrim(up.full_name), ''), nullif(btrim(up.company_name), ''), ''),
    coalesce(up.avatar_url, ''),
    case when lower(coalesce(up.account_tag_visibility, 'public')) = 'hidden'
      then '' else coalesce(up.account_tag, '') end,
    coalesce(up.account_type, ''),
    pr.created_at,
    exists (
      select 1 from public.follows x
      where x.follower_id = auth.uid() and x.followee_id = pr.other_id
    )
  from pairs pr
  left join public.user_profiles up on up.user_id = pr.other_id
  where auth.uid() is not null
    and not public.feed_pair_blocked(auth.uid(), pr.other_id)
  order by pr.created_at desc
  limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;

grant execute on function public.list_follow_accounts(text, uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Rollback (run by hand if the feed has to go)
-- ---------------------------------------------------------------------------
-- drop function if exists public.get_feed(timestamptz, uuid, integer, text);
-- drop function if exists public.follow_counts(uuid);
-- drop function if exists public.list_follow_accounts(text, uuid, integer);
-- drop function if exists public.feed_post_visible(public.posts);
-- drop function if exists public.feed_pair_blocked(uuid, uuid);
-- drop table if exists public.post_saves;
-- drop table if exists public.post_likes;
-- drop table if exists public.post_media;
-- drop table if exists public.posts;
-- drop table if exists public.follows;
-- drop function if exists public.feed_bump_like_count();
-- drop function if exists public.feed_bump_save_count();
-- drop function if exists public.feed_bump_media_count();
-- drop function if exists public.feed_bump_repost_count();
-- drop function if exists public.feed_touch_updated_at();
