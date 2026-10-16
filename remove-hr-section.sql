-- ============================================================
-- NEXUS — remove the Human Resource section
-- Run this ONCE in Supabase SQL Editor. Safe: cascades automatically
-- remove the Hiring tool and any permission rows tied to it, because
-- the tables were built with "on delete cascade".
-- ============================================================
delete from public.sections where key = 'hr';

-- (Optional) re-number Sales/Customer Awareness so Sales shows first
update public.sections set sort_order = 1 where key = 'sales';
update public.sections set sort_order = 2 where key = 'customer_awareness';
