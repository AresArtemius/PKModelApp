-- Optional cleanup after removing user-requested verification from the app flow.
-- Moderation remains the main gate before a profile appears in the catalog.

update public.profiles
set verification_status = 'none',
    verification_requested_at = null
where verification_status = 'pending'
  and coalesce(is_verified, false) = false;

notify pgrst, 'reload schema';
