"""Synthetic, offline Playwright E2E of the actual owner-only BIL admin frontend.
No browser requests go to Supabase/production. No real account or money touched.
"""
from pathlib import Path
import json, os, shutil, base64
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
if not (ROOT/'site'/'app.mjs').is_file():
  ROOT=Path(__file__).resolve().parents[3]/'cloudflare'/'admin_site'
site=ROOT/'site'
html=(site/'index.html').read_text()
css=(site/'styles.css').read_text()
app=(site/'app.mjs').read_text()
header="import { createClient } from '@supabase/supabase-js';\nimport { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from './config.mjs';\n"
assert app.startswith(header)
mock_auth="""
const SUPABASE_URL='https://tgmanzhqulksykhslrzb.supabase.co';
const SUPABASE_PUBLISHABLE_KEY='sb_publishable_synthetic_browser_test';
const createClient=()=>({auth:{
  onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),
  getSession:async()=>({data:{session:{access_token:'eyJhbGciOiJub25lIn0.eyJzdWIiOiJzeW50aGV0aWMifQ.signature'}}}),
  getUser:async()=>({data:{user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'owner@example.invalid'}}}),
  mfa:{getAuthenticatorAssuranceLevel:async()=>({data:{currentLevel:'aal2'}}),
       listFactors:async()=>({data:{totp:[{id:'factor-synthetic',status:'verified'}]}}),
       challengeAndVerify:async()=>({data:{id:'challenge-synthetic'}})},
  signOut:async()=>({error:null})
}});
"""
script=mock_auth+app[len(header):]
assert '<link rel="stylesheet" href="./styles.css">' in html
assert '<script type="module" src="./app.bundle.js"></script>' in html
markup=html.replace('<link rel="stylesheet" href="./styles.css">','<style>'+css+'</style>').replace('<script type="module" src="./app.bundle.js"></script>','')
fixtures_js=r'''const author='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const post='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const report='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const grant='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const revision='f'.repeat(64);
const created='2026-10-18T03:30:00Z';
const photo=(idx)=>'https://tgmanzhqulksykhslrzb.supabase.co/storage/v1/object/sign/community-post-images/synthetic/'+idx+'.png?token=SYNTHETIC';
const fakePost={id:post,post_id:post,revision,title:'عنوان منشور مهم كامل عن التغذية والصحة، حتى يظهر كله',
 body:'هذه مشاركة طويلة للاختبار فقط تتضمن كل التفاصيل اللازمة للمراجعة. '.repeat(20),
 author_id:author,author_name:'Synthetic Community Contributor',author_email:'posting.author@example.invalid',
 status:'pending',moderation_status:'pending',created_at:created,location:'Cairo',hashtags:['nutrition','fitness'],
 poll:{question:'ما رأيكم؟',options:['ممتاز','يحتاج تعديل']},visibility:'community',
 images:[{url:photo(1),position:0},{url:photo(2),position:1}],media_count:2,media_complete:true,can_decide:true};
window.__requests=[];
window.__moderationWriteEnabled=false;
window.__mediaRequests=[];
const payload=(type,op,body)=>{
 if(type==='finance'){
   if(op==='status')return {access:'authorized',financial_writes_enabled:true};
   if(op==='list')return {rows:[{id:grant,email:'account.with.very.long.name@example.invalid',status:'revoked',plan_id:'premium_ai_coach',created_at:created},{id:'ffffffff-ffff-4fff-8fff-ffffffffffff',email:'active.account@example.invalid',status:'active',plan_id:'premium',created_at:created,expires_at:'2026-11-18T00:00:00Z'}],has_more:false};
   if(op==='audit')return {rows:[{id:report,actor_id:author,operation:'revoke',created_at:created,matched:true,changed:true,grant_id:grant,recipient_email:'account.with.very.long.name@example.invalid',actor_email:'owner@example.invalid',plan_id:'premium_ai_coach'}]};
   if(op==='grant'||op==='revoke')return {state:'verified',receipt:{matched:true,changed:true,grant_id:grant}};
 }
 if(type==='ops'){
   if(op==='status')return {access:'authorized',writes_enabled:true};
   if(op==='moderators.list')return {receipt:[{user_id:author,email:'moderator.long.name@example.invalid',protected_administrator:false,created_at:created}]};
   if(op==='members.list')return {receipt:[{user_id:author,email:'suspended.long.name@example.invalid',reason:'Community rule breaches',suspended_at:created}]};
   if(op==='moderation.safety.open')return {receipt:[{report_id:report,reporter_email:'reporting.user@example.invalid',reporter_user_id:author,reason:'unsafe',status:'open',locale:'ar',runtime:'local_fallback',created_at:created,user_note:'كنت بحاجة إلى دعم من المدرب الذكي',answer_text:'المدرب غير متاح حالياً. حاول مرة أخرى لاحقاً.'}]};
   if(op==='moderation.reports.open')return {receipt:[{id:report,reporter_email:'reported.member@example.invalid',reporter_user_id:author,status:'open',target_kind:'post',target_id:post,reason:'محتوى غير مناسب',created_at:created}]};
   if(['moderators.add','moderators.remove','members.suspend','members.reinstate','coach.reset.all','coach.reset.user','notifications.send'].includes(op))return {state:'executed',receipt:{operation:op,confirmation:'synthetic'}};
 }
 if(type==='review'){
   if(op==='status')return {access:'authorized',moderation_writes_enabled:window.__moderationWriteEnabled};
   if(op==='posts.queue')return {receipt:{rows:[fakePost],has_more:false}};
   if(op==='posts.detail')return {receipt:fakePost};
   if(op==='earn.policy')return {receipt:{tokens_per_approval:5,max_rewarded_posts_per_owner_per_utc_day:5,max_daily_tokens:25}};
   if(op==='earn.queue')return {receipt:[{...fakePost,status:'requested',request_id:report,reviewed_at:created}]};
   if(op==='posts.review')return {receipt:{post_id:post,decision:body.decision,tokens_granted:body.decision==='approved'?5:0,reward_reason:'granted',receipt_state:'executed'}};
   if(op==='earn.decide')return {receipt:{request_id:report,status:body.approve?'executed':'rejected',tokens_granted:body.approve?5:0,reward_reason:'granted'}};
 }
 return {error:'bad_synthetic_operation:'+type+':'+op};
};
window.fetch=async (url,options)=>{
 if(/storage\/v1/.test(url))throw Error('Images are handled by mocked browser route');
 const type=String(url).endsWith('bil-admin-web-v1')?'finance':String(url).endsWith('bil-admin-web-ops-v1')?'ops':'review';
 let body={};try{body=JSON.parse(options?.body||'{}')}catch{}
 window.__requests.push({type,operation:body.operation,body});
 const data=payload(type,body.operation,body);
 return {ok:!data.error,status:data.error?400:200,json:async()=>data};
};
'''
widths=(320,375,390,430,768,1280)
results=[]
with sync_playwright() as p:
  chrome=shutil.which('chromium') or shutil.which('google-chrome')
  opts={'headless':True,'args':['--no-sandbox','--disable-dev-shm-usage']}
  if chrome:opts['executable_path']=chrome
  browser=p.chromium.launch(**opts)
  for width in widths:
    page=browser.new_page(viewport={'width':width,'height':900},device_scale_factor=1)
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('dialog',lambda d:d.accept())
    sample_image=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAHgAAABkCAIAAADCEmNlAAABKElEQVR4nO3dwQnCMBiAUSsO5wKCAziCY7iBCwgu6dVra/NZ6HvnEMLHT3pLp/PzdmC8478PsBdCR4SOCB0ROiJ0ROiI0BGhI0JHhI4IHRE6InTkNGv16/IYdI7Nur7vq+xjoiNCR4SOzLujv611eW3QiE+RiY4IHRE6InRE6IjQEaEjQkeEjggdEToidEToiNARoSNCR4SOCB0ROiJ0ROiI0BGhI0JHhI4IHRE6InRE6IjQEaEjQkeEjggdEToidEToiNARoSNCR4SOCB0ROiJ0ROiI0BGhI0JHhI4IHRE6InRk+eNVO3xs8BcmOiJ0ROjI5F9ZDRMdEToidEToiNARoSNCR4SOCB0ROiJ0ROiI0BGhI0JHhI4IHRE6InRE6IjQEaEjQkc+yS4K5B2hCwQAAAAASUVORK5CYII=')
    page.route('**/storage/v1/object/sign/**',lambda route:route.fulfill(status=200,body=sample_image,content_type='image/png'))
    page.set_content(markup,wait_until='load')
    assert 'posting.author@example.invalid' not in page.locator('body').inner_text(), 'PII disclosed before auth'
    page.add_script_tag(content="if(!crypto.randomUUID)Object.defineProperty(crypto,'randomUUID',{value:()=> '7fe15286-8325-4508-bf07-e22bda32ae22'});")
    page.add_script_tag(content=fixtures_js)
    page.add_script_tag(content=script)
    page.wait_for_function("document.getElementById('admin-view').hidden === false",timeout=18000)
    # Operator-facing security gate is explained, not an inert unexplained button.
    assert page.locator('#ops-explain').is_enabled()
    page.locator('#ops-explain').click()
    assert 'متاحة' in page.locator('#notice').inner_text()
    if width<=800:
      # iOS-style off-canvas navigation closes on every expected pathway.
      page.locator('#mobile-menu').click()
      assert 'open' in page.locator('#sidebar').get_attribute('class')
      assert not page.locator('#sidebar-scrim').is_hidden()
      assert page.locator('#mobile-menu').get_attribute('aria-expanded')=='true'
      # Tap outside on the dimmed area to dismiss (particularly narrow 320px screens).
      page.locator('#sidebar-scrim').click(position={'x':12,'y':240},force=True)
      assert 'open' not in page.locator('#sidebar').get_attribute('class')
      assert page.locator('#sidebar-scrim').is_hidden()
      assert page.locator('#mobile-menu').get_attribute('aria-expanded')=='false'
      page.locator('#mobile-menu').click()
      page.keyboard.press('Escape')
      assert 'open' not in page.locator('#sidebar').get_attribute('class')
      page.locator('#mobile-menu').click()
      page.locator('#sidebar-close').click()
      assert 'open' not in page.locator('#sidebar').get_attribute('class')
      page.locator('#mobile-menu').click()
      page.locator('[data-page="notifications"]').click()
      assert 'open' not in page.locator('#sidebar').get_attribute('class')
      assert page.locator('#sidebar-scrim').is_hidden()
      page.locator('[data-page="overview"]').first.evaluate('(e)=>e.click()')
    # Backend raw failures are localized per-operation; an active financial
    # service must not cause a false assertion that every service is writable.
    error_text=page.evaluate("explainBackendError('not_authorized','review')")
    assert 'not_authorized' not in error_text
    assert 'هذه الوظيفة' in error_text
    for section in ('overview','finance','moderators','members','audit','coach','notifications','moderation','security'):
      page.locator(f'[data-page="{section}"]').first.evaluate('(e)=>e.click()')
      if section=='audit':page.wait_for_function("document.querySelector('#audit-content .data-table')!==null",timeout=9000)
      if section=='moderation':
        for q in ('posts','earn','reports','safety'):
          page.locator(f'[data-queue="{q}"]').evaluate('(e)=>e.click()')
          page.wait_for_function("document.querySelector('#queue-content .report-card')!==null",timeout=9000)
          txt=page.locator('#queue-content').inner_text()
          if q=='posts':
            assert 'عنوان منشور مهم كامل عن التغذية' in txt
            assert 'posting.author@example.invalid' in txt
            assert 'هذه مشاركة طويلة' in txt
            assert page.locator('#queue-content .post-image-wrap img').count()==2
            assert page.locator('#queue-content button.review-write').first.is_disabled(), 'Unsafe review enabled'
          if q=='earn':
            assert 'posting.author@example.invalid' in txt
            assert '5 AI Tokens' in page.locator('#earn-policy-summary').inner_text()
            assert page.locator('#queue-content img').count()==2
          if q=='safety':
            assert 'reporting.user@example.invalid' in txt
            assert 'كنت بحاجة' in txt
      dims=page.evaluate('({width:innerWidth,body:document.body.scrollWidth,doc:document.documentElement.scrollWidth})')
      assert max(dims['body'],dims['doc'])<=width+3,f'Horizontal overflow: {section} {width} {dims}'
    page.locator('[data-page="moderation"]').first.evaluate('(e)=>e.click()')
    page.locator('[data-queue="posts"]').evaluate('(e)=>e.click()')
    page.wait_for_function("document.querySelector('#queue-content .report-card')!==null",timeout=9000)
    assert page.locator('#queue-content img').count()==2
    if width==390:
      # A failed signed-image render must lock review even after refreshing backend status.
      page.locator('#queue-content .post-image-wrap img').first.evaluate('(e)=>e.dispatchEvent(new Event("error"))')
      page.evaluate("""state.review.moderation_writes_enabled=true;updateStatuses();""")
      assert page.locator('#queue-content button.review-write').first.is_disabled(), 'Expired/failed media was re-enabled by status refresh'
      page.evaluate("""fakePost.media_complete=true;loadQueue();""")
      page.wait_for_function("document.querySelector('#queue-content button.review-write')?.disabled===false",timeout=9000)
      assert page.locator('#queue-content button.review-write').first.is_enabled()
      page.locator('#queue-content button.review-write').first.click()
      page.wait_for_function("!document.getElementById('review-confirm-modal').hidden",timeout=9000)
      assert 'عنوان منشور مهم كامل' in page.locator('#review-confirm-text').inner_text()
      assert 'مكافأة' in page.locator('#review-confirm-text').inner_text()
      page.locator('#review-confirm-checkbox').check()
      page.locator('#review-confirm-accept').click()
      try: page.wait_for_function("!document.getElementById('mfa-modal').hidden",timeout=9000)
      except Exception:
        print('DEBUG_MODAL',page.evaluate("""({requests:window.__requests,notice:document.getElementById('notice')?.innerText,reviewModal:document.getElementById('review-confirm-modal').hidden,mfa:document.getElementById('mfa-modal').hidden,errors:document.querySelector('.notice.error')?.innerText})"""))
        raise
      page.locator('#step-up-code').fill('123456')
      page.locator('#confirm-stepup').click()
      page.wait_for_function("window.__requests.some(r=>r.operation==='posts.review')",timeout=9000)
      request=page.evaluate("window.__requests.find(r=>r.operation==='posts.review')")
      assert request['body']['decision']=='approved'
      assert request['body']['acknowledge_full_content'] is True
      assert request['type']=='review'
      page.wait_for_function("document.getElementById('review-confirm-modal').hidden",timeout=9000)
      page.wait_for_function("document.getElementById('mfa-modal').hidden",timeout=9000)
      # Reward approval from independent Earn queue is a separate operation.
      page.locator('[data-queue="earn"]').evaluate('(e)=>e.click()')
      page.wait_for_function("document.querySelector('#queue-content button.review-write')!==null",timeout=9000)
      page.locator('#queue-content button.review-write').first.click()
      page.wait_for_function("!document.getElementById('review-confirm-modal').hidden",timeout=9000)
      page.locator('#review-confirm-checkbox').check()
      page.locator('#review-confirm-accept').click()
      try: page.wait_for_function("!document.getElementById('mfa-modal').hidden",timeout=9000)
      except Exception:
        print('DEBUG_MODAL',page.evaluate("""({requests:window.__requests,notice:document.getElementById('notice')?.innerText,reviewModal:document.getElementById('review-confirm-modal').hidden,mfa:document.getElementById('mfa-modal').hidden,errors:document.querySelector('.notice.error')?.innerText})"""))
        raise
      page.locator('#step-up-code').fill('123456')
      page.locator('#confirm-stepup').click()
      page.wait_for_function("window.__requests.some(r=>r.operation==='earn.decide')",timeout=9000)
      assert page.evaluate("window.__requests.find(r=>r.operation==='earn.decide').body.approve") is True
      page.locator('[data-queue="posts"]').evaluate('(e)=>e.click()')
      page.wait_for_function("document.querySelector('#queue-content .report-card')!==null",timeout=9000)
    if width==390:
      # Full synthetic admin operations workflow: every privileged button sends a
      # verified operation only after typed recipient confirmation and MFA.
      async_ops=set()
      def execute_form(page_name,form_id,values,expected_operation):
        page.locator(f'[data-page="{page_name}"]').first.evaluate('(e)=>e.click()')
        form=page.locator('#'+form_id)
        for name,value in values.items():
          item=form.locator('[name="'+name+'"]')
          if isinstance(value,bool):
            if value:item.check()
            else:item.uncheck()
          elif item.evaluate('(el)=>el.tagName')=='SELECT':item.select_option(str(value))
          else:item.fill(str(value))
        form.locator('button').last.click()
        page.wait_for_function("!document.getElementById('mfa-modal').hidden",timeout=9000)
        page.locator('#step-up-code').fill('123456')
        page.locator('#confirm-stepup').click()
        page.wait_for_function("window.__requests.some(r=>r.operation==='"+expected_operation+"')",timeout=9000)
        async_ops.add(expected_operation)
        page.wait_for_function("document.getElementById('mfa-modal').hidden",timeout=9000)

      execute_form('moderators','moderator-form',{
        'email':'mod.example@example.invalid','confirm_email':'mod.example@example.invalid'
      },'moderators.add')
      execute_form('members','member-form',{
        'email':'user.example@example.invalid','confirm_email':'user.example@example.invalid',
        'reason':'Verified community policy violation'
      },'members.suspend')
      execute_form('coach','coach-individual-form',{
        'email':'user.example@example.invalid','confirm_email':'user.example@example.invalid',
        'reason':'Verified support request','message':'AI Coach allowance restored'
      },'coach.reset.user')
      execute_form('coach','coach-global-form',{
        'message':'Allowance counters restored','confirm_phrase':'RESET ALL AI COACH ACCOUNTS'
      },'coach.reset.all')
      execute_form('notifications','notification-form',{
        'kind':'gift','audience':'all','message':'A gift for every BIL member',
        'confirm_target':'SEND TO ALL','confirm_mass_grant':'GRANT 2500 AI TOKENS TO ALL USERS',
        'acknowledge_token_grant':True
      },'notifications.send')
      request=page.evaluate("window.__requests.filter(r=>r.operation==='notifications.send').slice(-1)[0]")
      assert request['body']['confirm_mass_grant']=='GRANT 2500 AI TOKENS TO ALL USERS'
      assert request['body']['acknowledge_token_grant'] is True
      page.locator('[data-page="finance"]').first.evaluate('(e)=>e.click()')
      page.locator('#grant-form [name="email"]').fill('grant.user@example.invalid')
      page.locator('#grant-form [name="confirm_email"]').fill('grant.user@example.invalid')
      page.locator('#grant-form [name="reason"]').fill('Verified goodwill support grant')
      page.locator('#grant-form [name="external_grant"]').check()
      page.locator('#grant-submit').click()
      page.wait_for_function("!document.getElementById('mfa-modal').hidden",timeout=9000)
      page.locator('#step-up-code').fill('123456')
      page.locator('#confirm-stepup').click()
      page.wait_for_function("window.__requests.some(r=>r.operation==='grant')",timeout=9000)
      assert page.locator('#finance-list').inner_text().count('active.account@example.invalid')>0
      assert page.locator('#audit-content').count()==1
      assert len(async_ops)==5
      # Search actually filters visible records; no fictitious rows.
      page.locator('#finance-filter').fill('active.account')
      assert 'active.account@example.invalid' in page.locator('#finance-list').inner_text()
      assert 'account.with.very.long.name@example.invalid' not in page.locator('#finance-list').inner_text()
      page.locator('#finance-filter').fill('')
      page.locator('[data-page="audit"]').first.evaluate('(e)=>e.click()')
      assert 'owner@example.invalid' in page.locator('#audit-content').inner_text()
    if width in (375,390,1280):
      path=Path(os.getenv('BIL_ADMIN_E2E_ARTIFACTS','/mnt/data/bil-admin-global-20261018/evidence'))
      path.mkdir(parents=True,exist_ok=True)
      page.screenshot(path=str(path/f'ugc_review_mobile_{width}.png'),full_page=True)
    page.locator('#language').click()
    assert page.evaluate('document.documentElement.dir')=='ltr'
    assert page.evaluate('document.documentElement.scrollWidth')<=width+3
    assert not errors,repr(errors)
    results.append({'width':width,'modules':9,'queues':4,'postTitleAndFullBody':True,'privatePhotoPreviews':2,'earnPolicy':5,'rtl':True,'ltr':True,'overflow':False,'js_errors':0})
    page.close()
  browser.close()
print('BIL_SYNTHETIC_BROWSER_E2E_PASS '+json.dumps(results,ensure_ascii=False))