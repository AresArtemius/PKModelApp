-- Step 62 (smoke): open an account page for accounts without a public @tag.
-- /u/<user_id> uses this; the @tag is returned only when it is public.
-- Run after account_profile_tags.sql.

create or replace function public.get_public_account_profile_by_id(p_user_id uuid)
returns table (
  user_id uuid,
  account_tag text,
  avatar_url text,
  full_name text,
  company_name text,
  account_position text,
  account_type text,
  city text,
  country text,
  website text,
  social_url text,
  bio text
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $fn$
  select
    up.user_id,
    case
      when up.account_tag_visibility = 'public' then coalesce(up.account_tag, '')
      else ''
    end as account_tag,
    up.avatar_url,
    up.full_name,
    up.company_name,
    up.position as account_position,
    up.account_type,
    up.city,
    up.country,
    up.website,
    up.social_url,
    up.bio
  from public.user_profiles up
  where up.user_id = p_user_id
  limit 1;
$fn$;

grant execute on function public.get_public_account_profile_by_id(uuid)
  to anon, authenticated;
