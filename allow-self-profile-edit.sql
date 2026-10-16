-- ============================================================
-- NEXUS — allow self-service profile editing (name only)
-- Run this ONCE in Supabase SQL Editor. Safe to re-run.
--
-- Previously only admins could update ANY profile row, which meant a
-- user couldn't even fix a typo in their own name. This opens
-- self-editing, but a trigger guarantees a non-admin can never change
-- their own role or status, no matter what they submit — admins remain
-- the only ones who can promote, demote, block, or unblock anyone.
-- ============================================================

drop policy if exists "profiles_update_admin_only" on public.profiles;
create policy "profiles_update_self_or_admin" on public.profiles
  for update using (id = auth.uid() or public.is_admin());

create or replace function public.enforce_profile_role_status_lock()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    new.role := old.role;
    new.status := old.status;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_lock_role_status on public.profiles;
create trigger profiles_lock_role_status
  before update on public.profiles
  for each row execute procedure public.enforce_profile_role_status_lock();
