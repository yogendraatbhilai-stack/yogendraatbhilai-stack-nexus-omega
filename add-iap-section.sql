-- ============================================================
-- NEXUS — add the "Investor Awareness Program (IAP)" section and
-- its "IAP Proposal Builder" tool to the catalogue. Run this ONCE
-- in Supabase SQL Editor. Safe to re-run (on conflict do nothing).
--
-- No access-control rows are inserted for existing users, which
-- means this new section/tool is visible to everyone by default —
-- same as Table Performance Manager and Event SOP. If you want to
-- restrict it for specific users, do that afterwards from
-- Admin → Permissions, same as any other tool.
-- ============================================================

insert into public.sections (key, name, description, icon, sort_order) values
  ('iap', 'Investor Awareness Program (IAP)', 'Investor Awareness Programme proposal letters for organisations', 'megaphone', 3)
on conflict (key) do nothing;

insert into public.tools (section_id, key, name, description, path, sort_order)
select s.id, v.key, v.name, v.description, v.path, v.sort_order
from (values
  ('iap_proposal','IAP Proposal Builder','Investor Awareness Programme proposal letter builder for organisations/companies','iap-proposal.html',1)
) as v(key,name,description,path,sort_order)
join public.sections s on s.key = 'iap'
on conflict (key) do nothing;
