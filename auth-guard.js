/* =========================================================
   NEXUS — auth guard & shared helpers
   Include AFTER supabase-client.js on every protected page.
   ========================================================= */

function nexusToast(msg, kind){
  const el = document.createElement('div');
  el.className = 'toast' + (kind ? ' ' + kind : '');
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(()=> el.remove(), 4200);
}

// Ensures the visitor is logged in AND not blocked.
// Redirects to login.html otherwise. Returns {session, profile}.
async function nexusRequireAuth(){
  const { data: { session } } = await nexus.auth.getSession();
  if (!session){
    window.location.href = 'login.html';
    return null;
  }
  const { data: profile, error } = await nexus
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .single();

  if (error || !profile){
    nexusToast('Could not load your profile. Please sign in again.', 'err');
    await nexus.auth.signOut();
    window.location.href = 'login.html';
    return null;
  }
  if (profile.status === 'blocked'){
    nexusToast('Your account has been blocked by an admin. Contact your admin.', 'err');
    await nexusLogEvent(profile, 'blocked_login_attempt', {});
    await nexus.auth.signOut();
    window.location.href = 'login.html?blocked=1';
    return null;
  }
  if (profile.status === 'pending'){
    nexusToast('Your account is awaiting admin approval. You\'ll be able to sign in once approved.', 'err');
    await nexusLogEvent(profile, 'pending_login_attempt', {});
    await nexus.auth.signOut();
    window.location.href = 'login.html?pending=1';
    return null;
  }
  return { session, profile };
}

// Admin-only pages call this instead.
async function nexusRequireAdmin(){
  const ctx = await nexusRequireAuth();
  if (!ctx) return null;
  if (ctx.profile.role !== 'admin'){
    document.body.innerHTML = '<div class="center-screen"><div class="card auth-card"><h2>Restricted</h2><p class="muted">This area is for Nexus admins only.</p><a class="btn btn-outline" href="dashboard.html">Back to dashboard</a></div></div>';
    return null;
  }
  return ctx;
}

async function nexusSignOut(){
  await nexus.auth.signOut();
  window.location.href = 'login.html';
}

// Fetch which sections/tools this user (or admin, who sees all) can open.
async function nexusGetCatalogue(profile){
  const { data: sections } = await nexus.from('sections').select('*').order('sort_order');
  const { data: tools } = await nexus.from('tools').select('*').order('sort_order');

  if (profile.role === 'admin'){
    return { sections: sections || [], tools: tools || [], sectionAccess: {}, toolAccess: {}, isAdmin: true };
  }

  const { data: secAccessRows } = await nexus
    .from('user_section_access').select('*').eq('user_id', profile.id);
  const { data: toolAccessRows } = await nexus
    .from('user_tool_access').select('*').eq('user_id', profile.id);

  const sectionAccess = {};
  (secAccessRows || []).forEach(r => sectionAccess[r.section_id] = r.allowed);
  const toolAccess = {};
  (toolAccessRows || []).forEach(r => toolAccess[r.tool_id] = r.allowed);

  return { sections: sections || [], tools: tools || [], sectionAccess, toolAccess, isAdmin: false };
}

// Default-allow: if no explicit row exists for a user, access is allowed.
// This matches "restrict access" being an admin action, not opt-in.
function nexusCanSeeSection(cat, sectionId){
  if (cat.isAdmin) return true;
  return cat.sectionAccess[sectionId] !== false;
}
function nexusCanSeeTool(cat, toolId){
  if (cat.isAdmin) return true;
  return cat.toolAccess[toolId] !== false;
}

function nexusInitials(name, email){
  const src = (name && name.trim()) || (email || '');
  return src.split(/[\s@.]+/).filter(Boolean).slice(0,2).map(s=>s[0].toUpperCase()).join('');
}

// Writes one permanent line to the audit log. Available on every page
// (not just tool pages) — pass the profile object you already have in
// hand to avoid an extra database round trip. Best-effort: a logging
// failure never blocks the action the person is actually trying to do.
async function nexusLogEvent(profile, eventType, details){
  try{
    await nexus.from('audit_log').insert({
      user_id: profile.id,
      user_name: profile.full_name || profile.email,
      event_type: eventType,
      details: details || {}
    });
  }catch(e){
    console.warn('Nexus audit log write failed (non-blocking):', e.message);
  }
}

/* =========================================================
   Digital IP / non-compete declaration
   ========================================================= */
const NEXUS_DECLARATION_VERSION = 'v1';
const NEXUS_DECLARATION_TEXT = `I confirm that:
1. All clients serviced through Nexus belong to Omega Financial.
2. All reports, calculators, portfolios, and methodologies inside Nexus are Omega Financial's intellectual property.
3. I shall not use this system for any personal ARN or on behalf of any external distributor.
4. I shall not share client data, investment recommendations, or any proprietary methodology outside Omega Financial.
5. I understand that violation of the above may result in disciplinary and legal action.`;

// Has this person already accepted the current version of the declaration?
async function nexusHasAcceptedDeclaration(profile){
  const { data } = await nexus
    .from('user_declarations')
    .select('user_id')
    .eq('user_id', profile.id)
    .eq('version', NEXUS_DECLARATION_VERSION)
    .maybeSingle();
  return !!data;
}

// Records acceptance permanently (best-effort IP lookup — never blocks
// on it if the lookup fails or is blocked by the browser/network).
async function nexusRecordDeclarationAcceptance(profile){
  let ip = null;
  try{
    const res = await fetch('https://api.ipify.org?format=json');
    if (res.ok){ ip = (await res.json()).ip || null; }
  }catch(e){ /* non-blocking — some networks/ad-blockers block this, that's fine */ }

  const { error } = await nexus.from('user_declarations').insert({
    user_id: profile.id,
    version: NEXUS_DECLARATION_VERSION,
    ip
  });
  if (error) throw error;
  await nexusLogEvent(profile, 'declaration_accepted', { version: NEXUS_DECLARATION_VERSION });
}

// Blocks the page behind a full-screen mandatory declaration until the
// person accepts it. Call this AFTER nexusRequireAuth() on any page that
// should enforce it (dashboard, section, admin). Resolves once accepted
// (or immediately if already accepted before).
async function nexusEnsureDeclaration(profile){
  const already = await nexusHasAcceptedDeclaration(profile);
  if (already) return;

  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(8,26,48,.92);z-index:999999;display:flex;align-items:center;justify-content:center;padding:24px;';
    overlay.innerHTML = `
      <div style="background:#fff;border-radius:16px;max-width:560px;width:100%;padding:32px;max-height:86vh;overflow:auto;">
        <h2 style="margin:0 0 6px;color:#0E2A47;font-family:'Fraunces',serif;">Before you continue</h2>
        <p style="color:#4d5c68;font-size:13.5px;margin:0 0 18px;">Please read and accept this declaration to use Nexus.</p>
        <div style="background:#F6F4EE;border-radius:10px;padding:16px;font-size:13px;color:#10202F;white-space:pre-line;line-height:1.6;margin-bottom:18px;">${NEXUS_DECLARATION_TEXT}</div>
        <label style="display:flex;gap:10px;align-items:flex-start;font-size:13px;color:#10202F;margin-bottom:20px;cursor:pointer;">
          <input type="checkbox" id="nexusDeclareCheck" style="margin-top:3px;width:16px;height:16px;flex-shrink:0;">
          <span>I have read and agree to the above declaration.</span>
        </label>
        <button id="nexusDeclareBtn" disabled style="width:100%;padding:13px;border:none;border-radius:10px;background:#cfd6dc;color:#fff;font-weight:600;font-size:15px;cursor:not-allowed;">I Agree &amp; Continue</button>
      </div>
    `;
    document.body.appendChild(overlay);

    const checkbox = overlay.querySelector('#nexusDeclareCheck');
    const btn = overlay.querySelector('#nexusDeclareBtn');
    checkbox.addEventListener('change', () => {
      btn.disabled = !checkbox.checked;
      btn.style.background = checkbox.checked ? '#0E2A47' : '#cfd6dc';
      btn.style.cursor = checkbox.checked ? 'pointer' : 'not-allowed';
    });
    btn.addEventListener('click', async () => {
      if (!checkbox.checked) return;
      btn.textContent = 'Saving…';
      btn.disabled = true;
      try{
        await nexusRecordDeclarationAcceptance(profile);
        document.body.removeChild(overlay);
        resolve();
      }catch(e){
        nexusToast('Could not record your acceptance: ' + e.message, 'err');
        btn.textContent = 'I Agree & Continue';
        btn.disabled = false;
      }
    });
  });
}
