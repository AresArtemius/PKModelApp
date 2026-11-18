-- Moderation v2 (Admin → Safety): one place to act on every report.
--
--  * comment_reports: reports on a single comment (a user can now report a
--    post AND a comment under it — post_reports keeps one row per post per
--    reporter for older app builds).
--  * report_comment(): the app files a comment report through this RPC.
--  * user_suspensions + admin_suspend_user / admin_unsuspend_user: ejecting
--    an abusive user (sign-in blocked, sessions revoked, posts and comments
--    hidden from everyone) — App Review 1.2 «ejecting the user».
--  * admin_list_reports(): every report (post, comment, profile) with the
--    reported content, its author and the reporter, for the moderation queue.
--  * admin_resolve_reports(): one decision for all reports on one target —
--    dismiss / remove the content / remove and suspend the author; notifies
--    the reporters and the author.
--  * admin_list_user_blocks(), admin_list_suspensions(): the «Blocks» and
--    «Suspended» tabs.
--  * feed_post_visible / list_post_comments hide suspended authors.
--  * Admins may delete report rows (test reports).
--
-- Re-runnable. Run after feed_comments.sql, ugc_block_safety.sql,
-- feed_notifications.sql / push_notifications.sql.

-- ---------------------------------------------------------------------------
-- 1. Comment reports
-- ---------------------------------------------------------------------------
create table if not exists public.comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null,
  post_id uuid,
  comment_author_id uuid,
  comment_body text not null default '',
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  comment text not null default '',
  status text not null default 'open'
    check (status in ('open', 'in_review', 'resolved', 'closed', 'dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (comment_id, reporter_user_id)
);

create index if not exists comment_reports_status_created_idx
  on public.comment_reports (status, created_at desc);

alter table public.comment_reports enable row level security;

drop policy if exists "comment_reports_admin_all" on public.comment_reports;
create policy "comment_reports_admin_all"
  on public.comment_reports for all
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

drop policy if exists "comment_reports_read_own" on public.comment_reports;
create policy "comment_reports_read_own"
  on public.comment_reports for select
  to authenticated
  using (reporter_user_id = auth.uid());

create or replace function public.report_comment(
  p_comment_id uuid,
  p_reason text,
  p_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_c public.post_comments;
begin
  if v_me is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  select * into v_c from public.post_comments where id = p_comment_id;
  if v_c.id is null then
    return; -- the comment is already gone
  end if;
  insert into public.comment_reports
    (comment_id, post_id, comment_author_id, comment_body,
     reporter_user_id, reason, comment, status)
  values
    (v_c.id, v_c.post_id, v_c.author_id, v_c.body,
     v_me, coalesce(nullif(btrim(p_reason), ''), 'other'),
     left(coalesce(btrim(p_note), ''), 500), 'open')
  on conflict (comment_id, reporter_user_id) do update
    set reason = excluded.reason,
        comment = excluded.comment,
        status = 'open',
        updated_at = now();
end;
$$;

grant execute on function public.report_comment(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Suspensions (ejecting a user)
-- ---------------------------------------------------------------------------
create table if not exists public.user_suspensions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reason text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.user_suspensions enable row level security;

drop policy if exists "user_suspensions_admin_all" on public.user_suspensions;
create policy "user_suspensions_admin_all"
  on public.user_suspensions for all
  to authenticated
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

create or replace function public.user_is_suspended(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_user_id is not null
    and exists (select 1 from public.user_suspensions s where s.user_id = p_user_id);
$$;

grant execute on function public.user_is_suspended(uuid) to anon, authenticated;

create or replace function public.admin_suspend_user(
  p_user_id uuid,
  p_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  if p_user_id is null or p_user_id = auth.uid() then
    raise exception 'cannot suspend this account' using errcode = '22023';
  end if;
  if exists (select 1 from public.user_roles r where r.user_id = p_user_id and r.role = 'admin') then
    raise exception 'cannot suspend an admin' using errcode = '22023';
  end if;

  insert into public.user_suspensions (user_id, reason, created_by)
  values (p_user_id, left(coalesce(p_reason, ''), 500), auth.uid())
  on conflict (user_id) do update
    set reason = excluded.reason,
        created_by = excluded.created_by,
        created_at = now();

  -- Sign-in is refused while banned_until is in the future; existing
  -- sessions are revoked so the app is signed out at the next refresh.
  -- (The app also checks user_is_suspended() and signs the user out.)
  begin
    update auth.users
       set banned_until = now() + interval '100 years'
     where id = p_user_id;
    delete from auth.sessions where user_id = p_user_id;
  exception when insufficient_privilege then
    raise warning 'auth ban skipped: no privileges on auth schema';
  end;
end;
$$;

grant execute on function public.admin_suspend_user(uuid, text) to authenticated;

create or replace function public.admin_unsuspend_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  delete from public.user_suspensions where user_id = p_user_id;
  begin
    update auth.users set banned_until = null where id = p_user_id;
  exception when insufficient_privilege then
    raise warning 'auth unban skipped: no privileges on auth schema';
  end;
end;
$$;

grant execute on function public.admin_unsuspend_user(uuid) to authenticated;

-- Posts of a suspended author are hidden from everyone but admins.
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
        and not public.user_is_suspended(p.author_id)
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

grant execute on function public.feed_post_visible(public.posts) to anon, authenticated;

-- Comments: blocked pairs and suspended authors are hidden (admins see all).
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
      or (
        not public.feed_pair_blocked(auth.uid(), c.author_id)
        and not public.user_is_suspended(c.author_id)
      )
    )
  order by c.created_at asc, c.id asc
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
$$;

grant execute on function public.list_post_comments(uuid, integer) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. The moderation queue
-- ---------------------------------------------------------------------------
-- Older app builds filed a comment report as a post report whose note starts
-- with «Комментарий @tag (<comment uuid>): «text»». Those rows are shown as
-- comment reports too.
create or replace function public.moderation_legacy_comment_id(p_note text)
returns uuid
language sql
immutable
as $$
  select case
    when p_note ~* '^(Комментарий|Comment) [^\n]*\(([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\)'
    then (regexp_match(p_note, '\(([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\)'))[1]::uuid
    else null
  end;
$$;

drop function if exists public.admin_list_reports(integer);
create or replace function public.admin_list_reports(p_limit integer default 300)
returns table (
  report_id uuid,
  report_table text,
  kind text,              -- post | comment | profile
  target_id uuid,         -- post id | comment id | profile id
  post_id uuid,
  reason text,
  note text,
  status text,
  created_at timestamptz,
  reporter_id uuid,
  reporter_name text,
  content_text text,
  content_image text,
  author_id uuid,
  author_name text,
  author_tag text,
  content_removed boolean,
  author_suspended boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with reps as (
    -- post reports (and legacy comment reports)
    select
      r.id as report_id,
      'post_reports'::text as report_table,
      case when public.moderation_legacy_comment_id(r.comment) is null then 'post' else 'comment' end as kind,
      coalesce(public.moderation_legacy_comment_id(r.comment), r.post_id) as target_id,
      r.post_id,
      r.reason,
      case
        when public.moderation_legacy_comment_id(r.comment) is null then r.comment
        when position(E'\n' in r.comment) > 0 then substr(r.comment, position(E'\n' in r.comment) + 1)
        else ''
      end as note,
      r.status,
      r.created_at,
      r.reporter_user_id as reporter_id,
      public.moderation_legacy_comment_id(r.comment) as legacy_comment_id,
      r.comment as raw_note
    from public.post_reports r
    union all
    select
      cr.id, 'comment_reports', 'comment', cr.comment_id, cr.post_id,
      cr.reason, cr.comment, cr.status, cr.created_at, cr.reporter_user_id,
      null::uuid, ''
    from public.comment_reports cr
    union all
    select
      pr.id, 'profile_reports', 'profile', pr.profile_id, null::uuid,
      pr.reason, pr.comment, pr.status, pr.created_at, pr.reporter_user_id,
      null::uuid, ''
    from public.profile_reports pr
  )
  select
    x.report_id,
    x.report_table,
    x.kind,
    x.target_id,
    x.post_id,
    x.reason,
    coalesce(x.note, ''),
    coalesce(x.status, 'open'),
    x.created_at,
    x.reporter_id,
    coalesce(nullif(btrim(rup.full_name), ''), nullif(btrim(rup.company_name), ''),
             nullif(btrim(rup.email), ''), ''),
    -- content
    case x.kind
      when 'post' then coalesce(p.body, '')
      when 'comment' then coalesce(c.body, cr2.comment_body,
        substring(x.raw_note from '«(.*)»'), '')
      else coalesce(prof.full_name, '')
    end,
    case x.kind
      when 'post' then coalesce(
        (select nullif(m.thumbnail_url, '') from public.post_media m
          where m.post_id = p.id order by m.position limit 1),
        (select m.url from public.post_media m
          where m.post_id = p.id and m.media_type = 'image' order by m.position limit 1),
        '')
      when 'profile' then coalesce(prof.cover_photo_url, '')
      else ''
    end,
    -- author
    a.author_id,
    coalesce(nullif(btrim(aup.full_name), ''), nullif(btrim(aup.company_name), ''), ''),
    case when lower(coalesce(aup.account_tag_visibility, 'public')) = 'hidden'
      then '' else coalesce(aup.account_tag, '') end,
    case x.kind
      when 'post' then p.id is null or p.deleted_at is not null
      when 'comment' then c.id is null
      else prof.id is null or prof.status <> 'approved'
    end,
    public.user_is_suspended(a.author_id)
  from reps x
  left join public.posts p on x.kind = 'post' and p.id = x.target_id
  left join public.post_comments c on x.kind = 'comment' and c.id = x.target_id
  left join lateral (
    select cr.comment_body, cr.comment_author_id
    from public.comment_reports cr
    where x.kind = 'comment' and cr.comment_id = x.target_id
    limit 1
  ) cr2 on true
  left join public.profiles prof on x.kind = 'profile' and prof.id = x.target_id
  left join lateral (
    select case x.kind
      when 'post' then p.author_id
      when 'comment' then coalesce(c.author_id, cr2.comment_author_id)
      else prof.user_id
    end as author_id
  ) a on true
  left join public.user_profiles aup on aup.user_id = a.author_id
  left join public.user_profiles rup on rup.user_id = x.reporter_id
  where public.current_user_is_admin()
  order by x.created_at desc
  limit least(greatest(coalesce(p_limit, 300), 1), 1000);
$$;

grant execute on function public.admin_list_reports(integer) to authenticated;

-- One decision for every report on one target.
--   p_kind:     post | comment | profile
--   p_decision: dismiss | remove | remove_and_suspend
create or replace function public.admin_resolve_reports(
  p_kind text,
  p_target_id uuid,
  p_decision text,
  p_note text default ''
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
  v_post uuid;
  v_status text;
  v_count integer := 0;
  v_n integer;
  v_reporters uuid[];
  v_reporter uuid;
  v_checked text;   -- «Мы проверили …»
  v_removed text;   -- «… пост удалён»
  v_yours text;     -- «Ваш … удалён»
  v_changed integer := 0;
begin
  if not public.current_user_is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  if p_decision not in ('dismiss', 'remove', 'remove_and_suspend') then
    raise exception 'unknown decision %', p_decision using errcode = '22023';
  end if;
  v_status := case when p_decision = 'dismiss' then 'dismissed' else 'resolved' end;

  if p_kind = 'post' then
    select author_id, id into v_author, v_post from public.posts where id = p_target_id;
    v_checked := 'пост';
    v_removed := 'пост удалён';
    v_yours := 'Ваш пост удалён';
    select array_agg(distinct reporter_user_id) into v_reporters
      from public.post_reports
     where post_id = p_target_id
       and public.moderation_legacy_comment_id(comment) is null
       and status in ('open', 'in_review', 'reviewing');
  elsif p_kind = 'comment' then
    select author_id, post_id into v_author, v_post
      from public.post_comments where id = p_target_id;
    if v_author is null then
      select comment_author_id, post_id into v_author, v_post
        from public.comment_reports where comment_id = p_target_id limit 1;
    end if;
    v_checked := 'комментарий';
    v_removed := 'комментарий удалён';
    v_yours := 'Ваш комментарий удалён';
    select array_agg(distinct u) into v_reporters from (
      select reporter_user_id as u from public.comment_reports
       where comment_id = p_target_id and status in ('open', 'in_review', 'reviewing')
      union
      select reporter_user_id from public.post_reports
       where public.moderation_legacy_comment_id(comment) = p_target_id
         and status in ('open', 'in_review', 'reviewing')
    ) q;
  elsif p_kind = 'profile' then
    select user_id into v_author from public.profiles where id = p_target_id;
    v_checked := 'анкету';
    v_removed := 'анкета снята с публикации';
    v_yours := 'Ваша анкета снята с публикации';
    select array_agg(distinct reporter_user_id) into v_reporters
      from public.profile_reports
     where profile_id = p_target_id and status in ('open', 'reviewing', 'in_review');
  else
    raise exception 'unknown kind %', p_kind using errcode = '22023';
  end if;

  -- the content
  if p_decision in ('remove', 'remove_and_suspend') then
    if p_kind = 'post' then
      update public.posts set deleted_at = now()
       where id = p_target_id and deleted_at is null;
    elsif p_kind = 'comment' then
      delete from public.post_comments where id = p_target_id;
    else
      -- only a published profile is taken down; a pending one stays in the
      -- moderation queue
      update public.profiles
         set status = 'rejected',
             moderation_comment = coalesce(nullif(btrim(p_note), ''), 'Снята модератором по жалобе')
       where id = p_target_id and status = 'approved';
    end if;
    get diagnostics v_changed = row_count;
  end if;

  if p_decision = 'remove_and_suspend' and v_author is not null then
    perform public.admin_suspend_user(
      v_author,
      coalesce(nullif(btrim(p_note), ''), 'Жалоба: ' || v_checked)
    );
  end if;

  -- the reports
  if p_kind = 'post' then
    update public.post_reports set status = v_status, updated_at = now()
     where post_id = p_target_id
       and public.moderation_legacy_comment_id(comment) is null
       and status in ('open', 'in_review', 'reviewing');
    get diagnostics v_n = row_count; v_count := v_count + v_n;
  elsif p_kind = 'comment' then
    update public.comment_reports set status = v_status, updated_at = now()
     where comment_id = p_target_id and status in ('open', 'in_review', 'reviewing');
    get diagnostics v_n = row_count; v_count := v_count + v_n;
    update public.post_reports set status = v_status, updated_at = now()
     where public.moderation_legacy_comment_id(comment) = p_target_id
       and status in ('open', 'in_review', 'reviewing');
    get diagnostics v_n = row_count; v_count := v_count + v_n;
  else
    update public.profile_reports set status = v_status, updated_at = now()
     where profile_id = p_target_id and status in ('open', 'reviewing', 'in_review');
    get diagnostics v_n = row_count; v_count := v_count + v_n;
  end if;

  -- notifications: every reporter gets the outcome
  foreach v_reporter in array coalesce(v_reporters, '{}'::uuid[])
  loop
    continue when v_reporter is null;
    perform public.enqueue_app_notification(
      v_reporter,
      'Жалоба рассмотрена',
      case when p_decision = 'dismiss'
        then 'Мы проверили ' || v_checked || ' и не нашли нарушений правил. Спасибо, что сообщили.'
        else 'Мы рассмотрели вашу жалобу: ' || v_removed || '. Спасибо, что сообщили.'
      end,
      '/notifications',
      'report_resolved',
      jsonb_build_object('kind', p_kind, 'target_id', p_target_id, 'decision', p_decision)
    );
  end loop;

  -- the author is told when this decision removed their content (a
  -- suspended author cannot sign in, so nothing is sent then)
  if p_decision = 'remove' and v_changed > 0 and v_author is not null then
    perform public.enqueue_app_notification(
      v_author,
      'Контент удалён модератором',
      v_yours || ' за нарушение правил PK Management. '
        || 'Повторные нарушения приводят к блокировке аккаунта.',
      '/notifications',
      'content_removed',
      jsonb_build_object('kind', p_kind, 'target_id', p_target_id)
    );
  end if;

  return v_count;
end;
$$;

grant execute on function public.admin_resolve_reports(text, uuid, text, text) to authenticated;

-- «Blocks» tab: who blocked whom.
create or replace function public.admin_list_user_blocks(p_limit integer default 200)
returns table (
  blocker_id uuid,
  blocker_name text,
  blocked_id uuid,
  blocked_name text,
  blocked_tag text,
  blocked_suspended boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    b.blocker_user_id,
    coalesce(nullif(btrim(u1.full_name), ''), nullif(btrim(u1.company_name), ''), nullif(btrim(u1.email), ''), ''),
    b.blocked_user_id,
    coalesce(nullif(btrim(u2.full_name), ''), nullif(btrim(u2.company_name), ''), nullif(btrim(u2.email), ''), ''),
    case when lower(coalesce(u2.account_tag_visibility, 'public')) = 'hidden'
      then '' else coalesce(u2.account_tag, '') end,
    public.user_is_suspended(b.blocked_user_id),
    b.created_at
  from public.blocked_users b
  left join public.user_profiles u1 on u1.user_id = b.blocker_user_id
  left join public.user_profiles u2 on u2.user_id = b.blocked_user_id
  where public.current_user_is_admin()
  order by b.created_at desc
  limit least(greatest(coalesce(p_limit, 200), 1), 1000);
$$;

grant execute on function public.admin_list_user_blocks(integer) to authenticated;

-- «Suspended» tab.
create or replace function public.admin_list_suspensions()
returns table (
  user_id uuid,
  full_name text,
  account_tag text,
  email text,
  reason text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.user_id,
    coalesce(nullif(btrim(up.full_name), ''), nullif(btrim(up.company_name), ''), ''),
    coalesce(up.account_tag, ''),
    coalesce(up.email, ''),
    s.reason,
    s.created_at
  from public.user_suspensions s
  left join public.user_profiles up on up.user_id = s.user_id
  where public.current_user_is_admin()
  order by s.created_at desc;
$$;

grant execute on function public.admin_list_suspensions() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Admins may delete report rows (test reports, duplicates)
-- ---------------------------------------------------------------------------
drop policy if exists "post_reports_admin_delete" on public.post_reports;
create policy "post_reports_admin_delete"
  on public.post_reports for delete
  to authenticated
  using (public.current_user_is_admin());
