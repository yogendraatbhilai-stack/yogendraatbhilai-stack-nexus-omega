-- ============================================================
-- NEXUS — fix stored tool paths for the flat file structure
-- Run this ONCE in Supabase SQL Editor if you previously set up
-- Nexus before the flat-file switch. Safe to re-run.
-- ============================================================
update public.tools set path = 'retirement-planner.html' where key = 'retirement_planner';
update public.tools set path = 'cba-tool.html' where key = 'cba_tool';
update public.tools set path = 'table-performance.html' where key = 'table_performance_manager';
update public.tools set path = 'event-sop.html' where key = 'event_sop';
