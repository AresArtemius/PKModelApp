alter table public.profiles
  add column if not exists photo_category_labels text[] not null default '{}',
  add column if not exists video_category_labels text[] not null default '{}',
  add column if not exists pending_photo_category_labels text[] not null default '{}',
  add column if not exists pending_video_category_labels text[] not null default '{}',
  add column if not exists showreel_url text not null default '',
  add column if not exists showreel_preview_url text not null default '',
  add column if not exists pending_showreel_url text not null default '',
  add column if not exists pending_showreel_preview_url text not null default '';

update public.profiles
set
  photo_category_labels = case
    when coalesce(array_length(photo_category_labels, 1), 0) = coalesce(array_length(photo_urls, 1), 0)
      then photo_category_labels
    else array_fill('Портфолио'::text, array[coalesce(array_length(photo_urls, 1), 0)])
  end,
  video_category_labels = case
    when coalesce(array_length(video_category_labels, 1), 0) = coalesce(array_length(video_urls, 1), 0)
      then video_category_labels
    else array_fill('Видео'::text, array[coalesce(array_length(video_urls, 1), 0)])
  end,
  pending_photo_category_labels = case
    when coalesce(array_length(pending_photo_category_labels, 1), 0) = coalesce(array_length(pending_photo_urls, 1), 0)
      then pending_photo_category_labels
    else array_fill('Портфолио'::text, array[coalesce(array_length(pending_photo_urls, 1), 0)])
  end,
  pending_video_category_labels = case
    when coalesce(array_length(pending_video_category_labels, 1), 0) = coalesce(array_length(pending_video_urls, 1), 0)
      then pending_video_category_labels
    else array_fill('Видео'::text, array[coalesce(array_length(pending_video_urls, 1), 0)])
  end;
