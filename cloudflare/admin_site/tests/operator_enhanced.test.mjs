import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const app=readFileSync(new URL('../site/app.mjs',import.meta.url),'utf8');
const html=readFileSync(new URL('../site/index.html',import.meta.url),'utf8');
const css=readFileSync(new URL('../site/styles.css',import.meta.url),'utf8');

test('operator command center routes to real dashboard sections and never mocks production counts',()=>{
 for(const page of ['moderation','finance','members','audit'])
  assert.ok(html.includes('data-quick-nav="'+page+'"'));
 for(const id of ['metric-posts','metric-earn','metric-reports','metric-mods','metric-grants','metric-members'])
  assert.ok(html.includes('id="'+id+'"'));
 assert.match(app,/function loadDashboardWorkload\(/);
 assert.match(app,/Promise\.allSettled\(checks\.map/);
 assert.match(app,/api\(type,body\)/);
});
test('searchable owner-only grant and financial audit records',()=>{
 assert.ok(html.includes('id="finance-filter"'));
 assert.ok(html.includes('id="audit-filter"'));
 assert.match(app,/function renderFinanceRows\(/);
 assert.match(app,/function renderAuditRows\(/);
 assert.match(app,/function searchableText\(/);
 assert.match(app,/recipient_email/);
 assert.match(app,/actor_email/);
 assert.match(app,/grant_expires_at|expires_at/);
});
test('full financial IDs are accessible and copyable rather than permanently truncated',()=>{
 assert.match(app,/function identifier\(/);
 assert.match(app,/navigator\.clipboard\.writeText\(value\)/);
 assert.match(app,/function renderAuditRows\(/);
 assert.match(app,/function renderFinanceRows\(/);
 assert.match(css,/\.complete-id/);
});
test('owner-only operations are real wired form actions, never cosmetic buttons',()=>{
 for(const op of ['moderators.add','members.suspend','coach.reset.all','coach.reset.user','notifications.send'])
   assert.ok(app.includes("makeOpsForm(") && app.includes("'"+op+"'"),op);
 assert.match(app,/function opsConfirm\(/);
 assert.match(app,/async function transaction\(/);
 assert.match(app,/showStepUp\(\)/);
});
test('global token gifts need exact typed effect confirmation and fresh TOTP',()=>{
 assert.match(html,/id="mass-grant-confirmation"/);
 assert.match(app,/GRANT 2500 AI TOKENS TO ALL USERS/);
 assert.match(app,/confirm_mass_grant/);
 assert.match(app,/name.*acknowledge_token_grant|acknowledge_token_grant/);
 assert.match(app,/function actionConfirmation\(/);
});
test('clear localized status and help, no raw user IDs exposed without owner sign-in',()=>{
 for(const k of ['operatorModeActive','compMassWarning','quickModeration','quickGrants','noMatchingSearch'])
  assert.match(app,new RegExp(k));
 assert.match(app,/function clearPrivateView\(/);
 assert.doesNotMatch(app,/service_role|SUPABASE_SERVICE_ROLE_KEY|sb_secret_/i);
 assert.match(html,/id="auth-view"/);
 assert.match(html,/id="admin-view" hidden/);
});
test('mobile navigation remains dismissable from outside and scrolling has no page overflow',()=>{
 assert.match(html,/id="sidebar-scrim"/);
 assert.match(html,/id="sidebar-close"/);
 assert.match(app,/function closeSidebar\(/);
 assert.match(app,/document\.addEventListener\('pointerdown'/);
 assert.match(app,/event\.key==='Escape'/);
 assert.match(css,/overflow-x:clip/);
 assert.match(css,/@media\(max-width:440px\)/);
});
test('review decisions still require media and versioned backend receipts',()=>{
 assert.match(app,/media_complete!==true/);
 assert.match(app,/expected_revision/);
 assert.match(app,/acknowledge_full_content/);
 assert.match(app,/require.*TOTP|showStepUp\(/);
 assert.match(app,/button\.dataset\.caseEligible='false'/);
});