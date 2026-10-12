-- Smoke 12.10, batch 2: «Дополнительная информация» on a casting.
alter table public.castings
  add column if not exists extra_info text not null default '';
