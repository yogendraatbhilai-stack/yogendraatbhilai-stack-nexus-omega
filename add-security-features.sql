-- ============================================================
-- NEXUS — Security additions: audit log + digital IP declaration
-- Run this ONCE in Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- ---------- Audit log: permanent, append-only event history ----------
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id),
  user_name text,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.audit_log enable row level security;

-- Any active, logged-in person can write their own events (login, report
-- saved, etc). Admin actions (blocking a user, changing permissions) are
-- written under the admin's own id.
drop policy if exists "audit_insert_self" on public.audit_log;
create policy "audit_insert_self" on public.audit_log
  for insert with check (user_id = auth.uid());

-- Only admins can ever read the log.
drop policy if exists "audit_select_admin_only" on public.audit_log;
create policy "audit_select_admin_only" on public.audit_log
  for select using (public.is_admin());

-- No update/delete policy exists for anyone (including admins) — once
-- written, a log entry can never be edited or removed by design.

-- ---------- Digital IP / non-compete declaration ----------
-- One row per person per declaration text version. If the wording ever
-- changes, bump the version string in dashboard.html and everyone will
-- be asked to accept the new version — their acceptance of the old one
-- stays on record permanently underneath it.
create table if not exists public.user_declarations (
  user_id uuid references public.profiles(id) on delete cascade,
  version text not null default 'v1',
  accepted_at timestamptz not null default now(),
  ip text,
  primary key (user_id, version)
);

alter table public.user_declarations enable row level security;

drop policy if exists "decl_select_self_or_admin" on public.user_declarations;
create policy "decl_select_self_or_admin" on public.user_declarations
  for select using (user_id = auth.uid() or public.is_admin());

drop policy if exists "decl_insert_self" on public.user_declarations;
create policy "decl_insert_self" on public.user_declarations
  for insert with check (user_id = auth.uid());

-- No update/delete — once accepted, it's a permanent record.
