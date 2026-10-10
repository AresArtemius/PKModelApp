-- Step 47: comments under posts and reports on posts.
--
-- Run after feed_mvp.sql in the Supabase SQL Editor. Idempotent.
-- A rollback block is at the end of the file (commented out).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  check (length(btrim(body)) between 1 and 1000)
);

create index if not exists post_comments_post_idx
  on public.post_comments (post_id, created_at asc, id asc);

create table if not exists public.post_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  comment text not null default '',
  status text not null default 'open'
    check (status in ('open', 'in_review', 'resolved', 'closed', 'dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, reporter_user_id)
);

create index if not exists post_reports_status_created_idx
  on public.post_reports (status, created_at desc);

-- ---------------------------------------------------------------------------
-- Counters and defaults
-- ---------------------------------------------------------------------------

create or replace function public.feed_bump_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set comment_count = comment_count + 1 where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.posts
    set comment_count = greatest(comment_count - 1, 0)
    where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists post_comments_count on public.post_comments;
create trigger post_comments_count
  after insert or delete on public.post_comments
  for each row execute function public.feed_bump_comment_count();

/** Posts about a minor's profile start with comments switched off. */
create or replace function public.feed_posts_minor_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_age integer;
begin
  if new.profile_id is not null then
    select pr.age into v_age from public.profiles pr where pr.id = new.profile_id;
    if v_age is not null and v_age < 18 then
      new.comments_enabled := false;
      new.city := '';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists posts_minor_defaults on public.posts;
create trigger posts_minor_defaults
  before insert on public.posts
  for each row execute function public.feed_posts_minor_defaults();

create or replace function public.feed_touch_report_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists post_reports_touch on public.post_reports;
create trigger post_reports_touch
  before update on public.post_reports
  for each row execute function public.feed_touch_report_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.post_comments enable row level security;
alter table public.post_reports enable row level security;

drop policy if exists "post_comments_read" on public.post_comments;
create policy "post_comments_read"
  on public.post_comments for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = post_id and public.feed_post_visible(p)
    )
    and not public.feed_pair_blocked(auth.uid(), author_id)
  );

drop policy if exists "post_comments_insert" on public.post_comments;
create policy "post_comments_insert"
  on public.post_comments for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.posts p
      where p.id = post_id
        and p.comments_enabled
        and public.feed_post_visible(p)
    )
  );

-- The commenter, the post's author and admins can remove a comment.
drop policy if exists "post_comments_delete" on public.post_comments;
create policy "post_comments_delete"
  on public.post_comments for delete
  to authenticated
  using (
    author_id = auth.uid()
    or public.current_user_is_admin()
    or exists (
      select 1 from public.posts p
      where p.id = post_id and p.author_id = auth.uid()
    )
  );

drop policy if exists "post_reports_insert_own" on public.post_reports;
create policy "post_reports_insert_own"
  on public.post_reports for insert
  to authenticated
  with check (reporter_user_id = auth.uid());

drop policy if exists "post_reports_read" on public.post_reports;
create policy "post_reports_read"
  on public.post_reports for select
  to authenticated
  using (reporter_user_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "post_reports_admin_update" on public.post_reports;
create policy "post_reports_admin_update"
  on public.post_reports for update
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

-- Admins may hide any post (soft delete) from the moderation queue.
drop policy if exists "posts_admin_update" on public.posts;
create policy "posts_admin_update"
  on public.posts for update
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

-- ---------------------------------------------------------------------------
-- list_post_comments(post, limit): oldest first, with the author's card
-- ---------------------------------------------------------------------------

drop function if exists public.list_post_comments(uuid, integer);

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
  order by c.created_at asc, c.id asc
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
$$;

grant execute on function public.list_post_comments(uuid, integer) to anon, authenticated;

-- Admin queue: open reports with the post's text and author.
drop function if exists public.list_post_reports(text, integer);

create or replace function public.list_post_reports(
  p_status text default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  post_id uuid,
  reporter_user_id uuid,
  reason text,
  comment text,
  status text,
  created_at timestamptz,
  post_body text,
  post_kind text,
  post_author_id uuid,
  post_author_name text,
  post_deleted boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.post_id,
    r.reporter_user_id,
    r.reason,
    r.comment,
    r.status,
    r.created_at,
    coalesce(p.body, '') as post_body,
    coalesce(p.kind, '') as post_kind,
    p.author_id as post_author_id,
    coalesce(nullif(btrim(up.full_name), ''), nullif(btrim(up.company_name), ''), '') as post_author_name,
    (p.deleted_at is not null) as post_deleted
  from public.post_reports r
  left join public.posts p on p.id = r.post_id
  left join public.user_profiles up on up.user_id = p.author_id
  where public.current_user_is_admin()
    and (p_status is null or r.status = p_status)
  order by r.created_at desc
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
$$;

grant execute on function public.list_post_reports(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Rollback (uncomment to undo)
-- ---------------------------------------------------------------------------
-- drop function if exists public.list_post_reports(text, integer);
-- drop function if exists public.list_post_comments(uuid, integer);
-- drop policy if exists "posts_admin_update" on public.posts;
-- drop trigger if exists posts_minor_defaults on public.posts;
-- drop function if exists public.feed_posts_minor_defaults();
-- drop table if exists public.post_reports;
-- drop table if exists public.post_comments;
-- drop function if exists public.feed_bump_comment_count();
-- drop function if exists public.feed_touch_report_updated_at();
