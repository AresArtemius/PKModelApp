-- Back-office aggregate counters for staged admin tables.
-- Run after account_public_roles.sql and after castings/selections tables exist.

create index if not exists casting_responses_casting_id_idx
  on public.casting_responses (casting_id);

create index if not exists selection_items_selection_id_idx
  on public.selection_items (selection_id);

create or replace function public.admin_casting_response_counts(
  p_casting_ids uuid[]
)
returns table (
  casting_id uuid,
  response_count int
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    cr.casting_id,
    count(*)::int as response_count
  from public.casting_responses cr
  where public.current_user_is_admin()
    and cr.casting_id = any(coalesce(p_casting_ids, array[]::uuid[]))
  group by cr.casting_id;
$$;

grant execute on function public.admin_casting_response_counts(uuid[])
  to authenticated;

create or replace function public.admin_selection_item_counts(
  p_selection_ids uuid[]
)
returns table (
  selection_id uuid,
  item_count int
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    si.selection_id,
    count(*)::int as item_count
  from public.selection_items si
  where public.current_user_is_admin()
    and si.selection_id = any(coalesce(p_selection_ids, array[]::uuid[]))
  group by si.selection_id;
$$;

grant execute on function public.admin_selection_item_counts(uuid[])
  to authenticated;
