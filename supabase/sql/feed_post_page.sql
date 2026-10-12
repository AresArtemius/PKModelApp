-- Step 62 (smoke): single post page. get_feed learns the `post:<uuid>`
-- scope, so /post/<id> can load one post (visibility rules unchanged —
-- feed_post_visible still applies). Run after feed_recommendations.sql.

create or replace function public.get_feed(
  p_cursor_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 20,
  p_scope text default 'home'   -- home | saved | author:<uuid> | post:<uuid>
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
  v_post uuid;
  v_follows_nobody boolean := false;
begin
  v_follows_nobody := v_me is not null and not exists (
    select 1 from public.follows f where f.follower_id = v_me
  );
  select lower(nullif(btrim(coalesce(up.city, '')), '')) into v_city
  from public.user_profiles up where up.user_id = v_me;

  if p_scope like 'author:%' then
    v_author := substring(p_scope from 8)::uuid;
  elsif p_scope like 'post:%' then
    v_post := substring(p_scope from 6)::uuid;
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
          when v_post is not null then p.id = v_post
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
