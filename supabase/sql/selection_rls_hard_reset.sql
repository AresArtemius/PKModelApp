-- Hard reset for recursive selection RLS.
-- Use this when Supabase shows:
-- infinite recursion detected in policy for relation "selections"

drop policy if exists "Public can view published selections"
  on public.selections;
drop policy if exists "Selection owners and admins can view selections"
  on public.selections;
drop policy if exists "Selection owners admins models can view selections"
  on public.selections;
drop policy if exists "Anonymous can view public selections"
  on public.selections;
drop policy if exists "Casting agents and admins can create selections"
  on public.selections;
drop policy if exists "Authenticated can view accessible selections"
  on public.selections;
drop policy if exists "Anon can view public selections"
  on public.selections;
drop policy if exists "Agents can create own selections"
  on public.selections;
drop policy if exists "Selection owners and admins can update selections"
  on public.selections;

drop policy if exists "Public can view published selection items"
  on public.selection_items;
drop policy if exists "Selection owners and admins can view selection items"
  on public.selection_items;
drop policy if exists "Models and public can view selection items"
  on public.selection_items;
drop policy if exists "Selection owners and admins can create selection items"
  on public.selection_items;
drop policy if exists "Selection participants can view items"
  on public.selection_items;
drop policy if exists "Anon can view public selection items"
  on public.selection_items;

alter table public.selections enable row level security;
alter table public.selection_items enable row level security;

create or replace function public.current_user_owns_selection(
  p_selection_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.selections s
    where s.id = p_selection_id
      and s.created_by = auth.uid()
  );
$$;

create or replace function public.current_user_has_selection_item(
  p_selection_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.selection_items si
    join public.profiles p on p.id = si.profile_id
    where si.selection_id = p_selection_id
      and p.user_id = auth.uid()
  );
$$;

create or replace function public.selection_is_public(
  p_selection_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.selections s
    where s.id = p_selection_id
      and coalesce(s.is_public, false) = true
  );
$$;

grant execute on function public.current_user_owns_selection(uuid)
  to authenticated;
grant execute on function public.current_user_has_selection_item(uuid)
  to authenticated;
grant execute on function public.selection_is_public(uuid)
  to anon, authenticated;

create policy "Authenticated can view accessible selections"
  on public.selections
  for select
  to authenticated
  using (
    coalesce(is_public, false)
    or created_by = auth.uid()
    or public.current_user_has_selection_item(id)
    or public.current_user_is_admin()
  );

create policy "Anon can view public selections"
  on public.selections
  for select
  to anon
  using (coalesce(is_public, false));

create policy "Agents can create own selections"
  on public.selections
  for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.current_user_can_create_selections()
  );

create policy "Selection owners and admins can update selections"
  on public.selections
  for update
  to authenticated
  using (
    created_by = auth.uid()
    or public.current_user_is_admin()
  )
  with check (
    created_by = auth.uid()
    or public.current_user_is_admin()
  );

create policy "Selection participants can view items"
  on public.selection_items
  for select
  to authenticated
  using (
    public.selection_is_public(selection_id)
    or public.current_user_owns_selection(selection_id)
    or public.current_user_has_selection_item(selection_id)
    or public.current_user_is_admin()
  );

create policy "Anon can view public selection items"
  on public.selection_items
  for select
  to anon
  using (public.selection_is_public(selection_id));

create policy "Selection owners and admins can create selection items"
  on public.selection_items
  for insert
  to authenticated
  with check (
    public.current_user_can_create_selections()
    and (
      public.current_user_owns_selection(selection_id)
      or public.current_user_is_admin()
    )
  );

notify pgrst, 'reload schema';
