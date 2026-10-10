-- Step 48: feed notifications — like, comment, repost, follow.
--
-- Run after push_notifications.sql, feed_mvp.sql and feed_comments.sql in
-- the Supabase SQL Editor. Idempotent.
--
-- 1. notification_preferences.feed_enabled — the «Лента» toggle.
-- 2. enqueue_app_notification() learns the `feed` group: types feed_*
--    are skipped when the toggle is off (copy of the function from
--    push_notifications.sql with the extra group).
-- 3. Triggers on post_likes / post_comments / posts(repost) / follows that
--    notify the author (never about one's own actions, never across a block,
--    one like-notification per post per hour per liker).

alter table public.notification_preferences
  add column if not exists feed_enabled boolean not null default true;

alter table public.app_notifications
  add column if not exists type text not null default 'generic',
  add column if not exists data jsonb not null default '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- enqueue_app_notification with the feed group
-- ---------------------------------------------------------------------------

create or replace function public.enqueue_app_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_route text default '',
  p_type text default 'generic',
  p_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_profile_action_log_id uuid;
  v_email_to text := '';
  v_send_email boolean := false;
  v_event_group text := 'system';
  v_push_enabled boolean := true;
  v_email_enabled boolean := true;
  v_chat_enabled boolean := true;
  v_casting_enabled boolean := true;
  v_profile_enabled boolean := true;
  v_system_enabled boolean := true;
  v_feed_enabled boolean := true;
begin
  if p_user_id is null then
    return null;
  end if;

  v_event_group := case
    when coalesce(p_type, '') = 'chat_message' then 'chat'
    when coalesce(p_type, '') like 'feed_%' then 'feed'
    when coalesce(p_type, '') in (
      'selection_invitation',
      'video_intro_request'
    ) or coalesce(p_type, '') like 'casting_%' then 'casting'
    when coalesce(p_type, '') in (
      'profile_moderation',
      'casting_agent_moderation'
    ) then 'profile'
    else 'system'
  end;

  select
    coalesce(push_enabled, true),
    coalesce(email_enabled, true),
    coalesce(chat_enabled, true),
    coalesce(casting_enabled, true),
    coalesce(profile_enabled, true),
    coalesce(system_enabled, true),
    coalesce(feed_enabled, true)
  into
    v_push_enabled,
    v_email_enabled,
    v_chat_enabled,
    v_casting_enabled,
    v_profile_enabled,
    v_system_enabled,
    v_feed_enabled
  from public.notification_preferences
  where user_id = p_user_id;

  v_push_enabled := coalesce(v_push_enabled, true);
  v_email_enabled := coalesce(v_email_enabled, true);
  v_chat_enabled := coalesce(v_chat_enabled, true);
  v_casting_enabled := coalesce(v_casting_enabled, true);
  v_profile_enabled := coalesce(v_profile_enabled, true);
  v_system_enabled := coalesce(v_system_enabled, true);
  v_feed_enabled := coalesce(v_feed_enabled, true);

  if (v_event_group = 'chat' and not v_chat_enabled)
     or (v_event_group = 'casting' and not v_casting_enabled)
     or (v_event_group = 'profile' and not v_profile_enabled)
     or (v_event_group = 'system' and not v_system_enabled)
     or (v_event_group = 'feed' and not v_feed_enabled) then
    return null;
  end if;

  begin
    v_profile_action_log_id :=
      nullif(btrim(coalesce(p_data ->> 'profile_action_log_id', '')), '')::uuid;
  exception
    when others then
      v_profile_action_log_id := null;
  end;

  v_send_email := lower(coalesce(p_data ->> 'send_email', 'false')) in (
    'true',
    '1',
    'yes',
    'email'
  );

  if v_send_email then
    v_email_to := nullif(btrim(coalesce(p_data ->> 'email_to', '')), '');

    if v_email_to is null then
      select nullif(btrim(coalesce(email, '')), '')
      into v_email_to
      from public.user_profiles
      where user_id = p_user_id
      limit 1;
    end if;
  end if;

  insert into public.app_notifications (
    user_id,
    title,
    body,
    route,
    type,
    data,
    profile_action_log_id,
    push_status,
    push_error,
    email_status,
    email_to,
    email_subject,
    email_body,
    email_error
  )
  values (
    p_user_id,
    coalesce(p_title, ''),
    coalesce(p_body, ''),
    coalesce(p_route, ''),
    coalesce(nullif(btrim(p_type), ''), 'generic'),
    coalesce(p_data, '{}'::jsonb),
    v_profile_action_log_id,
    case when v_push_enabled then 'pending' else 'skipped' end,
    case when v_push_enabled then null else 'Push disabled by user preferences' end,
    case
      when v_send_email and v_email_enabled then 'pending'
      when v_send_email then 'skipped'
      else 'none'
    end,
    coalesce(v_email_to, ''),
    coalesce(nullif(btrim(p_data ->> 'email_subject'), ''), coalesce(p_title, '')),
    coalesce(nullif(btrim(p_data ->> 'email_body'), ''), coalesce(p_body, '')),
    case
      when v_send_email and not v_email_enabled then 'Email disabled by user preferences'
      else null
    end
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

/** Display name of an account for notification texts. */
create or replace function public.feed_actor_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select coalesce(
        nullif(btrim(up.full_name), ''),
        nullif(btrim(up.company_name), ''),
        case when nullif(btrim(up.account_tag), '') is not null then '@' || up.account_tag end
      )
      from public.user_profiles up
      where up.user_id = p_user_id
      limit 1
    ),
    'Кто-то'
  );
$$;

/** Short preview of a post for the notification body. */
create or replace function public.feed_post_preview(p_post public.posts)
returns text
language sql
stable
as $$
  select case
    when length(btrim(p_post.body)) > 0 then
      left(btrim(p_post.body), 80) || case when length(btrim(p_post.body)) > 80 then '…' else '' end
    when p_post.kind = 'media' then 'фото'
    when p_post.kind = 'casting' then 'кастинг'
    when p_post.kind = 'booked' then 'утверждение'
    when p_post.kind = 'repost' then 'репост'
    else 'пост'
  end;
$$;

-- ---------------------------------------------------------------------------
-- like
-- ---------------------------------------------------------------------------

create or replace function public.feed_notify_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.posts;
begin
  select * into v_post from public.posts p where p.id = new.post_id;
  if v_post.id is null or v_post.author_id = new.user_id then
    return new;
  end if;
  if public.feed_pair_blocked(v_post.author_id, new.user_id) then
    return new;
  end if;
  -- One notification per liker per post per hour (un-like / like again).
  if exists (
    select 1 from public.app_notifications n
    where n.user_id = v_post.author_id
      and n.type = 'feed_like'
      and n.data ->> 'post_id' = v_post.id::text
      and n.data ->> 'actor_id' = new.user_id::text
      and n.created_at > now() - interval '1 hour'
  ) then
    return new;
  end if;

  perform public.enqueue_app_notification(
    v_post.author_id,
    public.feed_actor_name(new.user_id) || ' оценил(а) ваш пост',
    public.feed_post_preview(v_post),
    '/feed',
    'feed_like',
    jsonb_build_object('post_id', v_post.id, 'actor_id', new.user_id)
  );
  return new;
end;
$$;

drop trigger if exists post_likes_notify on public.post_likes;
create trigger post_likes_notify
  after insert on public.post_likes
  for each row execute function public.feed_notify_like();

-- ---------------------------------------------------------------------------
-- comment
-- ---------------------------------------------------------------------------

create or replace function public.feed_notify_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.posts;
begin
  select * into v_post from public.posts p where p.id = new.post_id;
  if v_post.id is null or v_post.author_id = new.author_id then
    return new;
  end if;
  if public.feed_pair_blocked(v_post.author_id, new.author_id) then
    return new;
  end if;

  perform public.enqueue_app_notification(
    v_post.author_id,
    public.feed_actor_name(new.author_id) || ' прокомментировал(а) ваш пост',
    left(btrim(new.body), 120) || case when length(btrim(new.body)) > 120 then '…' else '' end,
    '/feed',
    'feed_comment',
    jsonb_build_object('post_id', v_post.id, 'comment_id', new.id, 'actor_id', new.author_id)
  );
  return new;
end;
$$;

drop trigger if exists post_comments_notify on public.post_comments;
create trigger post_comments_notify
  after insert on public.post_comments
  for each row execute function public.feed_notify_comment();

-- ---------------------------------------------------------------------------
-- repost (of a post; reposts of profiles notify the profile owner)
-- ---------------------------------------------------------------------------

create or replace function public.feed_notify_repost()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target uuid;
  v_source public.posts;
  v_body text := '';
begin
  if new.kind <> 'repost' then
    return new;
  end if;

  if new.repost_of is not null then
    select * into v_source from public.posts p where p.id = new.repost_of;
    v_target := v_source.author_id;
    v_body := public.feed_post_preview(v_source);
  elsif new.profile_id is not null then
    select pr.user_id, coalesce(pr.full_name, '') into v_target, v_body
    from public.profiles pr where pr.id = new.profile_id;
  else
    return new;
  end if;

  if v_target is null or v_target = new.author_id then
    return new;
  end if;
  if public.feed_pair_blocked(v_target, new.author_id) then
    return new;
  end if;

  perform public.enqueue_app_notification(
    v_target,
    public.feed_actor_name(new.author_id)
      || case when new.repost_of is not null then ' поделился(-ась) вашим постом' else ' поделился(-ась) вашей анкетой' end,
    v_body,
    '/feed',
    'feed_repost',
    jsonb_build_object('post_id', new.id, 'actor_id', new.author_id)
  );
  return new;
end;
$$;

drop trigger if exists posts_notify_repost on public.posts;
create trigger posts_notify_repost
  after insert on public.posts
  for each row execute function public.feed_notify_repost();

-- ---------------------------------------------------------------------------
-- follow
-- ---------------------------------------------------------------------------

create or replace function public.feed_notify_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tag text;
begin
  if new.follower_id = new.followee_id then
    return new;
  end if;
  if public.feed_pair_blocked(new.followee_id, new.follower_id) then
    return new;
  end if;
  -- Once per follower per day (follow / unfollow / follow).
  if exists (
    select 1 from public.app_notifications n
    where n.user_id = new.followee_id
      and n.type = 'feed_follow'
      and n.data ->> 'actor_id' = new.follower_id::text
      and n.created_at > now() - interval '1 day'
  ) then
    return new;
  end if;

  select nullif(btrim(up.account_tag), '') into v_tag
  from public.user_profiles up where up.user_id = new.follower_id;

  perform public.enqueue_app_notification(
    new.followee_id,
    public.feed_actor_name(new.follower_id) || ' подписался(-ась) на вас',
    '',
    case when v_tag is not null then '/@' || v_tag else '/following' end,
    'feed_follow',
    jsonb_build_object('actor_id', new.follower_id)
  );
  return new;
end;
$$;

drop trigger if exists follows_notify on public.follows;
create trigger follows_notify
  after insert on public.follows
  for each row execute function public.feed_notify_follow();

-- ---------------------------------------------------------------------------
-- Rollback (uncomment to undo; enqueue_app_notification keeps the feed group)
-- ---------------------------------------------------------------------------
-- drop trigger if exists follows_notify on public.follows;
-- drop trigger if exists posts_notify_repost on public.posts;
-- drop trigger if exists post_comments_notify on public.post_comments;
-- drop trigger if exists post_likes_notify on public.post_likes;
-- drop function if exists public.feed_notify_follow();
-- drop function if exists public.feed_notify_repost();
-- drop function if exists public.feed_notify_comment();
-- drop function if exists public.feed_notify_like();
-- drop function if exists public.feed_post_preview(public.posts);
-- drop function if exists public.feed_actor_name(uuid);
-- alter table public.notification_preferences drop column if exists feed_enabled;
