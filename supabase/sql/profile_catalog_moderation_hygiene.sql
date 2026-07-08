-- Catalog moderation hygiene for legacy data.
-- New admin-created profiles are approved by the app UI immediately.
-- Use the report first, then repair only explicit legacy profile ids.

create or replace function public.catalog_moderation_hygiene_report()
returns table (
  id uuid,
  full_name text,
  status text,
  user_id uuid,
  has_media boolean,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.full_name,
    p.status,
    p.user_id,
    (
      coalesce(p.cover_photo_url, '') <> ''
      or coalesce(array_length(p.photo_urls, 1), 0) > 0
    ) as has_media,
    p.updated_at
  from public.profiles p
  where public.current_user_is_admin()
    and coalesce(p.status, '') <> 'approved'
    and (
      coalesce(p.cover_photo_url, '') <> ''
      or coalesce(array_length(p.photo_urls, 1), 0) > 0
    )
  order by p.updated_at desc nulls last, p.full_name;
$$;

grant execute on function public.catalog_moderation_hygiene_report()
  to authenticated;

create or replace function public.return_profiles_to_moderation(
  p_profile_ids uuid[]
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can repair profile moderation state';
  end if;

  update public.profiles
  set
    status = 'pending',
    moderation_comment = coalesce(
      nullif(moderation_comment, ''),
      'Returned to moderation because the profile existed before the current approval workflow.'
    )
  where id = any(coalesce(p_profile_ids, array[]::uuid[]))
    and coalesce(status, '') <> 'approved';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.return_profiles_to_moderation(uuid[])
  to authenticated;
