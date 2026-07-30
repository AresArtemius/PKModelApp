-- The profile action journal contains private audit data and message excerpts.
-- Only platform administrators may read it.

drop policy if exists "Profile action participants can view"
  on public.profile_action_logs;
drop policy if exists "Only admins can view profile action logs"
  on public.profile_action_logs;

create policy "Only admins can view profile action logs"
  on public.profile_action_logs
  for select
  to authenticated
  using (public.current_user_is_admin());
