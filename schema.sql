-- ============================================================
-- NEXUS by Omega Financial — Supabase schema
-- Run this once in Supabase: Project -> SQL Editor -> New query -> paste -> Run
-- ============================================================

-- ---------- 0. Bootstrap admins ----------
-- Anyone who signs up with one of these two emails is auto-promoted to admin.
-- Add more later by editing the profiles table directly.
create table if not exists public.bootstrap_admins (
  email text primary key
);
insert into public.bootstrap_admins (email) values
  ('yogendra.singh@omegafinancial.co.in'),
  ('augustine.john@omegafinancial.co.in')
on conflict do nothing;

-- ---------- 1. Profiles (one row per logged-in person) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  role text not null default 'user' check (role in ('admin','user')),
  status text not null default 'active' check (status in ('active','blocked','pending')),
  created_at timestamptz not null default now()
);

-- Auto-create a profile row whenever someone signs up
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

  -- Every new sign-up starts locked out (status 'pending'), regardless of
  -- what email address they registered with. Only an admin — flipping
  -- them to "active" from the Admin panel's Users tab — can let them in.
  -- This keeps onboarding entirely under admin control without depending
  -- on any email service to route a confirmation to a specific inbox
  -- (Supabase's built-in confirmation can only ever email the person who
  -- signed up, never a third party, so this is done at the database
  -- level instead). Bootstrap admin emails skip this and start active.
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

  -- New non-admin users don't get Retirement Planner or CBA Tool by
  -- default — an admin has to explicitly switch these on for them from
  -- the Permissions tab. Every other tool keeps the existing
  -- default-allow behaviour (accessible unless an admin restricts it).
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Helper: is the current logged-in user an admin?
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'
  );
$$;

-- Helper: is the current logged-in user active (not blocked)?
-- Used everywhere a blocked account must be shut out of real data,
-- even if their browser still has a valid, unexpired login session.
create or replace function public.is_active()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.status = 'active'
  );
$$;

-- ---------- 2. Sections & Tools (the catalogue) ----------
create table if not exists public.sections (
  id serial primary key,
  key text unique not null,
  name text not null,
  description text,
  icon text,
  sort_order int default 0
);

create table if not exists public.tools (
  id serial primary key,
  section_id int references public.sections(id) on delete cascade,
  key text unique not null,
  name text not null,
  description text,
  path text not null,           -- relative page path, e.g. tools/event-sop.html
  sort_order int default 0
);

insert into public.sections (key, name, description, icon, sort_order) values
  ('sales', 'Sales', 'Client-facing planning & calculation tools', 'trending-up', 1),
  ('customer_awareness', 'Customer Awareness', 'Investor engagement & event governance', 'megaphone', 2),
  ('iap', 'Investor Awareness Program (IAP)', 'Investor Awareness Programme proposal letters for organisations', 'megaphone', 3)
on conflict (key) do nothing;

insert into public.tools (section_id, key, name, description, path, sort_order)
select s.id, v.key, v.name, v.description, v.path, v.sort_order
from (values
  ('retirement_planner','Retirement Planner','Retirement corpus & income planning calculator','retirement-planner.html','sales',1),
  ('cba_tool','Client CBA Tool','Cost benefit analysis & 7-step financial planning flow','cba-tool.html','sales',2),
  ('table_performance_manager','Table Performance Manager','Monthly rotational sales leadership leaderboard, weekly Table Leaders, Table Mentor & recognitions','table-performance.html','sales',3),
  ('event_sop','Event SOP Governance','Investor engagement program SOP checklist & scoring','event-sop.html','customer_awareness',1),
  ('iap_proposal','IAP Proposal Builder','Investor Awareness Programme proposal letter builder for organisations/companies','iap-proposal.html','iap',1)
) as v(key,name,description,path,section_key,sort_order)
join public.sections s on s.key = v.section_key
on conflict (key) do nothing;

-- ---------- 3. Access control ----------
create table if not exists public.user_section_access (
  user_id uuid references public.profiles(id) on delete cascade,
  section_id int references public.sections(id) on delete cascade,
  allowed boolean not null default true,
  primary key (user_id, section_id)
);

create table if not exists public.user_tool_access (
  user_id uuid references public.profiles(id) on delete cascade,
  tool_id int references public.tools(id) on delete cascade,
  allowed boolean not null default true,
  primary key (user_id, tool_id)
);

-- ---------- 4. Reports (immutable once saved, except by admin) ----------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  tool_key text not null,
  section_key text not null,
  client_name text,
  client_contact text,
  summary text,
  created_by uuid references public.profiles(id),
  created_by_name text,
  data jsonb not null default '{}'::jsonb,
  pdf_path text,                -- storage path in the 'reports' bucket
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  updated_by uuid references public.profiles(id)
);

-- ---------- 5. Row Level Security ----------
alter table public.profiles enable row level security;
alter table public.sections enable row level security;
alter table public.tools enable row level security;
alter table public.user_section_access enable row level security;
alter table public.user_tool_access enable row level security;
alter table public.reports enable row level security;

-- profiles
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin" on public.profiles
  for select using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles_update_admin_only" on public.profiles;
drop policy if exists "profiles_update_self_or_admin" on public.profiles;
create policy "profiles_update_self_or_admin" on public.profiles
  for update using (id = auth.uid() or public.is_admin());

-- A non-admin can update their own row (e.g. their display name), but
-- can never change their own role or status this way — this trigger
-- silently restores whatever an admin last set, no matter what a
-- self-update submits, closing off any self-escalation route.
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

-- sections / tools: everyone logged in AND ACTIVE can read the catalogue.
-- A blocked account's read is refused here even if their browser session
-- is still technically valid — this is what makes a block immediate and
-- total, not just "kicked out on next page load".
drop policy if exists "sections_read_all" on public.sections;
create policy "sections_read_all" on public.sections
  for select using (public.is_active() or public.is_admin());
drop policy if exists "sections_write_admin" on public.sections;
create policy "sections_write_admin" on public.sections for all using (public.is_admin());

drop policy if exists "tools_read_all" on public.tools;
create policy "tools_read_all" on public.tools
  for select using (public.is_active() or public.is_admin());
drop policy if exists "tools_write_admin" on public.tools;
create policy "tools_write_admin" on public.tools for all using (public.is_admin());

-- access tables: an active user sees their own rows; admin sees/edits everything
drop policy if exists "sec_access_select" on public.user_section_access;
create policy "sec_access_select" on public.user_section_access
  for select using ((user_id = auth.uid() and public.is_active()) or public.is_admin());
drop policy if exists "sec_access_write_admin" on public.user_section_access;
create policy "sec_access_write_admin" on public.user_section_access
  for all using (public.is_admin());

drop policy if exists "tool_access_select" on public.user_tool_access;
create policy "tool_access_select" on public.user_tool_access
  for select using ((user_id = auth.uid() and public.is_active()) or public.is_admin());
drop policy if exists "tool_access_write_admin" on public.user_tool_access;
create policy "tool_access_write_admin" on public.user_tool_access
  for all using (public.is_admin());

-- reports: any active user can insert their own; active users read their
-- own; admin reads/updates/deletes all, always, regardless of status
drop policy if exists "reports_insert_self" on public.reports;
create policy "reports_insert_self" on public.reports
  for insert with check (created_by = auth.uid() and public.is_active());

drop policy if exists "reports_select_own_or_admin" on public.reports;
create policy "reports_select_own_or_admin" on public.reports
  for select using ((created_by = auth.uid() and public.is_active()) or public.is_admin());

-- IMPORTANT: only admins may update or delete a saved report (immutability rule)
drop policy if exists "reports_update_admin_only" on public.reports;
create policy "reports_update_admin_only" on public.reports
  for update using (public.is_admin());

drop policy if exists "reports_delete_admin_only" on public.reports;
create policy "reports_delete_admin_only" on public.reports
  for delete using (public.is_admin());

-- ---------- 6. Storage bucket for report PDFs ----------
insert into storage.buckets (id, name, public)
values ('reports', 'reports', false)
on conflict (id) do nothing;

drop policy if exists "reports_bucket_insert" on storage.objects;
create policy "reports_bucket_insert" on storage.objects
  for insert with check (bucket_id = 'reports' and public.is_active());

drop policy if exists "reports_bucket_select" on storage.objects;
create policy "reports_bucket_select" on storage.objects
  for select using (
    bucket_id = 'reports' and ((owner = auth.uid() and public.is_active()) or public.is_admin())
  );

drop policy if exists "reports_bucket_admin_manage" on storage.objects;
create policy "reports_bucket_admin_manage" on storage.objects
  for all using (bucket_id = 'reports' and public.is_admin());

-- ============================================================
-- Done. Next: create your own login in the app (Sign up screen)
-- using yogendra.singh@omegafinancial.co.in or
-- augustine.john@omegafinancial.co.in to get admin rights automatically.
-- ============================================================
