"""Prepared real PostgreSQL sessions for report review/authority; loopback only.
Synthetic auth claims stand in for PostgREST authentication, not a live SDK/device.
Loads repository SQL bodies, tests actual locks/RLS/transactions, and records hashes.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import time
import uuid

parser=argparse.ArgumentParser()
parser.add_argument('--psql',required=True)
parser.add_argument('--port',type=int,default=55432)
parser.add_argument('--case')
args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[2]
stamp=datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')
database='bil_qa_safety_'+stamp
assert re.fullmatch(r'bil_qa_safety_[0-9]+',database)
base=[args.psql,'-X','-qAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(args.port),'-U','bil_test_superuser']
out=root/'build/stage1-closure'/('postgres-community-safety-'+stamp)
out.mkdir(parents=True,exist_ok=False)
records=[]
inputs={}

def source(path):
    data=(root/path).read_bytes()
    inputs[path]=hashlib.sha256(data).hexdigest()
    return data.decode('utf-8')

def function(sql,name):
    pattern=r'(create(?:\s+or\s+replace)?\s+function\s+'+re.escape(name)+r'\s*\(.*?\bas\s+(\$[a-zA-Z_]*\$).*?\2\s*;)'
    match=re.search(pattern,sql,re.I|re.S)
    if not match: raise AssertionError('Missing source function '+name)
    return match.group(1)

def actor_sql(sql,actor,role='authenticated',application=''):
    claims=json.dumps({'sub':actor,'role':role})
    return ("begin; set local role "+role+"; select set_config('request.jwt.claims','"+claims+"',true); "
      "select set_config('request.jwt.claim.sub','"+actor+"',true); "
      "select set_config('application_name','"+application+"',true); "+sql+";commit;")

def execute(sql,actor=None,role='authenticated',db=None):
    if actor: sql=actor_sql(sql,actor,role)
    result=subprocess.run(base+['-d',db or database],input=sql,text=True,encoding='utf-8',capture_output=True,timeout=30)
    if result.returncode: raise RuntimeError(result.stderr)
    return result.stdout.strip().splitlines()

def scalar(sql,actor=None,role='authenticated'):
    return execute(sql,actor,role)[-1]

def value(sql,actor=None): return json.loads(scalar(sql,actor))
def uid(n): return f'12000000-0000-4000-8000-{n:012d}'
def deny(sql,actor,reason,role='authenticated'):
    try: execute(sql,actor,role)
    except RuntimeError as error:
        assert reason in str(error),str(error)
        return
    raise AssertionError('Unauthorized/stale operation succeeded')

def check(name,body):
    if args.case and name!=args.case: return
    try: body();records.append({'name':name,'result':'PASS'});print('PASS: '+name,flush=True)
    except Exception as error:
        records.append({'name':name,'result':'FAIL','error':str(error)});print('FAIL: '+name+': '+str(error),flush=True)

def post(n):
    identity=uid(1000+n)
    execute(f"insert into public.bil_community_posts(id,author_id,body,visibility,moderation_status,reviewed_at) values('{identity}','{uid(3)}','Synthetic reported post {n}','community','approved',now());")
    return identity

def report(n,target):
    identity=uid(2000+n)
    execute(f"insert into public.bil_community_reports(id,reporter_id,target_kind,target_id,reason) values('{identity}','{uid(5)}','post','{target}','Synthetic report reason');")
    return identity

def review(identity,kind='community',actor=2):
    return value(f"select public.bil_community_report_content_v1('{identity}','{kind}');",uid(actor))

def decide(identity,revision,kind='community',remove=True,key=None,actor=2):
    key=key or str(uuid.uuid4())
    return value(f"select public.bil_decide_community_report_v1('{identity}','{kind}','{revision}',{str(remove).lower()},'{key}');",uid(actor))

def wait_locked(application):
    deadline=time.monotonic()+8
    while time.monotonic()<deadline:
        if scalar("select exists(select 1 from pg_stat_activity where datname='"+database+"' and application_name='"+application+"' and wait_event_type='Lock');")=='t': return
        time.sleep(.01)
    raise AssertionError('Did not reach real PostgreSQL lock barrier: '+application)

def withdrawal_race(n,patched,report_target=False):
    identity=post(n); target=report(n,identity) if report_target else identity
    execute(f"insert into public.bil_community_moderators(user_id) values('{uid(2)}') on conflict do nothing;")
    locker=subprocess.Popen(base+['-d',database],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8')
    table='bil_community_reports' if report_target else 'bil_community_posts'
    locker.stdin.write(f"begin;select id from public.{table} where id='{target}' for update;select 'LOCK_READY';\n");locker.stdin.flush()
    while locker.stdout.readline().strip()!='LOCK_READY':
        if locker.poll() is not None: raise AssertionError('Row locker exited before barrier')
    sql=(f"select public.bil_moderate_community_report('{target}','closed','remove_content')" if report_target
         else f"select public.bil_moderate_published_community_post('{target}','hide','spam')")
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        decision=pool.submit(execute,actor_sql(sql,uid(2),application='bil_safety_decision'))
        wait_locked('bil_safety_decision')
        withdraw=pool.submit(execute,"begin;set local application_name='bil_safety_withdraw';delete from public.bil_community_moderators where user_id='"+uid(2)+"';commit;")
        try:
            if patched:
                wait_locked('bil_safety_withdraw');assert not withdraw.done()
            else: withdraw.result(timeout=8)
        finally:
            locker.stdin.write('commit;\n');locker.stdin.flush();locker.stdin.close()
            locker.wait(timeout=10)
        decision.result(timeout=12);withdraw.result(timeout=12)
    if report_target: assert scalar(f"select status from public.bil_community_reports where id='{target}';")=='closed'
    else: assert scalar(f"select moderation_visibility from public.bil_community_posts where id='{target}';")=='hidden_by_moderator'
    assert scalar(f"select count(*) from public.bil_community_moderators where user_id='{uid(2)}';")=='0'
    return identity

try:
    execute('create database "'+database+'";',db='postgres')
    execute("""do $$begin
      if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
      if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
      if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role;end if;
    end $$;create schema auth;create schema private;create schema extensions;
    create extension pgcrypto with schema extensions;
    create table auth.users(id uuid primary key,email text,deleted_at timestamptz);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
    grant usage on schema auth,public to anon,authenticated,service_role;""")
    execute(source('supabase/tests/fixtures/community_review_baseline/schema.sql'))
    execute(source('supabase/tests/fixtures/community_review_baseline/functions.sql'))
    foundation=source('supabase/migrations/202608020002_bil_community_foundation.sql')
    for name in ['bil_messages','bil_community_food_submissions','bil_community_reports']:
        statement=re.search(r'create table if not exists public\.'+name+r'\s*\(.*?\);',foundation,re.S).group(0)
        execute(statement)
    social=source('supabase/migrations/20260908013800_bil_community_social_v2.sql')
    for name in ['bil_social_comments_v2','bil_social_comment_reports_v2']:
        statement=re.search(r'create table public\.'+name+r'\(.*?\);',social,re.S).group(0)
        execute(statement)
    member=source('supabase/migrations/20260905160000_admin_community_access_control.sql')
    roster=source('supabase/migrations/20260904030000_community_post_human_moderation.sql')
    for table,sql in [('bil_community_member_access_audit',member),('bil_community_moderator_admin_audit',roster)]:
        execute(re.search(r'create table if not exists private\.'+table+r'\s*\(.*?\);',sql,re.S).group(0))
    for name,sql in [('public.bil_can_use_community',member),('public.bil_has_community_moderators',roster),
      ('public.bil_add_community_moderator_by_email',roster),('public.bil_remove_community_moderator',roster),
      ('public.bil_list_suspended_community_members_for_admin',member),
      ('public.bil_suspend_community_member_by_email',member),('public.bil_reinstate_community_member',member),
      ('public.bil_social_resolve_comment_report_v2',social)]:
        execute(function(sql,name))
    execute(source('supabase/migrations/20260905160100_fix_community_admin_coalesce.sql'))
    execute(source('supabase/migrations/20260905160200_fix_community_suspend_uuid_aggregate.sql'))
    authority=source('supabase/migrations/20260924223453_community_admin_moderation_visibility.sql')
    execute(function(authority,'public.bil_moderate_published_community_post'))
    generic=source('supabase/migrations/20260925005354_final_hardening_cloud_consent_community_authority.sql')
    execute(function(generic,'public.bil_moderate_community_report'))
    execute("""create function public.bil_is_community_moderator() returns boolean language sql stable security definer set search_path='' as $$select private.bil_resolve_community_moderation_authority(auth.uid()) is not null$$;
      alter table public.bil_blocks enable row level security;
      grant select,insert,delete on public.bil_blocks to authenticated;
      create policy bil_blocks_own on public.bil_blocks for select to authenticated using(blocker_id=auth.uid());
      create policy bil_blocks_insert_own on public.bil_blocks for insert to authenticated with check(blocker_id=auth.uid());
      create policy bil_blocks_delete_own on public.bil_blocks for delete to authenticated using(blocker_id=auth.uid());""")
    for n in range(1,7): execute(f"insert into auth.users(id,email) values('{uid(n)}','synthetic{n}@example.test');")
    execute(f"insert into private.bil_ai_coach_admins(user_id,active) values('{uid(1)}',true);insert into public.bil_community_moderators(user_id) values('{uid(2)}');")
    catalog=json.loads(source('supabase/tests/fixtures/community_safety_authority_baseline/catalog.json'))
    execute(source('supabase/tests/fixtures/community_safety_authority_baseline/functions.sql'))
    execute(source('supabase/tests/fixtures/community_safety_authority_baseline/contracts.sql'))
    def published_contracts():
        assert len(catalog)==8
        for row in catalog:
            signature=row['signature']
            meta=value("select json_build_object('result',pg_get_function_result(p.oid),'security_definer',p.prosecdef,'settings',p.proconfig,'grantees',(select array_agg(r.rolname order by r.rolname) from aclexplode(p.proacl) a join pg_roles r on r.oid=a.grantee where a.grantee<>p.proowner)) from pg_proc p where p.oid='"+signature+"'::regprocedure;")
            expected=sorted(item.split('=')[0] for item in row['acl'].strip('{}').split(',') if not item.startswith('postgres='))
            assert meta=={'result':row['result_type'],'security_definer':True,'settings':row['settings'],'grantees':expected},signature
    check('current RPC types and execute roles match captured published catalog',published_contracts)
    check('baseline hide admits effect after a separately committed withdrawal',lambda:withdrawal_race(1,False))
    signatures=['public.bil_moderate_community_post(uuid,text)','public.bil_moderate_published_community_post(uuid,text,text)',
      'public.bil_moderate_community_report(uuid,text,text)','public.bil_social_resolve_comment_report_v2(uuid,boolean)',
      'public.bil_add_community_moderator_by_email(uuid,text,text)','public.bil_remove_community_moderator(uuid,uuid,text)',
      'public.bil_suspend_community_member_by_email(uuid,text,text,text)','public.bil_reinstate_community_member(uuid,uuid,text)']
    before={name:scalar("select pg_get_function_result('"+name+"'::regprocedure)||':'||coalesce(proacl::text,'') from pg_proc where oid='"+name+"'::regprocedure;") for name in signatures}
    execute(source('supabase/migrations/20261013062221_community_safety_report_review_v1.sql'))
    def compatibility():
        after={name:scalar("select pg_get_function_result('"+name+"'::regprocedure)||':'||coalesce(proacl::text,'') from pg_proc where oid='"+name+"'::regprocedure;") for name in signatures}
        assert before==after
        published_contracts()
    check('old RPC identities return types ACL and financial rights are unchanged',compatibility)
    check('hide serializes admitted decision before role withdrawal commits',lambda:withdrawal_race(2,True))
    check('generic report serializes admitted decision before role withdrawal commits',lambda:withdrawal_race(3,True,True))
    execute(f"insert into public.bil_community_moderators(user_id) values('{uid(2)}') on conflict do nothing;")
    def admin_race():
        key='safety-reinstate-barrier-0001'
        execute(f"insert into private.bil_community_member_access(user_id,suspended,reason) values('{uid(6)}',true,'Synthetic suspension');")
        gate=subprocess.Popen(base+['-d',database],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8')
        gate.stdin.write("begin;select pg_advisory_xact_lock(hashtextextended('community_member_access:"+key+"',0));select 'ADMIN_GATE';\n");gate.stdin.flush()
        while gate.stdout.readline().strip()!='ADMIN_GATE':
            if gate.poll() is not None: raise AssertionError('Admin gate exited before barrier')
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            mutation=pool.submit(execute,actor_sql(f"select public.bil_reinstate_community_member('{uid(1)}','{uid(6)}','{key}')",uid(1),role='service_role',application='bil_safety_admin'))
            wait_locked('bil_safety_admin')
            withdraw=pool.submit(execute,"begin;set local application_name='bil_safety_admin_withdraw';update private.bil_ai_coach_admins set active=false where user_id='"+uid(1)+"';commit;")
            try: wait_locked('bil_safety_admin_withdraw');assert not withdraw.done()
            finally:
                gate.stdin.write('commit;\n');gate.stdin.flush();gate.stdin.close();gate.wait(timeout=10)
            mutation.result(timeout=12);withdraw.result(timeout=12)
        assert scalar(f"select not suspended from private.bil_community_member_access where user_id='{uid(6)}';")=='t'
        deny(f"select public.bil_reinstate_community_member('{uid(1)}','{uid(6)}','safety-reinstate-withdrawn-0002');",uid(1),'administrator_required',role='service_role')
        execute(f"update private.bil_ai_coach_admins set active=true where user_id='{uid(1)}';")
    check('service-only reinstatement finishes before admitted administrator withdrawal commits',admin_race)
    def direct_admin():
        requests=[f"select public.bil_add_community_moderator_by_email('{uid(1)}','synthetic6@example.test','safety-direct-add-00001')",
          f"select public.bil_remove_community_moderator('{uid(1)}','{uid(2)}','safety-direct-remove-0001')",
          f"select public.bil_suspend_community_member_by_email('{uid(1)}','synthetic6@example.test','Synthetic reason','safety-direct-suspend-01')",
          f"select public.bil_reinstate_community_member('{uid(1)}','{uid(6)}','safety-direct-reinstate-1')"]
        before_roster=scalar('select count(*) from public.bil_community_moderators;')
        before_access_audit=scalar('select count(*) from private.bil_community_member_access_audit;')
        for request in requests: deny(request,uid(5),'permission denied for function')
        # The execute ACL above rejects an ordinary caller before the body.
        # A trusted service must still resolve a real authorized actor.
        deny(f"select public.bil_reinstate_community_member('{uid(5)}','{uid(6)}','safety-untrusted-actor-01');",uid(5),'administrator_required',role='service_role')
        assert scalar('select count(*) from public.bil_community_moderators;')==before_roster
        assert scalar('select count(*) from private.bil_community_member_access_audit;')==before_access_audit
        assert scalar('select count(*) from public.bil_ai_credit_balances;')=='0'
    check('ordinary direct API cannot spoof the actor of roster or suspension RPCs',direct_admin)
    def rights():
        target=post(4);identity=report(4,target)
        deny(f"select public.bil_community_report_content_v1('{identity}','community');",uid(5),'moderator_or_administrator_required')
        execute(f"insert into public.bil_community_moderators(user_id) values('{uid(3)}');")
        deny(f"select public.bil_community_report_content_v1('{identity}','community');",uid(3),'moderator_cannot_review_own_content')
        execute(f"delete from public.bil_community_moderators where user_id='{uid(3)}';")
        data=review(identity);assert data['body']=='Synthetic reported post 4'
        assert set(data)=={'contract_version','report_id','source','target_id','target_kind','reason','status','available','body','parent_body','post','can_remove','revision'}
        assert 'reporter_id' not in json.dumps(data) and 'email' not in json.dumps(data)
        execute(f"delete from public.bil_community_moderators where user_id='{uid(2)}';")
        deny(f"select public.bil_community_report_content_v1('{identity}','community');",uid(2),'moderator_or_administrator_required')
        execute(f"insert into public.bil_community_moderators(user_id) values('{uid(2)}');")
    check('ordinary own-content and revoked identities cannot read reported content',rights)
    def suspended_review():
        target=post(8);identity=report(8,target)
        execute(f"insert into private.bil_community_member_access(user_id,suspended,reason) values('{uid(2)}',true,'Synthetic review suspension');")
        try:
            deny(f"select public.bil_community_report_content_v1('{identity}','community');",uid(2),'community_unavailable')
        finally:
            # Use the real service-only reinstatement contract, including its
            # timestamp, actor and audit. Never bypass the captured CHECK.
            execute(f"select public.bil_reinstate_community_member('{uid(1)}','{uid(2)}','safety-review-reinstate-0001');",uid(1),role='service_role')
        assert scalar(f"select not suspended and reinstated_at is not null and reinstated_by='{uid(1)}' from private.bil_community_member_access where user_id='{uid(2)}';")=='t'
        assert review(identity)['body']=='Synthetic reported post 8'
    check('suspended moderator cannot read content until reinstated',suspended_review)
    def revision():
        target=post(5);identity=report(5,target);snapshot=review(identity)
        execute(f"update public.bil_community_posts set body='Changed after review' where id='{target}';")
        deny(f"select public.bil_decide_community_report_v1('{identity}','community','{snapshot['revision']}',true,'{uuid.uuid4()}');",uid(2),'community_report_content_changed')
        assert scalar(f"select deleted_at is null from public.bil_community_posts where id='{target}';")=='t'
    check('changed reported text rejects stale removal without deleting content',revision)
    def media_revision():
        target=post(9);identity=report(9,target)
        execute(f"insert into public.bil_community_post_media_v1(post_id,position,object_path,mime_type,bytes,width,height) values('{target}',0,'synthetic-report-preview.jpg','image/jpeg',100,100,100);")
        snapshot=review(identity)
        execute(f"update public.bil_community_post_media_v1 set object_path='changed-report-preview.jpg' where post_id='{target}' and position=0;")
        deny(f"select public.bil_decide_community_report_v1('{identity}','community','{snapshot['revision']}',true,'{uuid.uuid4()}');",uid(2),'community_report_content_changed')
        assert scalar(f"select deleted_at is null from public.bil_community_posts where id='{target}';")=='t'
    check('changed reported image rejects stale removal without deleting content',media_revision)
    def poll_revision(field,number):
        target=post(number);identity=report(number,target)
        execute(f"insert into public.bil_community_polls(post_id,question) values('{target}','Synthetic poll question');insert into public.bil_community_poll_options(post_id,position,option_text) values('{target}',0,'Synthetic first option'),('{target}',1,'Synthetic second option');")
        snapshot=review(identity)
        if field=='question':
            execute(f"update public.bil_community_polls set question='Edited synthetic question' where post_id='{target}';")
        else:
            execute(f"update public.bil_community_poll_options set option_text='Edited synthetic option' where post_id='{target}' and position=0;")
        deny(f"select public.bil_decide_community_report_v1('{identity}','community','{snapshot['revision']}',true,'{uuid.uuid4()}');",uid(2),'community_report_content_changed')
        assert scalar(f"select deleted_at is null from public.bil_community_posts where id='{target}';")=='t'
        assert scalar(f"select count(*) from private.bil_community_report_decisions_v1 where report_id='{identity}';")=='0'
    check('changed poll question rejects the stale reviewed decision',lambda:poll_revision('question',10))
    check('changed poll option rejects the stale reviewed decision',lambda:poll_revision('option',11))
    def revoked_receipt():
        target=post(12);identity=report(12,target);snapshot=review(identity);key=str(uuid.uuid4())
        receipt=decide(identity,snapshot['revision'],key=key)
        execute(f"delete from public.bil_community_moderators where user_id='{uid(2)}';")
        try:
            deny(f"select public.bil_get_community_report_decision_v1('{key}');",uid(2),'moderator_or_administrator_required')
            deny(f"select public.bil_decide_community_report_v1('{identity}','community','{snapshot['revision']}',true,'{key}');",uid(2),'moderator_or_administrator_required')
            assert scalar(f"select count(*) from private.bil_community_report_decisions_v1 where report_id='{identity}';")=='1'
        finally:
            execute(f"insert into public.bil_community_moderators(user_id) values('{uid(2)}');")
        assert value(f"select public.bil_get_community_report_decision_v1('{key}');",uid(2))==receipt
    check('withdrawn role cannot replay or read a committed report receipt',revoked_receipt)
    def duplicate():
        target=post(6);identity=report(6,target);snapshot=review(identity);key=str(uuid.uuid4())
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            receipts=list(pool.map(lambda _:decide(identity,snapshot['revision'],key=key),range(2)))
        assert sum(r['duplicate'] for r in receipts)==1
        assert all(r['status']=='closed' and r['content_removed'] for r in receipts)
        assert scalar(f"select count(*) from private.bil_community_report_decisions_v1 where report_id='{identity}';")=='1'
        assert value(f"select public.bil_get_community_report_decision_v1('{key}');",uid(2))['status']=='closed'
        deny(f"select public.bil_get_community_report_decision_v1('{key}');",uid(1),'report_receipt_unavailable')
        deny(f"select public.bil_decide_community_report_v1('{identity}','community','{snapshot['revision']}',false,'{key}');",uid(2),'idempotency_conflict')
    check('simultaneous retry creates one decision and owned readback is exact',duplicate)
    def reply():
        target=post(7);parent=uid(3001);child=uid(3002);identity=uid(4001)
        execute(f"insert into public.bil_social_comments_v2(id,post_id,author_id,body) values('{parent}','{target}','{uid(3)}','Synthetic parent');insert into public.bil_social_comments_v2(id,post_id,author_id,parent_id,body) values('{child}','{target}','{uid(4)}','{parent}','Synthetic reported reply');insert into public.bil_social_comment_reports_v2(id,comment_id,reporter_id,reason) values('{identity}','{child}','{uid(5)}','Synthetic abuse reason');")
        snapshot=review(identity,'comment');assert snapshot['target_kind']=='reply' and snapshot['parent_body']=='Synthetic parent'
        receipt=decide(identity,snapshot['revision'],'comment');assert receipt['content_removed']
        assert scalar(f"select reviewed_at is not null from public.bil_social_comment_reports_v2 where id='{identity}';")=='t'
        assert scalar(f"select removed_at is null from public.bil_social_comments_v2 where id='{parent}';")=='t'
    check('reported reply includes only its context and removes only the referenced reply',reply)
    def blocks():
        execute(f"insert into public.bil_blocks(blocker_id,blocked_id) values('{uid(3)}','{uid(4)}'),('{uid(4)}','{uid(3)}');")
        execute(f"delete from public.bil_blocks where blocker_id='{uid(4)}' and blocked_id='{uid(3)}';",uid(3))
        assert scalar(f"select count(*) from public.bil_blocks;")=='2'
        execute(f"delete from public.bil_blocks where blocker_id='{uid(3)}' and blocked_id='{uid(4)}';",uid(3))
        assert scalar(f"select count(*) from public.bil_blocks where blocker_id='{uid(3)}';",uid(3))=='0'
        assert scalar(f"select count(*) from public.bil_blocks where blocker_id='{uid(4)}';")=='1'
    check('own-block RLS delete preserves the opposite block and rejects cross-owner removal',blocks)
finally:
    result={'host':'127.0.0.1','port':args.port,'database':database,'production_tested':False,
      'cases':records,'input_sha256':inputs,'source_only_auth_claims':True}
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    execute('drop database if exists "'+database+'" with (force);',db='postgres')
if not records or any(r['result']!='PASS' for r in records): raise SystemExit(1)
