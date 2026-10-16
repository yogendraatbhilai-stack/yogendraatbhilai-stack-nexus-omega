# Nexus by Omega Financial — deployment guide

This folder is a complete, working website. No build tools, no npm, no
server code to run — it's plain HTML/CSS/JS that talks directly to
Supabase (your free database + login system). Follow these steps in
order.

## Part 1 — Create your Supabase project (5 minutes)

1. Go to https://supabase.com and sign up (free, no card needed).
2. Click **New project**. Name it `nexus-omega`, choose any region close
   to India (e.g. Singapore), set a database password (save it somewhere safe).
3. Wait ~2 minutes for the project to finish provisioning.
4. In the left sidebar, open **SQL Editor** → **New query**.
5. Open `supabase/schema.sql` from this folder, copy its entire contents,
   paste into the SQL editor, and click **Run**. This creates every table,
   security rule, and the "reports" file storage bucket.
6. In the left sidebar, open **Project Settings → API**. You'll see:
   - **Project URL** (looks like `https://xxxxx.supabase.co`)
   - **anon public** key (a long string)
7. Open `js/supabase-client.js` in this folder and paste those two values
   in place of `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_ANON_PUBLIC_KEY`.
8. Optional but recommended: In **Authentication → Providers**, confirm
   "Email" is enabled. In **Authentication → URL Configuration**, once you
   know your live site address (Part 2), add it as a **Redirect URL** so
   password-reset links work — e.g. `https://yourname.github.io/nexus/update-password.html`.

## Part 2 — Put the code on GitHub and go live (5 minutes)

1. Create a free GitHub account at https://github.com if you don't have one.
2. Create a new repository, e.g. named `nexus`. Keep it **Public** (needed
   for free GitHub Pages) — this is fine, since nobody can read your data
   without a Nexus login; the anon key only unlocks what Row Level Security
   allows.
3. Upload every file and folder from this package into that repository
   (drag-and-drop works on github.com — click **Add file → Upload files**).
4. In the repository, go to **Settings → Pages**. Under "Build and
   deployment", set **Source: Deploy from a branch**, **Branch: main**,
   folder **/(root)**. Click **Save**.
5. Wait a minute, then GitHub shows your live link, e.g.
   `https://yourname.github.io/nexus/`. That is Nexus's public web address —
   share it with your team.

## Part 3 — Create the two admin accounts

1. Open your live link, click **Sign in → Create an account**.
2. Sign up once with `yogendra.singh@omegafinancial.co.in` and once with
   `augustine.john@omegafinancial.co.in`. Both are automatically made
   admins by the database script you ran in Part 1 — no extra step needed.
3. Everyone else who signs up gets a normal "user" account with default
   access to every section, until an admin restricts it from the
   **Admin panel → Permissions** tab.

## Updating an already-deployed Nexus (block = fully locked out, Aug 2026)

If you already set up Supabase before this update, run the schema script
once more so the stronger lockout rules take effect:

1. Supabase → **SQL Editor** → **New query**
2. Paste in the *whole* `supabase/schema.sql` (not just a snippet) and
   click **Run** — it's safe to re-run any time, it only updates rules
   and never duplicates your existing sections, tools, or data
3. Re-upload the refreshed website files to your GitHub repo

**What changed:** blocking a user in the admin panel now cuts them off
immediately and completely — even if their browser still has a signed-in
session open, every read from the database (sections, tools, reports,
anything) is refused the instant their account is set to blocked, not
just the next time they happen to reload a page. Only your two admin
accounts can block, unblock, promote, or demote anyone — no other login
has that power, by design (enforced in the database itself, not just
hidden in the interface).

## Updating an already-deployed Nexus (HR section removed, Aug 2026)

If you already ran the original `schema.sql` and set up Supabase before this
update, run one more script to remove the Human Resource section (it's
been taken out of Nexus, along with the Hiring tool):

1. Supabase → **SQL Editor** → **New query**
2. Paste in `supabase/remove-hr-section.sql` and click **Run**
3. Re-upload the refreshed website files to your GitHub repo (they now
   only show Sales and Customer Awareness, and every section has its own
   **View saved reports** button)

## What's already working

- Landing page → Sign in / Create account → forgot/reset password
- Dashboard showing your two sections (Sales, Customer Awareness), each
  filtered to what the signed-in user is allowed to open
- **Every section now has its own "View saved reports" library** — open
  a section, click the gold button, and see every report saved from tools
  in that section, with one-click branded PDF download for sending to
  clients or keeping for internal records
- Admin panel: **Users** (promote/demote admin, block/unblock),
  **Permissions** (turn any section or individual tool on/off per user),
  **Reports** (every saved report across the whole company, with PDF
  preview and delete — delete is admin-only by design)
- **Event SOP Governance** tool is fully wired: fill it in, click
  **Save to Nexus**, and it writes a permanent report row plus a stored
  PDF that shows up instantly in both the section's Reports library and
  the admin Reports tab. The PDF now lists **every single checklist item**
  — ticked or blank — under each section, not just percentages, so a
  proper stage-by-stage analysis is possible. The section's Reports page
  also lets you expand each report inline to see the full checklist
  without downloading anything. Ordinary users cannot edit or delete a
  report once saved — only an admin can.
- **Retirement Planner, CBA Tool, and Table Performance Manager** are now
  also fully wired with their own **Save to Nexus** buttons — each saves
  a locked, permanent, Omega-branded PDF report straight into its
  section's Reports library and the admin Reports tab.

## Folder map

```
index.html              landing page
login.html               sign in / sign up
reset-password.html      request a password reset email
update-password.html     set a new password (opens from the emailed link)
dashboard.html            the 3 sections, filtered by permission
sections/section.html    generic "tools inside this section" page
admin/index.html         admin panel (Users / Permissions / Reports)
tools/event-sop.html     Event SOP tool — fully wired to Nexus
tools/retirement-planner.html   access-gated, save-to-Nexus pending
tools/cba-tool.html      access-gated, save-to-Nexus pending
tools/table-performance.html    Table Performance Manager — access-gated, save-to-Nexus pending
css/nexus.css            shared styling
js/supabase-client.js    your project keys live here (edit this first)
js/auth-guard.js         login checks + permission helpers, used on every page
js/nexus-bridge.js       saveReport() / exportBrandedPDF() used inside tools
supabase/schema.sql      run this once inside Supabase
```

## Cost

Everything here fits inside Supabase's free tier (500MB database, 1GB file
storage, 50,000 monthly active users) and GitHub Pages' free tier. There is
no card, subscription, or usage charge for a sales team of this size.
