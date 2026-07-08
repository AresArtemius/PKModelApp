-- Reference media for castings.
-- Run in Supabase SQL Editor or via `supabase db query`.

alter table public.castings
  add column if not exists reference_media jsonb not null default '[]'::jsonb;

update public.castings
set reference_media = '[]'::jsonb
where reference_media is null;

alter table public.castings
  drop constraint if exists castings_reference_media_array_chk;

alter table public.castings
  add constraint castings_reference_media_array_chk
  check (jsonb_typeof(reference_media) = 'array');

create or replace function public.set_casting_reference_media(
  p_casting_id uuid,
  p_reference_media jsonb
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can update casting references';
  end if;

  if jsonb_typeof(coalesce(p_reference_media, '[]'::jsonb)) <> 'array' then
    raise exception 'Reference media must be a JSON array';
  end if;

  update public.castings
  set reference_media = coalesce(p_reference_media, '[]'::jsonb)
  where id = p_casting_id;

  if not found then
    raise exception 'Casting not found';
  end if;
end;
$$;

grant execute on function public.set_casting_reference_media(uuid, jsonb)
  to authenticated;
