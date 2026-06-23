-- Atomic selection creation.
-- Run after roles_and_agent_approval.sql and after selections/selection_items exist.

alter table public.selections
  add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.selections
  add column if not exists request_video_intro boolean not null default false;

alter table public.selections
  add column if not exists video_intro_requirements text not null default '';

drop policy if exists "Casting agents and admins can create selections"
  on public.selections;

create policy "Casting agents and admins can create selections"
  on public.selections
  for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.current_user_can_create_selections()
  );

drop policy if exists "Selection owners and admins can view selections"
  on public.selections;

create policy "Selection owners and admins can view selections"
  on public.selections
  for select
  to authenticated
  using (
    created_by = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Selection owners and admins can create selection items"
  on public.selection_items;

create policy "Selection owners and admins can create selection items"
  on public.selection_items
  for insert
  to authenticated
  with check (
    public.current_user_can_create_selections()
    and exists (
      select 1
      from public.selections s
      where s.id = selection_items.selection_id
        and (
          s.created_by = auth.uid()
          or public.current_user_is_admin()
        )
    )
  );

create or replace function public.create_selection_with_items(
  p_title text,
  p_profile_ids uuid[],
  p_request_video_intro boolean default false,
  p_video_intro_requirements text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_selection_id uuid;
begin
  if not public.current_user_can_create_selections() then
    raise exception 'Only casting agents and admins can create selections';
  end if;

  if btrim(coalesce(p_title, '')) = '' then
    raise exception 'Selection title is required';
  end if;

  insert into public.selections (
    title,
    created_by,
    request_video_intro,
    video_intro_requirements
  )
  values (
    btrim(p_title),
    auth.uid(),
    coalesce(p_request_video_intro, false),
    btrim(coalesce(p_video_intro_requirements, ''))
  )
  returning id into v_selection_id;

  insert into public.selection_items (selection_id, profile_id)
  select v_selection_id, distinct_profile_id
  from (
    select distinct unnest(coalesce(p_profile_ids, array[]::uuid[]))
      as distinct_profile_id
  ) ids
  where distinct_profile_id is not null;

  return v_selection_id;
end;
$$;

grant execute on function public.create_selection_with_items(
  text,
  uuid[],
  boolean,
  text
) to authenticated;
