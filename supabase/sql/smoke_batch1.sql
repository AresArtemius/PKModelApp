-- Smoke 12.10, batch 1: post/comment editing, notification actor names, admin alerts for status requests.
-- Posts already allow UPDATE by the author (posts_update_own); comments get
-- the same. Run after feed_comments.sql.

alter table public.post_comments
  add column if not exists edited_at timestamptz;

alter table public.posts
  add column if not exists edited_at timestamptz;

drop policy if exists "post_comments_update_own" on public.post_comments;
create policy "post_comments_update_own"
  on public.post_comments for update
  to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

-- Notifications: «Кто-то лайкнул» → name, company, @tag, or the email
-- local part when the profile is empty.
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
    (select u.email from auth.users u where u.id = p_user_id),
    'Кто-то'
  );
$$;

-- Admins get an in-app/push notification when someone asks for the client
-- status (there was none, so requests went unnoticed).
create or replace function public.notify_admins_status_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
  v_name text := public.feed_actor_name(new.user_id);
begin
  if new.status <> 'pending' then
    return new;
  end if;
  for v_admin in select ur.user_id from public.user_roles ur where ur.role = 'admin'
  loop
    perform public.enqueue_app_notification(
      v_admin.user_id,
      'Заявка на статус заказчика',
      v_name || ' просит статус заказчика',
      '/casting_agent_applications_admin',
      'admin_status_request',
      jsonb_build_object('application_id', new.id, 'user_id', new.user_id)
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists casting_agent_applications_notify_admins on public.casting_agent_applications;
create trigger casting_agent_applications_notify_admins
  after insert on public.casting_agent_applications
  for each row execute function public.notify_admins_status_request();
