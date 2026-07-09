-- Public client-facing selections with like/reject/comment feedback.
-- Run after selection_statuses.sql and selection_rls_hard_reset.sql.

alter table public.selections
  add column if not exists is_public boolean not null default false;

alter table public.selections
  add column if not exists status text not null default 'draft';

create index if not exists selections_is_public_created_at_idx
  on public.selections (is_public, created_at desc);

create table if not exists public.selection_client_feedback (
  selection_id uuid not null references public.selections(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  client_key text not null,
  vote text check (vote in ('liked', 'rejected')),
  comment text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (selection_id, profile_id, client_key)
);

create index if not exists selection_client_feedback_selection_idx
  on public.selection_client_feedback (selection_id, updated_at desc);

alter table public.selection_client_feedback
  drop constraint if exists selection_client_feedback_vote_check;

update public.selection_client_feedback
set vote = 'selected'
where vote in ('liked', 'like', 'chosen');

alter table public.selection_client_feedback
  add constraint selection_client_feedback_vote_check
  check (vote in ('selected', 'reserve', 'rejected'));

alter table public.selection_client_feedback enable row level security;

drop policy if exists "Selection owners and admins view client feedback"
  on public.selection_client_feedback;

create policy "Selection owners and admins view client feedback"
  on public.selection_client_feedback
  for select
  to authenticated
  using (
    public.current_user_owns_selection(selection_id)
    or public.current_user_is_admin()
  );

drop policy if exists "Public clients can create feedback"
  on public.selection_client_feedback;

create policy "Public clients can create feedback"
  on public.selection_client_feedback
  for insert
  to anon, authenticated
  with check (
    public.selection_is_public(selection_id)
    and length(btrim(client_key)) >= 12
  );

drop policy if exists "Public clients can update feedback"
  on public.selection_client_feedback;

create policy "Public clients can update feedback"
  on public.selection_client_feedback
  for update
  to anon, authenticated
  using (
    public.selection_is_public(selection_id)
    and length(btrim(client_key)) >= 12
  )
  with check (
    public.selection_is_public(selection_id)
    and length(btrim(client_key)) >= 12
  );

create or replace function public.set_selection_public(
  p_selection_id uuid,
  p_is_public boolean
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  update public.selections
  set
    is_public = coalesce(p_is_public, false),
    status = case
      when coalesce(p_is_public, false) and status = 'draft'
        then 'sent_to_client'
      else status
    end
  where id = p_selection_id
    and (
      created_by = auth.uid()
      or public.current_user_is_admin()
    );

  if not found then
    raise exception 'Selection not found or access denied';
  end if;
end;
$$;

grant execute on function public.set_selection_public(uuid, boolean)
  to authenticated;

create or replace function public.save_selection_client_feedback(
  p_selection_id uuid,
  p_profile_id uuid,
  p_client_key text,
  p_vote text default null,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_key text := btrim(coalesce(p_client_key, ''));
  v_vote text := nullif(lower(btrim(coalesce(p_vote, ''))), '');
begin
  if length(v_key) < 12 then
    raise exception 'Client key is required';
  end if;

  if v_vote in ('liked', 'like', 'chosen') then
    v_vote := 'selected';
  end if;

  if v_vote is not null and v_vote not in ('selected', 'reserve', 'rejected') then
    raise exception 'Unsupported vote: %', p_vote;
  end if;

  if not public.selection_is_public(p_selection_id) then
    raise exception 'Selection is not public';
  end if;

  if not exists (
    select 1
    from public.selection_items si
    where si.selection_id = p_selection_id
      and si.profile_id = p_profile_id
  ) then
    raise exception 'Profile is not in this selection';
  end if;

  insert into public.selection_client_feedback (
    selection_id,
    profile_id,
    client_key,
    vote,
    comment,
    updated_at
  )
  values (
    p_selection_id,
    p_profile_id,
    v_key,
    v_vote,
    btrim(coalesce(p_comment, '')),
    now()
  )
  on conflict (selection_id, profile_id, client_key)
  do update set
    vote = excluded.vote,
    comment = excluded.comment,
    updated_at = now();

  if v_vote = 'selected' then
    update public.selections
    set status = 'selected'
    where id = p_selection_id
      and status in ('sent_to_client', 'client_viewed', 'draft', 'rejected');
  elsif v_vote = 'rejected'
    and not exists (
      select 1
      from public.selection_client_feedback f
      where f.selection_id = p_selection_id
        and f.vote in ('selected', 'reserve')
    )
    and (
      select count(*)
      from public.selection_client_feedback f
      where f.selection_id = p_selection_id
        and f.vote = 'rejected'
    ) >= (
      select count(*)
      from public.selection_items si
      where si.selection_id = p_selection_id
    )
  then
    update public.selections
    set status = 'rejected'
    where id = p_selection_id
      and status in ('sent_to_client', 'client_viewed', 'draft');
  end if;
end;
$$;

grant execute on function public.save_selection_client_feedback(
  uuid,
  uuid,
  text,
  text,
  text
) to anon, authenticated;

create or replace function public.get_selection_client_feedback(
  p_selection_id uuid,
  p_client_key text
)
returns table (
  profile_id uuid,
  client_key text,
  vote text,
  comment text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    f.profile_id,
    f.client_key,
    f.vote,
    f.comment,
    f.updated_at
  from public.selection_client_feedback f
  where f.selection_id = p_selection_id
    and f.client_key = btrim(coalesce(p_client_key, ''))
    and public.selection_is_public(p_selection_id)
  order by f.updated_at desc;
$$;

grant execute on function public.get_selection_client_feedback(uuid, text)
  to anon, authenticated;

notify pgrst, 'reload schema';
