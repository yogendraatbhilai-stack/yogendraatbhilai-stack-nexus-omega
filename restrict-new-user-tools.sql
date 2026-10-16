-- ============================================================
-- NEXUS — new users start WITHOUT access to Retirement Planner and
-- CBA Tool by default; an admin must explicitly grant it from the
-- Permissions tab. Run this ONCE in Supabase SQL Editor. Safe to re-run.
--
-- This only changes what happens for people who sign up FROM NOW ON.
-- It does not touch anyone who already has an account — if you also
-- want to restrict existing non-admin users, see the optional section
-- at the bottom of this file.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  new_role text;
begin
  new_role := case when exists (select 1 from public.bootstrap_admins b where lower(b.email) = lower(new.email))
         then 'admin' else 'user' end;

  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    new_role
  )
  on conflict (id) do nothing;

  if new_role <> 'admin' then
    insert into public.user_tool_access (user_id, tool_id, allowed)
    select new.id, t.id, false
    from public.tools t
    where t.key in ('retirement_planner', 'cba_tool')
    on conflict (user_id, tool_id) do nothing;
  end if;

  return new;
end;
$$;

-- ------------------------------------------------------------
-- OPTIONAL: uncomment and run this block too if you also want every
-- EXISTING non-admin user's access to these two tools revoked right
-- now (rather than only new sign-ups going forward).
-- ------------------------------------------------------------
-- insert into public.user_tool_access (user_id, tool_id, allowed)
-- select p.id, t.id, false
-- from public.profiles p
-- cross join public.tools t
-- where p.role <> 'admin'
--   and t.key in ('retirement_planner', 'cba_tool')
-- on conflict (user_id, tool_id) do update set allowed = false;
