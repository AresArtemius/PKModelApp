-- Step 45: reposts of someone else's profile / casting / post.
--
-- feed_mvp.sql allows a post to reference `profile_id` only when the profile
-- is the author's own (or the author is admin). A repost of a profile from
-- the catalogue points at another user's approved profile, so the insert
-- policy gets one more branch: kind = 'repost' + the profile is approved.
-- Run after feed_mvp.sql in the Supabase SQL Editor. Idempotent.

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
      or (
        kind = 'repost'
        and exists (
          select 1 from public.profiles pr
          where pr.id = profile_id and pr.status = 'approved'
        )
      )
    )
    -- a repost of a post must point at a post the author can see
    and (
      repost_of is null
      or exists (
        select 1 from public.posts src
        where src.id = repost_of
          and src.deleted_at is null
          and public.feed_post_visible(src)
      )
    )
  );
