-- DRAFT / NOT EXECUTED. Root review and exact-SHA Targeted/Candidate gates first.
-- Requires permanently applied, byte-verified ai_consent_receipt_completion_order_v1
-- after cloud_sync_authoritative_consent_boundary_v1. A migration name alone is
-- NOT approved-byte evidence. Function bodies/ACL/owner/RLS guard below is required.
-- Three independent calls: PRECHECK -> TRANSACTION -> RESIDUE. Retain receipts
-- externally; both inventories require3 tables/zero_synthetic_rows=true. Execute
-- RESIDUE independently even if transaction/transport fails. Also require the
-- parent's canonical68 supplement transformed to these exact2 IDs/all3 emails;
-- that supplement omits consent_receipts, so it must NOT replace this inventory.
-- TRANSACTION requires explicit PASS +18 true assertions and unconditionally
-- ends ROLLBACK. No COMMIT, DDL, helper swapping, grants, real user/password/Auth
-- HTTP/provider/network/health/context/Storage mutation or fake receipt timestamps.
-- SQL Auth/JWT principal simulation is NOT real login/JWT-validation evidence.
-- service_role is used ONLY for existing consent helper/receipt SELECTs; all
-- grants/revokes are the genuine ordinary-owner bil_record_consent RPC.
-- Known writes:2 synthetic auth.users and their consent receipts only. Guard
-- requires zero noninternal Auth/receipt triggers before seed. Other side effects
-- or new triggers abort. No existing identities or personal row values printed.
-- Scope: sequential current readback/strict disclosure version/isolation, NOT a
-- two-session Production race/tie guarantee or cancellation of admitted AI bytes.
-- Local PG concurrency proof is separate and must not be promoted to Production.
-- Parent must fresh-check current runtime schema/security before executing.
--
-- BEGIN SEGMENT PRECHECK
with owners as(select array['babf0387-b04c-4769-8dcb-27b1e058eab8','7cc4b028-1bf3-482a-bbbc-8505414cf0ae']::uuid[] as ids),
inventory as(
 select 'auth.users'::text as table_name,(select count(*) from auth.users) as total_rows,
   (select count(*) from auth.users t where t.id=any(owners.ids)
     or t.email in('bil_ai_receipt_rollback_20261004_babf0387@example.invalid','bil_ai_receipt_rollback_20261004_babf0387-a@example.invalid','bil_ai_receipt_rollback_20261004_babf0387-b@example.invalid')
     or t.raw_user_meta_data->>'audit_marker'='bil_ai_receipt_rollback_20261004_babf0387') as synthetic_rows from owners
 union all select 'auth.identities',(select count(*) from auth.identities),
   (select count(*) from auth.identities t where t.user_id=any(owners.ids)
     or t.identity_data->>'email' in('bil_ai_receipt_rollback_20261004_babf0387@example.invalid','bil_ai_receipt_rollback_20261004_babf0387-a@example.invalid','bil_ai_receipt_rollback_20261004_babf0387-b@example.invalid')) from owners
 union all select 'public.bil_consent_receipts',(select count(*) from public.bil_consent_receipts),
   (select count(*) from public.bil_consent_receipts t where t.user_id=any(owners.ids)) from owners
)
select statement_timestamp() as readback_at,count(*) as inventoried_table_count,
 bool_and(synthetic_rows=0) as zero_synthetic_rows,
 jsonb_agg(to_jsonb(inventory) order by table_name) as table_counts from inventory;
-- END SEGMENT PRECHECK

-- BEGIN SEGMENT TRANSACTION
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
do $ai_receipt_audit$
declare
 v_a constant uuid:='babf0387-b04c-4769-8dcb-27b1e058eab8';
 v_b constant uuid:='7cc4b028-1bf3-482a-bbbc-8505414cf0ae';
 v_marker constant text:='bil_ai_receipt_rollback_20261004_babf0387';
 v_checks jsonb:='{}'::jsonb;
 v_result jsonb;
 v_vision boolean;
 v_rejected boolean;
 v_error_state text; v_error_message text; v_error_context text;
begin
 if (select count(*) from supabase_migrations.schema_migrations
      where name='ai_consent_receipt_completion_order_v1')<>1
    or (select count(*) from supabase_migrations.schema_migrations
      where name='cloud_sync_authoritative_consent_boundary_v1')<>1
    or (select md5(prosrc) from pg_proc where oid='public.bil_record_consent(text,text,boolean)'::regprocedure)
      is distinct from 'd6190a543d5c621d3f781d20c14e3c68'
    or (select md5(prosrc) from pg_proc where oid='public.bil_get_remote_ai_consent()'::regprocedure)
      is distinct from '518c8175d8908dd89e8a5323a5e89d1e'
    or (select md5(prosrc) from pg_proc where oid='public.bil_has_remote_ai_consent(uuid)'::regprocedure)
      is distinct from '9f6245b81ab1f40e2bb7ddc5d05ff748'
    or (select md5(prosrc) from pg_proc where oid='public.bil_sync_records(text,bigint,jsonb)'::regprocedure)
      is distinct from '47aebaf2b294a889e142c6eae145335d'
    or (select count(*) from pg_proc p where p.oid in
       ('public.bil_record_consent(text,text,boolean)'::regprocedure,
        'public.bil_get_remote_ai_consent()'::regprocedure,
        'public.bil_has_remote_ai_consent(uuid)'::regprocedure)
       and p.proowner='postgres'::regrole and p.proconfig=array['search_path=public, pg_temp'])<>3
    or (select prosecdef from pg_proc where oid='public.bil_get_remote_ai_consent()'::regprocedure)
      is distinct from false
    or (select count(*) from pg_proc p where p.oid in
       ('public.bil_record_consent(text,text,boolean)'::regprocedure,
        'public.bil_has_remote_ai_consent(uuid)'::regprocedure) and p.prosecdef)<>2
    or not has_function_privilege('authenticated','public.bil_record_consent(text,text,boolean)','EXECUTE')
    or not has_function_privilege('authenticated','public.bil_get_remote_ai_consent()','EXECUTE')
    or not has_function_privilege('service_role','public.bil_has_remote_ai_consent(uuid)','EXECUTE')
    or has_function_privilege('anon','public.bil_record_consent(text,text,boolean)','EXECUTE')
    or has_function_privilege('anon','public.bil_get_remote_ai_consent()','EXECUTE')
    or has_function_privilege('anon','public.bil_has_remote_ai_consent(uuid)','EXECUTE')
    or has_function_privilege('authenticated','public.bil_has_remote_ai_consent(uuid)','EXECUTE')
    or has_table_privilege('authenticated','public.bil_consent_receipts','INSERT,UPDATE,DELETE')
    or (select relrowsecurity from pg_class where oid='public.bil_consent_receipts'::regclass)
      is distinct from true then
  raise exception 'AUDIT approved AI writer/readers/migration/ACL/RLS prerequisite not met';
 end if;
 v_checks:=v_checks||jsonb_build_object('exact_approved_function_migration_acl_rls_prerequisites',true);

 if exists(select 1 from auth.users where id in(v_a,v_b)
       or email in(v_marker||'@example.invalid',v_marker||'-a@example.invalid',v_marker||'-b@example.invalid')
       or raw_user_meta_data->>'audit_marker'=v_marker)
    or exists(select 1 from auth.identities where user_id in(v_a,v_b)
       or identity_data->>'email' in(v_marker||'@example.invalid',v_marker||'-a@example.invalid',v_marker||'-b@example.invalid'))
    or exists(select 1 from public.bil_consent_receipts where user_id in(v_a,v_b)) then
  raise exception 'AUDIT synthetic identifiers already exist; refuse reuse';
 end if;
 v_checks:=v_checks||jsonb_build_object('synthetic_identifiers_absent',true);

 if exists(select 1 from pg_trigger where tgrelid in
      ('auth.users'::regclass,'public.bil_consent_receipts'::regclass) and not tgisinternal) then
  raise exception 'AUDIT external trigger inventory drift';
 end if;
 v_checks:=v_checks||jsonb_build_object('zero_external_auth_receipt_triggers',true);

 insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
    raw_app_meta_data,raw_user_meta_data,is_anonymous) values
   (v_a,'authenticated','authenticated',v_marker||'-a@example.invalid',now(),now(),now(),
    '{"provider":"email","providers":["email"]}',jsonb_build_object('audit_marker',v_marker),false),
   (v_b,'authenticated','authenticated',v_marker||'-b@example.invalid',now(),now(),now(),
    '{"provider":"email","providers":["email"]}',jsonb_build_object('audit_marker',v_marker),false);
 execute 'reset role';
 perform set_config('request.jwt.claim.sub',v_a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 if current_user<>'authenticated' or auth.uid() is distinct from v_a then
  raise exception 'AUDIT ordinary owner principal mismatch';
 end if;

 v_checks:=v_checks||jsonb_build_object('ordinary_owner_principal',true);

 v_result:=public.bil_get_remote_ai_consent();
 if v_result is distinct from jsonb_build_object('granted',false,'policy_version','1') then
  raise exception 'AUDIT exact current-owner AI readback mismatch';
 end if;
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service reader role mismatch'; end if;
 if public.bil_has_remote_ai_consent(v_a) is distinct from false then
  raise exception 'AUDIT service current-policy AI authority mismatch';
 end if;
 execute 'reset role'; execute 'set local role authenticated';
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service Vision reader role mismatch'; end if;
 -- Exact analyze-meal/index.ts latest-row ordering + consent.ts policy1 predicate.
 -- This reads synthetic receipts only; NOT an Edge/provider/HTTP execution.
 select coalesce((select r.granted and r.policy_version='1'
   from public.bil_consent_receipts r
   where r.user_id=v_a and r.purpose='meal_vision_ai'
   order by r.recorded_at desc limit 1),false) into v_vision;
 if v_vision is distinct from false then raise exception 'AUDIT latest Vision policy1 authority mismatch'; end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('no_history_all_ai_authority_closed',true);

 perform public.bil_record_consent('remote_ai','3',true);
 v_result:=public.bil_get_remote_ai_consent();
 if v_result is distinct from jsonb_build_object('granted',true,'policy_version','3') then
  raise exception 'AUDIT exact current-owner AI readback mismatch';
 end if;
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service reader role mismatch'; end if;
 if public.bil_has_remote_ai_consent(v_a) is distinct from true then
  raise exception 'AUDIT service current-policy AI authority mismatch';
 end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('remote_current3_grant_actual_getter_and_service_authority',true);

 perform public.bil_record_consent('remote_ai','3',false);
 v_result:=public.bil_get_remote_ai_consent();
 if v_result is distinct from jsonb_build_object('granted',false,'policy_version','3') then
  raise exception 'AUDIT exact current-owner AI readback mismatch';
 end if;
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service reader role mismatch'; end if;
 if public.bil_has_remote_ai_consent(v_a) is distinct from false then
  raise exception 'AUDIT service current-policy AI authority mismatch';
 end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('remote_same3_revoke_actual_getter_and_service_denied',true);

 perform public.bil_record_consent('remote_ai','3',true);
 perform public.bil_record_consent('remote_ai','other-policy',false);
 v_result:=public.bil_get_remote_ai_consent();
 if v_result is distinct from jsonb_build_object('granted',false,'policy_version','other-policy') then
  raise exception 'AUDIT exact current-owner AI readback mismatch';
 end if;
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service reader role mismatch'; end if;
 if public.bil_has_remote_ai_consent(v_a) is distinct from false then
  raise exception 'AUDIT service current-policy AI authority mismatch';
 end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('remote_latest_other_policy_denial_wins',true);

 perform public.bil_record_consent('remote_ai','other-policy',true);
 v_result:=public.bil_get_remote_ai_consent();
 if v_result is distinct from jsonb_build_object('granted',true,'policy_version','other-policy') then
  raise exception 'AUDIT exact current-owner AI readback mismatch';
 end if;
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service reader role mismatch'; end if;
 if public.bil_has_remote_ai_consent(v_a) is distinct from false then
  raise exception 'AUDIT service current-policy AI authority mismatch';
 end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('remote_latest_unknown_policy_grant_does_not_authorize3',true);

 perform public.bil_record_consent('remote_ai','3',true);
 v_result:=public.bil_get_remote_ai_consent();
 if v_result is distinct from jsonb_build_object('granted',true,'policy_version','3') then
  raise exception 'AUDIT exact current-owner AI readback mismatch';
 end if;
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service reader role mismatch'; end if;
 if public.bil_has_remote_ai_consent(v_a) is distinct from true then
  raise exception 'AUDIT service current-policy AI authority mismatch';
 end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('remote_current3_regrant_restores_authority',true);

 execute 'reset role';
 perform set_config('request.jwt.claim.sub',v_b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 if current_user<>'authenticated' or auth.uid() is distinct from v_b then
  raise exception 'AUDIT ordinary owner principal mismatch';
 end if;

 if public.bil_get_remote_ai_consent() is distinct from jsonb_build_object('granted',false,'policy_version','1') then
  raise exception 'AUDIT ownerB getter leaked ownerA receipt'; end if;
 perform public.bil_record_consent('remote_ai','2',false);
 if public.bil_get_remote_ai_consent() is distinct from jsonb_build_object('granted',false,'policy_version','2') then
  raise exception 'AUDIT ownerB ordinary receipt readback mismatch'; end if;
 execute 'reset role'; execute 'set local role service_role';
 if public.bil_has_remote_ai_consent(v_b) is distinct from false
    or public.bil_has_remote_ai_consent(v_a) is distinct from true then
  raise exception 'AUDIT foreign owner changed/is authorized by ownerA consent'; end if;
 execute 'reset role';
 perform set_config('request.jwt.claim.sub',v_a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 if current_user<>'authenticated' or auth.uid() is distinct from v_a then
  raise exception 'AUDIT ordinary owner principal mismatch';
 end if;

 v_checks:=v_checks||jsonb_build_object('foreign_owner_getter_writer_and_service_isolation',true);

 perform public.bil_record_consent('meal_vision_ai','1',true);
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service Vision reader role mismatch'; end if;
 -- Exact analyze-meal/index.ts latest-row ordering + consent.ts policy1 predicate.
 -- This reads synthetic receipts only; NOT an Edge/provider/HTTP execution.
 select coalesce((select r.granted and r.policy_version='1'
   from public.bil_consent_receipts r
   where r.user_id=v_a and r.purpose='meal_vision_ai'
   order by r.recorded_at desc limit 1),false) into v_vision;
 if v_vision is distinct from true then raise exception 'AUDIT latest Vision policy1 authority mismatch'; end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('vision_current1_grant_latest_actual_selector',true);

 perform public.bil_record_consent('meal_vision_ai','1',false);
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service Vision reader role mismatch'; end if;
 -- Exact analyze-meal/index.ts latest-row ordering + consent.ts policy1 predicate.
 -- This reads synthetic receipts only; NOT an Edge/provider/HTTP execution.
 select coalesce((select r.granted and r.policy_version='1'
   from public.bil_consent_receipts r
   where r.user_id=v_a and r.purpose='meal_vision_ai'
   order by r.recorded_at desc limit 1),false) into v_vision;
 if v_vision is distinct from false then raise exception 'AUDIT latest Vision policy1 authority mismatch'; end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('vision_same1_revoke_latest_actual_selector',true);

 perform public.bil_record_consent('meal_vision_ai','1',true);
 perform public.bil_record_consent('meal_vision_ai','other-policy',false);
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service Vision reader role mismatch'; end if;
 -- Exact analyze-meal/index.ts latest-row ordering + consent.ts policy1 predicate.
 -- This reads synthetic receipts only; NOT an Edge/provider/HTTP execution.
 select coalesce((select r.granted and r.policy_version='1'
   from public.bil_consent_receipts r
   where r.user_id=v_a and r.purpose='meal_vision_ai'
   order by r.recorded_at desc limit 1),false) into v_vision;
 if v_vision is distinct from false then raise exception 'AUDIT latest Vision policy1 authority mismatch'; end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('vision_latest_other_policy_denial_wins',true);

 perform public.bil_record_consent('meal_vision_ai','other-policy',true);
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service Vision reader role mismatch'; end if;
 -- Exact analyze-meal/index.ts latest-row ordering + consent.ts policy1 predicate.
 -- This reads synthetic receipts only; NOT an Edge/provider/HTTP execution.
 select coalesce((select r.granted and r.policy_version='1'
   from public.bil_consent_receipts r
   where r.user_id=v_a and r.purpose='meal_vision_ai'
   order by r.recorded_at desc limit 1),false) into v_vision;
 if v_vision is distinct from false then raise exception 'AUDIT latest Vision policy1 authority mismatch'; end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('vision_latest_unknown_policy_grant_does_not_authorize1',true);

 perform public.bil_record_consent('meal_vision_ai','1',true);
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service Vision reader role mismatch'; end if;
 -- Exact analyze-meal/index.ts latest-row ordering + consent.ts policy1 predicate.
 -- This reads synthetic receipts only; NOT an Edge/provider/HTTP execution.
 select coalesce((select r.granted and r.policy_version='1'
   from public.bil_consent_receipts r
   where r.user_id=v_a and r.purpose='meal_vision_ai'
   order by r.recorded_at desc limit 1),false) into v_vision;
 if v_vision is distinct from true then raise exception 'AUDIT latest Vision policy1 authority mismatch'; end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('vision_current1_regrant_restores_authority',true);

 v_rejected:=false;
 begin
  perform public.bil_record_consent('remote_ai',' ',true);
 exception when others then
  if sqlstate<>'P0001' or sqlerrm<>'invalid_consent' then raise; end if;
  v_rejected:=true;
 end;
 if not v_rejected then raise exception 'AUDIT invalid consent was accepted'; end if;
 v_result:=public.bil_get_remote_ai_consent();
 if v_result is distinct from jsonb_build_object('granted',true,'policy_version','3') then
  raise exception 'AUDIT exact current-owner AI readback mismatch';
 end if;
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service reader role mismatch'; end if;
 if public.bil_has_remote_ai_consent(v_a) is distinct from true then
  raise exception 'AUDIT service current-policy AI authority mismatch';
 end if;
 execute 'reset role'; execute 'set local role authenticated';
 execute 'reset role'; execute 'set local role service_role';
 if current_user<>'service_role' then raise exception 'AUDIT service Vision reader role mismatch'; end if;
 -- Exact analyze-meal/index.ts latest-row ordering + consent.ts policy1 predicate.
 -- This reads synthetic receipts only; NOT an Edge/provider/HTTP execution.
 select coalesce((select r.granted and r.policy_version='1'
   from public.bil_consent_receipts r
   where r.user_id=v_a and r.purpose='meal_vision_ai'
   order by r.recorded_at desc limit 1),false) into v_vision;
 if v_vision is distinct from true then raise exception 'AUDIT latest Vision policy1 authority mismatch'; end if;
 execute 'reset role'; execute 'set local role authenticated';

 v_checks:=v_checks||jsonb_build_object('invalid_consent_fails_without_changing_existing_purpose_authorities',true);

 execute 'reset role';
 if (select count(*) from public.bil_consent_receipts where user_id=v_a)<>4
    or (select count(*) from public.bil_consent_receipts where user_id=v_b)<>1
    or exists(select 1 from public.bil_consent_receipts where user_id in(v_a,v_b)
       and purpose not in('remote_ai','meal_vision_ai'))
    or (select count(*) from auth.users where id in(v_a,v_b))<>2
    or exists(select 1 from auth.identities where user_id in(v_a,v_b)) then
  raise exception 'AUDIT synthetic owner receipt/idempotent-upsert surface mismatch';
 end if;
 v_checks:=v_checks||jsonb_build_object('exact_owner_receipt_upsert_and_identity_surface',true);

 if (select count(*) from jsonb_object_keys(v_checks))<>18
    or exists(select 1 from jsonb_each(v_checks) where value is distinct from 'true'::jsonb) then
  raise exception 'AUDIT incomplete AI receipt assertion inventory';
 end if;
 perform set_config('bil.ai_receipt_audit_assertions',v_checks::text,true);
 perform set_config('bil.ai_receipt_audit_failure','',true);
 perform set_config('bil.ai_receipt_audit_result','PASS',true);
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{}',true);
exception when others or query_canceled or assert_failure then
 -- Entire body writes/role settings roll back before reporting this FAILURE.
 get stacked diagnostics v_error_state=returned_sqlstate,
  v_error_message=message_text,v_error_context=pg_exception_context;
 perform set_config('bil.ai_receipt_audit_result','FAIL',true);
 perform set_config('bil.ai_receipt_audit_assertions','{}',true);
 perform set_config('bil.ai_receipt_audit_failure',jsonb_build_object('sqlstate',v_error_state,
  'error',v_error_message,'stack_context',v_error_context,
  'checks_reached_before_failure',v_checks)::text,true);
end
$ai_receipt_audit$;
select statement_timestamp() as assertions_completed_at,
 coalesce(nullif(current_setting('bil.ai_receipt_audit_result',true),''),'UNKNOWN') as transaction_result,
 nullif(current_setting('bil.ai_receipt_audit_failure',true),'')::jsonb as exact_failure,
 coalesce(nullif(current_setting('bil.ai_receipt_audit_assertions',true),'')::jsonb,'{}') as completed_assertions,
 (select count(*) from jsonb_object_keys(coalesce(nullif(current_setting('bil.ai_receipt_audit_assertions',true),'')::jsonb,'{}'))) as completed_assertion_count;
rollback;
-- END SEGMENT TRANSACTION

-- BEGIN SEGMENT RESIDUE
with owners as(select array['babf0387-b04c-4769-8dcb-27b1e058eab8','7cc4b028-1bf3-482a-bbbc-8505414cf0ae']::uuid[] as ids),
inventory as(
 select 'auth.users'::text as table_name,(select count(*) from auth.users) as total_rows,
   (select count(*) from auth.users t where t.id=any(owners.ids)
     or t.email in('bil_ai_receipt_rollback_20261004_babf0387@example.invalid','bil_ai_receipt_rollback_20261004_babf0387-a@example.invalid','bil_ai_receipt_rollback_20261004_babf0387-b@example.invalid')
     or t.raw_user_meta_data->>'audit_marker'='bil_ai_receipt_rollback_20261004_babf0387') as synthetic_rows from owners
 union all select 'auth.identities',(select count(*) from auth.identities),
   (select count(*) from auth.identities t where t.user_id=any(owners.ids)
     or t.identity_data->>'email' in('bil_ai_receipt_rollback_20261004_babf0387@example.invalid','bil_ai_receipt_rollback_20261004_babf0387-a@example.invalid','bil_ai_receipt_rollback_20261004_babf0387-b@example.invalid')) from owners
 union all select 'public.bil_consent_receipts',(select count(*) from public.bil_consent_receipts),
   (select count(*) from public.bil_consent_receipts t where t.user_id=any(owners.ids)) from owners
)
select statement_timestamp() as readback_at,count(*) as inventoried_table_count,
 bool_and(synthetic_rows=0) as zero_synthetic_rows,
 jsonb_agg(to_jsonb(inventory) order by table_name) as table_counts from inventory;
-- END SEGMENT RESIDUE
