-- Step 49: recommendations («Кого читать») and a non-empty feed for new
-- accounts.
--
-- Run after feed_mvp.sql (and feed_comments.sql) in the Supabase SQL Editor.
-- Idempotent.
--
-- 1. get_feed(): an account that follows nobody yet sees all public posts,
--    so the feed is never empty on day one (copy of the function from
--    feed_mvp.sql with one extra branch).
-- 2. suggest_follow_accounts(): who to follow — same city first, then the
--    most followed, then the most recently active; never me, never already
--    followed, never across a block.

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
  v_follows_nobody boolean := false;
begin
  v_follows_nobody := v_me is not null and not exists (
    select 1 from public.follows f where f.follower_id = v_me
  );
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
            -- Step 49: an account that follows nobody yet sees public posts.
            or (v_follows_nobody and p.visibility = 'public')
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
grant execute on function public.get_feed(timestamptz, uuid, integer, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- suggest_follow_accounts(limit)
-- ---------------------------------------------------------------------------

drop function if exists public.suggest_follow_accounts(integer);

create or replace function public.suggest_follow_accounts(
  p_limit integer default 10
)
returns table (
  user_id uuid,
  full_name text,
  avatar_url text,
  account_tag text,
  account_type text,
  city text,
  followers integer,
  reason text
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select
      auth.uid() as uid,
      (
        select lower(nullif(btrim(coalesce(up.city, '')), ''))
        from public.user_profiles up where up.user_id = auth.uid()
      ) as city
  ),
  candidates as (
    select
      up.user_id,
      coalesce(nullif(btrim(up.full_name), ''), nullif(btrim(up.company_name), ''), '') as full_name,
      coalesce(up.avatar_url, '') as avatar_url,
      case when lower(coalesce(up.account_tag_visibility, 'public')) = 'hidden'
        then '' else coalesce(up.account_tag, '') end as account_tag,
      coalesce(up.account_type, '') as account_type,
      coalesce(up.city, '') as city,
      (select count(*)::int from public.follows f where f.followee_id = up.user_id) as followers,
      (
        select max(p.created_at) from public.posts p
        where p.author_id = up.user_id and p.deleted_at is null
      ) as last_post_at,
      exists (
        select 1 from public.profiles pr
        where pr.user_id = up.user_id and pr.status = 'approved'
      ) as has_profile
    from public.user_profiles up, me
    where me.uid is not null
      and up.user_id <> me.uid
      and not exists (
        select 1 from public.follows f
        where f.follower_id = me.uid and f.followee_id = up.user_id
      )
      and not public.feed_pair_blocked(me.uid, up.user_id)
  )
  select
    c.user_id,
    c.full_name,
    c.avatar_url,
    c.account_tag,
    c.account_type,
    c.city,
    c.followers,
    case
      when me.city is not null and lower(c.city) = me.city then 'city'
      when c.followers >= 3 then 'popular'
      when c.last_post_at is not null then 'active'
      else 'profile'
    end as reason
  from candidates c, me
  where (c.has_profile or c.last_post_at is not null or c.followers > 0)
    and (c.full_name <> '' or c.account_tag <> '')
  order by
    (me.city is not null and lower(c.city) = me.city) desc,
    c.followers desc,
    c.last_post_at desc nulls last,
    c.user_id
  limit least(greatest(coalesce(p_limit, 10), 1), 50);
$$;

grant execute on function public.suggest_follow_accounts(integer) to authenticated;

-- Rollback: re-run the get_feed block of feed_mvp.sql and
-- drop function if exists public.suggest_follow_accounts(integer);
