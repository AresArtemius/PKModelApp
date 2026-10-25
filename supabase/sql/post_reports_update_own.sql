-- A user may report the same post more than once (e.g. first the post, then
-- one of its comments): the client upserts on (post_id, reporter_user_id), so
-- the reporter needs UPDATE on their own open report. Re-runnable.

drop policy if exists "post_reports_update_own" on public.post_reports;
create policy "post_reports_update_own"
  on public.post_reports for update
  to authenticated
  using (reporter_user_id = auth.uid())
  with check (reporter_user_id = auth.uid());
