-- ============================================================
-- NEXUS — new sign-ups now start locked ("pending") and can only
-- sign in once an admin approves them from the Admin panel's Users
-- tab. Run this ONCE in Supabase SQL Editor. Safe to re-run.
--
-- Why not route the confirmation email to a specific admin instead?
-- Supabase's built-in confirmation system can only ever email the
-- address that signed up — there's no way to redirect it to a third
-- party's inbox without a custom backend service, and we've already
-- had reliability trouble with email delivery generally. Gating
-- access at the database level, controlled entirely from the Admin
-- panel, achieves the same "nobody gets in without Yogendra's
-- say-so" goal without depending on any email service at all.
-- ============================================================

alter table public.profiles drop constraint if exists profiles_status_check;
alter table public.profiles add constraint profiles_status_check
  check (status in ('active','blocked','pending'));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  new_role text;
  new_status text;
begin
  new_role := case when exists (select 1 from public.bootstrap_admins b where lower(b.email) = lower(new.email))
         then 'admin' else 'user' end;

  new_status := case when new_role = 'admin' then 'active' else 'pending' end;

  insert into public.profiles (id, email, full_name, role, status)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    new_role,
    new_status
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
