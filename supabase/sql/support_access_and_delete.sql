-- Support access hardening and ticket deletion.
-- Apply after support_center_mvp.sql.

drop policy if exists "Users can delete own support tickets" on public.support_tickets;
create policy "Users can delete own support tickets"
  on public.support_tickets for delete
  using (user_id = auth.uid());

drop policy if exists "Support staff can delete tickets" on public.support_tickets;
create policy "Support staff can delete tickets"
  on public.support_tickets for delete
  using (public.current_user_is_support_staff());

grant delete on public.support_tickets to authenticated;

