-- ============================================================
-- NEXUS — add client_contact to reports (for the Analysis tab's
-- client list). Run this ONCE in Supabase SQL Editor. Safe to re-run.
-- ============================================================
alter table public.reports add column if not exists client_contact text;
