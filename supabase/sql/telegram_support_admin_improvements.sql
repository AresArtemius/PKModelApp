-- Admin-managed FAQ for Telegram and in-app support.
-- Apply after telegram_support_mvp.sql.

drop policy if exists "Support staff can create support FAQ" on public.support_faq;
create policy "Support staff can create support FAQ"
  on public.support_faq for insert to authenticated
  with check (public.current_user_is_support_staff());

drop policy if exists "Support staff can update support FAQ" on public.support_faq;
create policy "Support staff can update support FAQ"
  on public.support_faq for update to authenticated
  using (public.current_user_is_support_staff())
  with check (public.current_user_is_support_staff());

drop policy if exists "Support staff can delete support FAQ" on public.support_faq;
create policy "Support staff can delete support FAQ"
  on public.support_faq for delete to authenticated
  using (public.current_user_is_support_staff());

grant insert, update, delete on public.support_faq to authenticated;
