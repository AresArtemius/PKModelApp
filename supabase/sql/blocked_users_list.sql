-- "Blocked users" page in My account: who I blocked, with name/avatar/tag.
-- user_profiles is not readable across accounts, hence security definer.
-- Re-runnable.

create or replace function public.list_my_blocked_users(p_limit integer default 200)
returns table (
  user_id uuid,
  full_name text,
  avatar_url text,
  account_tag text,
  account_type text,
  blocked_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    b.blocked_user_id,
    coalesce(nullif(btrim(up.full_name), ''), nullif(btrim(up.company_name), ''), ''),
    coalesce(up.avatar_url, ''),
    case when lower(coalesce(up.account_tag_visibility, 'public')) = 'hidden'
      then '' else coalesce(up.account_tag, '') end,
    coalesce(up.account_type, ''),
    b.created_at
  from public.blocked_users b
  left join public.user_profiles up on up.user_id = b.blocked_user_id
  where b.blocker_user_id = auth.uid()
  order by b.created_at desc
  limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;

grant execute on function public.list_my_blocked_users(integer) to authenticated;
