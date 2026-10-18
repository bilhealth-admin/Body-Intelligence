"""Browser E2E with synthetic in-memory Supabase; never touches Production."""
from pathlib import Path
import os, json, re, shutil
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[3]
site = root/'cloudflare'/'admin_site'/'site'
app = (site/'app.mjs').read_text()
html = (site/'index.html').read_text()
css = (site/'styles.css').read_text()
imports = "import { createClient } from '@supabase/supabase-js';\nimport { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from './config.mjs';\n"
assert app.startswith(imports), 'Unexpected Auth bootstrap; abort synthetic testing'
assert '<script type="module" src="./app.bundle.js"></script>' in html
html = html.replace('<link rel="stylesheet" href="./styles.css">','<style>'+css+'</style>').replace('<script type="module" src="./app.bundle.js"></script>','')
mockAuth = """
const SUPABASE_URL='https://synthetic.invalid',SUPABASE_PUBLISHABLE_KEY='sb_publishable_synthetic';
const createClient=()=>({auth:{
 onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),
 getSession:async()=>({data:{session:{access_token:'synthetic'}}}),
 getUser:async()=>({data:{user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'owner@example.invalid'}}}),
 mfa:{getAuthenticatorAssuranceLevel:async()=>({data:{currentLevel:'aal2'}})},
 signOut:async()=>({error:null})}});
"""
mockHTTP = """
window.__ops=[];
window.fetch=async(url,opts)=>{
  const op=JSON.parse(opts?.body||'{}').operation;
  window.__ops.push(op);
  const when='2026-10-18T00:00:00Z',id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
  let data;
  if(String(url).endsWith('bil-admin-web-v1')){
    if(op==='status')data={access:'authorized',financial_writes_enabled:false};
    if(op==='list')data={rows:[{id,email:'long.recipient.name@example.invalid',status:'revoked',plan_id:'premium_ai_coach',created_at:when}],has_more:false};
    if(op==='audit')data={rows:[{id,actor_id:id,operation:'revoke',changed:true,matched:true,created_at:when,grant_id:id}]};
  }else{
    if(op==='status')data={access:'authorized',writes_enabled:false};
    if(op==='moderators.list')data={receipt:[{user_id:id,email:'moderator.long.name@example.invalid',created_at:when,protected_administrator:false}]};
    if(op==='members.list')data={receipt:[{user_id:id,email:'suspended.long.name@example.invalid',suspended_at:when,reason:'Community rule violation'}]};
    if(op==='moderation.posts.pending')data={receipt:[{id,author_name:'Synthetic author',author_id:id,reporter_email:'post.author@example.invalid',body:'Test post',moderation_status:'pending',created_at:when}]};
    if(op==='moderation.reports.open')data={receipt:[{id,reporter_email:'reporter.community@example.invalid',reporter_user_id:id,reason:'Unsafe content',target_kind:'post',target_id:id,status:'open',created_at:when}]};
    if(op==='moderation.safety.open')data={receipt:[{report_id:id,reporter_email:'reporter.safety@example.invalid',reporter_user_id:id,reason:'unsafe',user_note:'مشكلة في رد المدرب',answer_text:'A long answer that is readable and hidden in disclosure. '.repeat(9),runtime:'local_fallback',locale:'ar',status:'open',created_at:when}]};
  }
  if(!data)data={error:'no_synthetic_writes'};
  return {ok:!data.error,status:data.error?400:200,json:async()=>data};
};
"""

checks=[]
with sync_playwright() as playwright:
  chrome=next((shutil.which(exe) for exe in ('google-chrome','chromium') if shutil.which(exe)),None)
  launch={'headless':True,'args':['--no-sandbox','--disable-dev-shm-usage']}
  if chrome:launch['executable_path']=chrome
  browser=playwright.chromium.launch(**launch)
  for width in (320,375,390,430,800,1280):
    page=browser.new_page(viewport={'width':width,'height':860})
    errors=[]
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.set_content(html,wait_until='load')
    assert 'reporter.safety@example.invalid' not in page.locator('body').inner_text()
    page.add_script_tag(content=mockHTTP)
    page.add_script_tag(content=mockAuth+app[len(imports):])
    page.wait_for_function("document.querySelector('#admin-view').hidden === false",timeout=15000)
    for section in ('overview','finance','moderators','members','audit','coach','notifications','moderation','security'):
      page.locator('[data-page="'+section+'"]').evaluate('(e)=>e.click()')
      if section=='moderation':
        for queue in ('posts','reports','safety'):
          page.locator('[data-queue="'+queue+'"]').evaluate('(e)=>e.click()')
          page.wait_for_function("document.querySelector('#queue-content .report-card')!==null",timeout=10000)
          if queue=='safety':
            text=page.locator('#queue-content').inner_text()
            assert 'reporter.safety@example.invalid' in text and 'مشكلة في رد المدرب' in text
            assert page.locator('#queue-content pre.record-body').count()==0
      if section=='audit':page.wait_for_function("document.querySelector('#audit-content .data-table')!==null",timeout=10000)
      w=max(page.evaluate('document.documentElement.scrollWidth'),page.evaluate('document.body.scrollWidth'))
      assert w<=width+3,f'Horizontal overflow at {width} on {section}: {w}'
      if section=='finance':
        assert 'ملغاة' in page.locator('#finance-list').inner_text()
      if section=='audit':
        assert 'سحب' in page.locator('#audit-content').inner_text()
      if section=='coach':
        assert 'عدادات استخدام' in page.locator('#coach-page').inner_text()
        assert page.locator('#coach-page button.ops-write').first.is_disabled()
      if section=='notifications':
        kind=page.locator('#notification-form select[name="kind"] option').first.text_content()
        assert 'مخصص' in re.sub('[\u064b-\u065f]','',kind)
      if section=='members':assert 'المجتمع' in page.locator('#members-page .page-help').inner_text()
    page.locator('[data-page="moderation"]').evaluate('(e)=>e.click()')
    page.locator('[data-queue="safety"]').evaluate('(e)=>e.click()')
    page.wait_for_function("document.querySelector('#queue-content .report-card')!==null",timeout=10000)
    page.locator('button.compensation-draft').first.click()
    assert page.locator('#notification-form [name="email"]').input_value()=='reporter.safety@example.invalid'
    assert page.locator('#notification-form [name="kind"]').input_value()=='compensation'
    assert page.locator('#notification-form button.ops-write').is_disabled()
    assert 'notifications.send' not in page.evaluate('window.__ops')
    page.locator('#language').click()
    assert page.evaluate('document.documentElement.dir')=='ltr'
    w=max(page.evaluate('document.documentElement.scrollWidth'),page.evaluate('document.body.scrollWidth'))
    assert w<=width+3,f'English LTR overflow at {width}: {w}'
    if width in (375,1280):
      page.locator('#language').click()
      page.locator('[data-page="moderation"]').evaluate('(e)=>e.click()')
      page.locator('[data-queue="safety"]').evaluate('(e)=>e.click()')
      dest=Path(os.environ.get('BIL_ADMIN_E2E_ARTIFACTS','/tmp'))/('admin-synthetic-'+str(width)+'.png')
      dest.parent.mkdir(parents=True,exist_ok=True)
      page.screenshot(path=str(dest),full_page=True)
    assert not errors, str(errors)
    checks.append({'width':width,'modules':9,'moderation_queues':3,'languages':2,'overflow':0,'report_email_verified':True,'synthetic':True})
    page.close()
  browser.close()
print('BIL_ADMIN_SYNTHETIC_E2E_PASS '+json.dumps(checks))
