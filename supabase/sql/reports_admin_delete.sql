-- Admins may delete post reports (test reports, duplicates) from
-- Admin → Safety. profile_reports already allows it ("reports_admin_all").
-- Re-runnable.

drop policy if exists "post_reports_admin_delete" on public.post_reports;
create policy "post_reports_admin_delete"
  on public.post_reports for delete
  to authenticated
  using (public.current_user_is_admin());
