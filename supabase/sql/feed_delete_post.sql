-- Step 62 (smoke): soft-deleting a post failed with «new row violates
-- row-level security policy»: Postgres re-checks the updated row against
-- the SELECT policy (feed_post_visible), which is false once deleted_at
-- is set. Deleting now goes through a definer function that checks the
-- caller itself. Run after feed_mvp.sql.

create or replace function public.delete_post(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_author uuid;
begin
  if v_me is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  select author_id into v_author from public.posts where id = p_post_id;
  if v_author is null then
    return; -- already gone
  end if;
  if v_author <> v_me and not public.current_user_is_admin() then
    raise exception 'not your post' using errcode = '42501';
  end if;
  update public.posts
     set deleted_at = coalesce(deleted_at, now())
   where id = p_post_id;
end;
$$;

grant execute on function public.delete_post(uuid) to authenticated;
