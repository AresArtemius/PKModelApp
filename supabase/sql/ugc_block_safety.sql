-- App Review 1.2 (user-generated content): blocking a user must hide their
-- content instantly and notify the developer.
--  1. Comments of blocked users are hidden (posts already are: feed_post_visible).
--  2. Every block notifies all admins (in-app + push via enqueue_app_notification)
--     so the team can review the blocked account within 24 hours.
-- Re-runnable. Run after feed_comments.sql and smoke_batch1.sql.

-- 1. Comments: hide both directions of a block (admins see everything).
create or replace function public.list_post_comments(
  p_post_id uuid,
  p_limit integer default 100
)
returns table (
  id uuid,
  post_id uuid,
  author_id uuid,
  author_name text,
  author_avatar_url text,
  author_tag text,
  body text,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    c.id,
    c.post_id,
    c.author_id,
    coalesce(nullif(btrim(up.full_name), ''), nullif(btrim(up.company_name), ''), '') as author_name,
    coalesce(up.avatar_url, '') as author_avatar_url,
    case
      when lower(coalesce(up.account_tag_visibility, 'public')) = 'hidden' then ''
      else coalesce(up.account_tag, '')
    end as author_tag,
    c.body,
    c.created_at
  from public.post_comments c
  left join public.user_profiles up on up.user_id = c.author_id
  where c.post_id = p_post_id
    and (
      public.current_user_is_admin()
      or not public.feed_pair_blocked(auth.uid(), c.author_id)
    )
  order by c.created_at asc, c.id asc
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
$$;

grant execute on function public.list_post_comments(uuid, integer) to anon, authenticated;

-- 2. Notify admins about every block.
create or replace function public.notify_admins_user_blocked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
  v_blocker text := public.feed_actor_name(new.blocker_user_id);
  v_blocked text := public.feed_actor_name(new.blocked_user_id);
begin
  for v_admin in select ur.user_id from public.user_roles ur where ur.role = 'admin'
  loop
    perform public.enqueue_app_notification(
      v_admin.user_id,
      'Блокировка пользователя',
      v_blocker || ' заблокировал(а) ' || v_blocked || ' — проверьте аккаунт',
      '/admin_users?user=' || new.blocked_user_id::text,
      'admin_user_blocked',
      jsonb_build_object(
        'blocker_user_id', new.blocker_user_id,
        'blocked_user_id', new.blocked_user_id,
        'blocked_profile_id', new.blocked_profile_id
      )
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists blocked_users_notify_admins on public.blocked_users;
create trigger blocked_users_notify_admins
  after insert on public.blocked_users
  for each row execute function public.notify_admins_user_blocked();
