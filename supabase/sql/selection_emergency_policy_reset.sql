-- Emergency reset for recursive selection RLS policies.
-- Run this if invitations still show:
-- "infinite recursion detected in policy for relation selections".

drop policy if exists "Public can view published selections"
  on public.selections;
drop policy if exists "Selection owners and admins can view selections"
  on public.selections;
drop policy if exists "Selection owners and admins can view selection items"
  on public.selection_items;
drop policy if exists "Public can view published selection items"
  on public.selection_items;
drop policy if exists "Selection owners and admins can create selection items"
  on public.selection_items;

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
      and s.is_public = true
  );
$$;

grant execute on function public.current_user_has_selection_item(uuid)
  to anon, authenticated;
grant execute on function public.selection_is_public(uuid)
  to anon, authenticated;

create policy "Selection owners admins models can view selections"
  on public.selections
  for select
  to authenticated
  using (
    created_by = auth.uid()
    or public.current_user_has_selection_item(id)
    or public.current_user_is_admin()
  );

create policy "Anonymous can view public selections"
  on public.selections
  for select
  to anon
  using (is_public = true);

create policy "Models and public can view selection items"
  on public.selection_items
  for select
  to anon, authenticated
  using (
    public.selection_is_public(selection_id)
    or exists (
      select 1
      from public.profiles p
      where p.id = selection_items.profile_id
        and p.user_id = auth.uid()
    )
  );

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

create or replace function public.get_my_selection_invitations()
returns table (
  selection_id uuid,
  profile_id uuid,
  model_user_id uuid,
  created_at timestamptz,
  selection_title text,
  request_video_intro boolean,
  video_intro_requirements text,
  profile_name text,
  photo_urls text[]
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    si.selection_id,
    si.profile_id,
    p.user_id as model_user_id,
    si.created_at,
    coalesce(s.title, '') as selection_title,
    coalesce(s.request_video_intro, false) as request_video_intro,
    coalesce(s.video_intro_requirements, '') as video_intro_requirements,
    coalesce(p.full_name, '') as profile_name,
    coalesce(p.photo_urls, array[]::text[]) as photo_urls
  from public.selection_items si
  join public.profiles p on p.id = si.profile_id
  join public.selections s on s.id = si.selection_id
  where p.user_id = auth.uid()
  order by si.created_at desc;
$$;

grant execute on function public.get_my_selection_invitations()
  to authenticated;
