-- Owner-authorized live RPC/RLS audit. Synthetic owners only, always ROLLBACK.
-- PRECHECK, TRANSACTION and RESIDUE are independent calls. Unknown trigger or
-- function drift aborts before seeding. No DDL, external HTTP or real-user writes.

-- BEGIN SEGMENT PRECHECK
with owners as(select array['b1380038-0000-4000-8000-000000000001','b1380038-0000-4000-8000-000000000002']::uuid[] as ids),
inventory as(
 select 'auth.users'::text as table_name,count(*) as synthetic_rows from auth.users,owners where id=any(ids)
 union all select 'auth.identities',count(*) from auth.identities,owners where user_id=any(ids)
 union all select 'public.bil_entitlements',count(*) from public.bil_entitlements,owners where owner_id=any(ids)
 union all select 'public.bil_smart_plan_sync_state',count(*) from public.bil_smart_plan_sync_state,owners where owner_id=any(ids)
 union all select 'bil_smart_plan_private.consent',count(*) from bil_smart_plan_private.consent,owners where owner_id=any(ids)
)
select count(*) as inventoried_table_count,bool_and(synthetic_rows=0) as zero_synthetic_rows,
 jsonb_agg(to_jsonb(inventory) order by table_name) as table_counts from inventory;
-- END SEGMENT PRECHECK

-- BEGIN SEGMENT TRANSACTION
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
do $smart_plan_audit$
declare
 a constant uuid:='b1380038-0000-4000-8000-000000000001';
 b constant uuid:='b1380038-0000-4000-8000-000000000002';
 marker constant text:='bil_smart_plan_v38_20261023';
 checks jsonb:='{}'; result jsonb; payload jsonb; extended jsonb; reviewed jsonb; rejected boolean;
 error_state text; error_message text;
begin
 if exists(select 1 from auth.users where id in(a,b) or email in(marker||'-a@example.invalid',marker||'-b@example.invalid'))
   or exists(select 1 from public.bil_smart_plan_sync_state where owner_id in(a,b))
   or exists(select 1 from bil_smart_plan_private.consent where owner_id in(a,b))
   or exists(select 1 from public.bil_entitlements where owner_id in(a,b)) then
  raise exception 'AUDIT synthetic identifiers are occupied';
 end if;
 checks:=checks||jsonb_build_object('synthetic_identifiers_absent',true);
 if exists(select 1 from pg_trigger t where not t.tgisinternal and (
     (t.tgrelid='auth.users'::regclass and not (
       t.tgname='bil_remove_owned_circles_before_account_delete_v1' and t.tgtype=11
       and t.tgenabled='O' and t.tgnargs=0 and t.tgqual is null
       and t.tgfoid=coalesce(to_regprocedure('private.bil_remove_owned_circles_before_account_delete_v1()')::oid,0)
       and (select md5(prosrc) from pg_proc where oid=t.tgfoid)='07e9bc31211219735ef172d3d9e6eee4'))
     or t.tgrelid in('public.bil_entitlements'::regclass,'public.bil_smart_plan_sync_state'::regclass,'bil_smart_plan_private.consent'::regclass))) then
  raise exception 'AUDIT unreviewed external trigger';
 end if;
 checks:=checks||jsonb_build_object('reviewed_trigger_inventory',true);
 if exists(with expected(schema_name,function_name,body_hash) as(values
    ('public','bil_smart_plan_cas_v1','a161fcef0c6d370c9f14c5047da6b548'),
    ('public','bil_smart_plan_consent_v1','351170a6d7d9c224faafe171ddf286ab'),
    ('public','bil_smart_plan_read_v1','83f8b662a13e3ae18f02d1ecb575cb1d'),
    ('bil_smart_plan_private','valid_payload','b0e1fcbf6550fee0b7b97afef2da48fb'),
    ('bil_smart_plan_private','valid_payload_base_v1','a02585bb753528c3c6408dbd9c5f855a'),
    ('bil_smart_plan_private','access_owner','289221b9c9e41bb24ec1a91fb221f708'))
   select 1 from expected e left join (select n.nspname,p.proname,md5(p.prosrc) body_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace) p
   on p.nspname=e.schema_name and p.proname=e.function_name where p.body_hash is distinct from e.body_hash) then
  raise exception 'AUDIT Smart Plan function source drift';
 end if;
 checks:=checks||jsonb_build_object('deployed_function_identity',true);
 if not (select relrowsecurity from pg_class where oid='public.bil_smart_plan_sync_state'::regclass)
   or has_table_privilege('anon','public.bil_smart_plan_sync_state','SELECT')
   or has_table_privilege('authenticated','public.bil_smart_plan_sync_state','INSERT,UPDATE,DELETE')
   or has_schema_privilege('authenticated','bil_smart_plan_private','USAGE') then
  raise exception 'AUDIT RLS/ACL drift';
 end if;
 checks:=checks||jsonb_build_object('table_rls_and_write_acl',true);
 insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_anonymous) values
  (a,'authenticated','authenticated',marker||'-a@example.invalid',now(),now(),now(),'{"provider":"email","providers":["email"]}','{}',false),
  (b,'authenticated','authenticated',marker||'-b@example.invalid',now(),now(),now(),'{"provider":"email","providers":["email"]}','{}',false);
 insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id)
  values(a,'plan:premium',marker,'closed_test',true,now(),now()+interval '1 hour',marker);
 payload:=jsonb_build_object('schema',1,'id',marker,'ownerId',a::text,'revision',1,'status','draft','horizon','week','focus','training',
   'startDate','2026-10-23','createdAt',now(),'updatedAt',now(),'days',
   (select jsonb_agg(jsonb_build_object('date',to_char(date '2026-10-23'+i,'YYYY-MM-DD'),'phase','Audit rest day','workout',null,'meals','[]'::jsonb) order by i) from generate_series(0,6) i));
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 if auth.uid() is distinct from a or current_user<>'authenticated' then raise exception 'AUDIT auth role not applied'; end if;
 rejected:=false;
 begin perform public.bil_smart_plan_read_v1(); exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'AUDIT missing consent was accepted'; end if;
 checks:=checks||jsonb_build_object('consent_required',true);
 perform public.bil_smart_plan_consent_v1(true);
 result:=public.bil_smart_plan_read_v1();
 if result<>jsonb_build_object('revision',0,'payload',null) then raise exception 'AUDIT initial state not empty'; end if;
 checks:=checks||jsonb_build_object('fresh_read',true);
 result:=public.bil_smart_plan_cas_v1(0,payload);
 if result<>jsonb_build_object('revision',1,'payload',payload) or public.bil_smart_plan_read_v1()<>result then
  raise exception 'AUDIT roundtrip readback differs';
 end if;
 checks:=checks||jsonb_build_object('paid_cas_and_readback',true);
 rejected:=false;
 begin perform public.bil_smart_plan_cas_v1(0,payload); exception when sqlstate 'PT409' then rejected:=true; end;
 if not rejected or public.bil_smart_plan_read_v1()<>result then raise exception 'AUDIT stale cursor overwrite'; end if;
 checks:=checks||jsonb_build_object('stale_revision_preserves_state',true);
 checks:=checks||jsonb_build_object('stale_conflict_returns_terminal_http409',true);
 rejected:=false;
 begin perform public.bil_smart_plan_cas_v1(1,jsonb_set(payload,'{ownerId}',to_jsonb(b::text))); exception when check_violation then rejected:=true; end;
 if not rejected or public.bil_smart_plan_read_v1()<>result then raise exception 'AUDIT foreign payload accepted'; end if;
 checks:=checks||jsonb_build_object('foreign_payload_rejected',true);
 rejected:=false;
 begin perform public.bil_smart_plan_cas_v1(1,'{}'); exception when check_violation then rejected:=true; end;
 if not rejected then raise exception 'AUDIT malformed plan accepted'; end if;
 checks:=checks||jsonb_build_object('malformed_payload_rejected',true);
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated')::text,true);
 perform public.bil_smart_plan_consent_v1(true);
 if public.bil_smart_plan_read_v1()<>jsonb_build_object('revision',0,'payload',null)
   or exists(select 1 from public.bil_smart_plan_sync_state where owner_id=a) then raise exception 'AUDIT cross-owner read'; end if;
 checks:=checks||jsonb_build_object('rpc_and_direct_select_owner_isolation',true);
 rejected:=false;
 begin perform public.bil_smart_plan_cas_v1(0,jsonb_set(payload,'{ownerId}',to_jsonb(b::text))); exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'AUDIT free owner wrote a plan'; end if;
 checks:=checks||jsonb_build_object('free_write_denied',true);
 -- The second disposable fixture now exercises the additive payload fields.
 -- Its earlier free-access rejection remains tested before this synthetic grant.
 execute 'reset role';
 insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id)
 values(b,'plan:premium',marker||'-b','closed_test',true,now(),now()+interval '1 hour',marker||'-b');
 execute 'set local role authenticated';
 extended:=jsonb_set(payload,'{ownerId}',to_jsonb(b::text)) || jsonb_build_object(
   'setup',jsonb_build_object('environment','gym','experience','beginner','sessionMinutes',25,'equipment',jsonb_build_array('gym'),'preferredTime','18:30'),
   'changes','[]'::jsonb);
 reviewed:=public.bil_smart_plan_cas_v1(0,extended);
 if reviewed<>jsonb_build_object('revision',1,'payload',extended) or public.bil_smart_plan_read_v1()<>reviewed then
   raise exception 'AUDIT setup roundtrip readback mismatch'; end if;
 checks:=checks||jsonb_build_object('personal_setup_roundtrip_and_owner_readback',true);
 extended:=extended||jsonb_build_object('revision',2,'status','active','changes',jsonb_build_array(
   jsonb_build_object('revision',2,'at',extended->'updatedAt','previousUpdatedAt',extended->'updatedAt',
     'reason','status','previousStatus','draft','beforeDays','[]'::jsonb)));
 reviewed:=public.bil_smart_plan_cas_v1(1,extended);
 if reviewed<>jsonb_build_object('revision',2,'payload',extended) or public.bil_smart_plan_read_v1()<>reviewed then
   raise exception 'AUDIT revision history readback mismatch'; end if;
 checks:=checks||jsonb_build_object('confirmed_revision_journal_roundtrip',true);
 rejected:=false;
 begin perform public.bil_smart_plan_cas_v1(2,jsonb_set(extended,'{changes,0,ownerId}',to_jsonb(a::text)));
 exception when check_violation then rejected:=true; end;
 if not rejected or public.bil_smart_plan_read_v1()<>reviewed then raise exception 'AUDIT foreign journal metadata accepted'; end if;
 checks:=checks||jsonb_build_object('foreign_journal_field_rejected_without_overwrite',true);
 rejected:=false;
 begin perform public.bil_smart_plan_cas_v1(2,jsonb_set(extended,'{setup,serviceRole}','true'));
 exception when check_violation then rejected:=true; end;
 if not rejected or public.bil_smart_plan_read_v1()<>reviewed then raise exception 'AUDIT arbitrary setup metadata accepted'; end if;
 checks:=checks||jsonb_build_object('injected_setup_field_rejected_without_overwrite',true);
 rejected:=false;
 begin perform public.bil_smart_plan_cas_v1(1,extended); exception when sqlstate 'PT409' then rejected:=true; end;
 if not rejected or public.bil_smart_plan_read_v1()<>reviewed then raise exception 'AUDIT revision replay changed the saved journal'; end if;
 checks:=checks||jsonb_build_object('journal_replay_preserves_exact_saved_version',true);
 execute 'reset role';
 update public.bil_entitlements set active=false where owner_id=a and entitlement_id='plan:premium';
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 result:=public.bil_smart_plan_cas_v1(1,null);
 if result<>jsonb_build_object('revision',2,'payload',null) then raise exception 'AUDIT deletion tombstone missing'; end if;
 checks:=checks||jsonb_build_object('deletion_allowed_after_paid_expiry',true);
 perform public.bil_smart_plan_consent_v1(false);
 rejected:=false;
 begin perform public.bil_smart_plan_read_v1(); exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'AUDIT revoked consent still readable'; end if;
 perform public.bil_smart_plan_consent_v1(true);
 if public.bil_smart_plan_read_v1()<>jsonb_build_object('revision',3,'payload',null) then raise exception 'AUDIT revoked data resurrected'; end if;
 checks:=checks||jsonb_build_object('revocation_and_reconsent_preserve_tombstone',true);
 execute 'reset role';
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{}',true);
 execute 'set local role anon';
 rejected:=false;
 begin perform public.bil_smart_plan_read_v1(); exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'AUDIT anonymous RPC accepted'; end if;
 checks:=checks||jsonb_build_object('anonymous_rpc_denied',true);
 execute 'reset role';
 perform set_config('bil.smart_plan_audit_result','PASS',true);
 perform set_config('bil.smart_plan_audit_assertions',checks::text,true);
exception when others then
 get stacked diagnostics error_state=returned_sqlstate,error_message=message_text;
 perform set_config('bil.smart_plan_audit_result','FAIL',true);
 perform set_config('bil.smart_plan_audit_assertions','{}',true);
 perform set_config('bil.smart_plan_audit_failure',jsonb_build_object('sqlstate',error_state,'error',error_message,'checks_reached_before_failure',checks)::text,true);
end
$smart_plan_audit$;
select coalesce(nullif(current_setting('bil.smart_plan_audit_result',true),''),'UNKNOWN') as transaction_result,
 nullif(current_setting('bil.smart_plan_audit_failure',true),'')::jsonb as exact_failure,
 coalesce(nullif(current_setting('bil.smart_plan_audit_assertions',true),'')::jsonb,'{}') as completed_assertions,
 (select count(*) from jsonb_object_keys(coalesce(nullif(current_setting('bil.smart_plan_audit_assertions',true),'')::jsonb,'{}'))) as completed_assertion_count;
rollback;
-- END SEGMENT TRANSACTION

-- BEGIN SEGMENT RESIDUE
with owners as(select array['b1380038-0000-4000-8000-000000000001','b1380038-0000-4000-8000-000000000002']::uuid[] as ids),
inventory as(
 select 'auth.users'::text as table_name,count(*) as synthetic_rows from auth.users,owners where id=any(ids)
 union all select 'auth.identities',count(*) from auth.identities,owners where user_id=any(ids)
 union all select 'public.bil_entitlements',count(*) from public.bil_entitlements,owners where owner_id=any(ids)
 union all select 'public.bil_smart_plan_sync_state',count(*) from public.bil_smart_plan_sync_state,owners where owner_id=any(ids)
 union all select 'bil_smart_plan_private.consent',count(*) from bil_smart_plan_private.consent,owners where owner_id=any(ids)
)
select count(*) as inventoried_table_count,bool_and(synthetic_rows=0) as zero_synthetic_rows,
 jsonb_agg(to_jsonb(inventory) order by table_name) as table_counts from inventory;
-- END SEGMENT RESIDUE
