-- DRAFT / NOT EXECUTED. Root review and exact-SHA QA required before any call.
-- This is NOT a migration, app build, native transaction or Auth login proof.
-- After source-approved cloud_sync_authoritative_consent_boundary_v1 is applied,
-- ROOT must independently compare actual migration statements and body/policy/
-- grant identities to approved source. Migration NAME is NOT byte identity.
-- Three independent tool calls: PRECHECK -> TRANSACTION -> RESIDUE. Retain
-- PRECHECK externally; require6 inventoried tables / zero synthetic. TRANSACTION
-- requires explicit PASS +18 true assertions; tool/transport errors remain FAIL.
-- Always execute independent RESIDUE, even after failure, require6/zero. Root
-- should also include these2 UUIDs/marker in its full release-residue inventory.
-- No session reuse, helper/temp/schema DDL, new grants, COMMIT, existing-user
-- edits, real credentials, Auth HTTP, health data, provider tokens, pushes,
-- Storage HTTP, Vault/key requests, native transaction or outbound network.
-- Only2 never-existing SQL Auth rows, versioned receipts and synthetic settings
-- envelopes/device/op via genuine owner RPCs, ALL in a rollback transaction.
-- No usable password. Claim simulation does NOT prove password/Auth validation.
-- Auth-user noninternal triggers must still be absent, cloud only has canonical
-- touch trigger; guard aborts before seeding if that inspected surface changes.
-- Default READ COMMITTED RPC lock races/ties were exercised in local PG17 ONLY.
-- Direct SELECT is statement-snapshot consent; cannot unsend earlier read bytes.
-- These6 tables are the known mutated surface plus Auth identity defense. No
-- claim all real-user global counts stay equal under concurrent traffic.
-- Sequence values may advance on rollback; gaps are not synthetic data rows.
-- Owner-scope aggregate predicates never serialize key/payload/token values.
-- Existing cloud key recovery/custody APIs and encryption are NOT certified.
--
-- BEGIN SEGMENT PRECHECK
with owners as(select array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c','977a0ce5-c8a2-4046-b3db-1553f92daaab']::uuid[] as ids),
inventory as(
 select 'auth.users'::text as table_name,(select count(*) from auth.users) as total_rows,
   (select count(*) from auth.users t where t.id=any(owners.ids) or t.email in('bil_cloud_rollback_20261004_c56534f4-a@example.invalid','bil_cloud_rollback_20261004_c56534f4-b@example.invalid')) as synthetic_rows from owners
 union all select 'public.bil_cloud_devices',(select count(*) from public.bil_cloud_devices),
   (select count(*) from public.bil_cloud_devices t where t.owner_id=any(owners.ids)) from owners
 union all select 'public.bil_cloud_records',(select count(*) from public.bil_cloud_records),
   (select count(*) from public.bil_cloud_records t where t.owner_id=any(owners.ids) or t.record_id='bil_cloud_rollback_20261004_c56534f4') from owners
 union all select 'public.bil_cloud_operations',(select count(*) from public.bil_cloud_operations),
   (select count(*) from public.bil_cloud_operations t where t.owner_id=any(owners.ids) or t.operation_id='bil_cloud_rollback_20261004_c56534f4') from owners
 union all select 'public.bil_consent_receipts',(select count(*) from public.bil_consent_receipts),
   (select count(*) from public.bil_consent_receipts t where t.user_id=any(owners.ids)) from owners
 union all select 'auth.identities',(select count(*) from auth.identities),
   (select count(*) from auth.identities t where t.user_id=any(owners.ids)) from owners
)
select statement_timestamp() as readback_at,count(*) as inventoried_table_count,
 bool_and(synthetic_rows=0) as zero_synthetic_rows,
 jsonb_agg(to_jsonb(inventory) order by table_name) as table_counts from inventory;
-- END SEGMENT PRECHECK

-- BEGIN SEGMENT TRANSACTION
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
do $cloud_audit$
declare
 v_a constant uuid:='c56534f4-b96f-498c-99e4-3a60f9ac2c9c';
 v_b constant uuid:='977a0ce5-c8a2-4046-b3db-1553f92daaab';
 v_marker constant text:='bil_cloud_rollback_20261004_c56534f4';
 v_device constant text:='bil_cloud_rollback_20261004_c56534f4-device';
 v_checks jsonb:='{}'::jsonb;
 v_operation jsonb;
 v_result jsonb;
 v_rejected boolean;
 v_before_seen timestamptz;
 v_error_state text; v_error_message text; v_error_context text;
begin
 if (select count(*) from supabase_migrations.schema_migrations
     where name='cloud_sync_authoritative_consent_boundary_v1')<>1
    or (select md5(prosrc) from pg_proc where oid='public.bil_sync_records(text,bigint,jsonb)'::regprocedure)
      is distinct from '47aebaf2b294a889e142c6eae145335d'
    or (select md5(prosrc) from pg_proc where oid='public.bil_record_consent(text,text,boolean)'::regprocedure)
      is distinct from '7c99240c0acfa473bc2765cee540e609'
    or (select count(*) from pg_policy where polname in
      ('bil_cloud_records_current_consent_select_v1','bil_cloud_operations_current_consent_select_v1')
      and not polpermissive and polcmd='r' and polroles=array['authenticated'::regrole::oid])<>2
    or has_function_privilege('anon','public.bil_sync_records(text,bigint,jsonb)','EXECUTE')
    or has_function_privilege('anon','public.bil_record_consent(text,text,boolean)','EXECUTE')
    or has_table_privilege('authenticated','public.bil_cloud_records','INSERT,UPDATE,DELETE')
    or has_table_privilege('authenticated','public.bil_cloud_operations','INSERT,UPDATE,DELETE') then
  raise exception 'AUDIT cloud approved migration/body/policy/grant prerequisite not met';
 end if;
 v_checks:=v_checks||jsonb_build_object('exact_function_migration_acl_prerequisites',true);
 if exists(select 1 from auth.users where id in(v_a,v_b)
   or email in(v_marker||'-a@example.invalid',v_marker||'-b@example.invalid'))
   or exists(select 1 from public.bil_cloud_records where owner_id in(v_a,v_b) or record_id=v_marker)
   or exists(select 1 from public.bil_cloud_devices where owner_id in(v_a,v_b))
   or exists(select 1 from public.bil_cloud_operations where owner_id in(v_a,v_b) or operation_id=v_marker)
   or exists(select 1 from public.bil_consent_receipts where user_id in(v_a,v_b)) then
  raise exception 'AUDIT synthetic identifiers already exist; refuse reuse';
 end if;
 v_checks:=v_checks||jsonb_build_object('synthetic_identifiers_absent',true);
 if exists(select 1 from pg_trigger where tgrelid='auth.users'::regclass and not tgisinternal)
    or (select count(*) from pg_trigger where tgrelid in
      ('public.bil_cloud_records'::regclass,'public.bil_cloud_operations'::regclass,
       'public.bil_cloud_devices'::regclass,'public.bil_consent_receipts'::regclass)
      and not tgisinternal)<>1
    or not exists(select 1 from pg_trigger t join pg_proc p on p.oid=t.tgfoid
      where t.tgrelid='public.bil_cloud_records'::regclass and t.tgname='bil_cloud_records_touch'
      and not t.tgisinternal and p.oid='public.bil_set_server_updated_at()'::regprocedure
      and md5(p.prosrc)='45a2952c812f8141f848aebe6b79ef45') then
  raise exception 'AUDIT external-boundary trigger inventory drift';
 end if;
 v_checks:=v_checks||jsonb_build_object('external_trigger_inventory',true);
 insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
    raw_app_meta_data,raw_user_meta_data,is_anonymous) values
   (v_a,'authenticated','authenticated',v_marker||'-a@example.invalid',now(),now(),now(),
    '{"provider":"email","providers":["email"]}',jsonb_build_object('audit_marker',v_marker),false),
   (v_b,'authenticated','authenticated',v_marker||'-b@example.invalid',now(),now(),now(),
    '{"provider":"email","providers":["email"]}',jsonb_build_object('audit_marker',v_marker),false);
 v_operation:=jsonb_build_array(jsonb_build_object('operation_id',v_marker,'mutation','upsert',
   'record',jsonb_build_object('entity_kind','settings','record_id',v_marker,
    'revision_device_id',v_device,'revision_sequence',1,'updated_at',clock_timestamp(),
    'deleted_at',null,'schema_version',1,'payload',jsonb_build_object('fixture_marker',v_marker))));
 perform set_config('request.jwt.claim.sub',v_a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 if current_user<>'authenticated' or auth.uid() is distinct from v_a then
  raise exception 'AUDIT ordinary owner principal mismatch';
 end if;
 v_checks:=v_checks||jsonb_build_object('ordinary_owner_principal',true);
 v_rejected:=false;
 begin
  perform public.bil_sync_records(v_device,0,v_operation);
 exception when insufficient_privilege then
  if sqlerrm<>'cloud_sync_consent_required' then raise; end if; v_rejected:=true;
 end;
 if not v_rejected then raise exception 'AUDIT no-consent write allowed'; end if;
 v_checks:=v_checks||jsonb_build_object('no_consent_rpc_write_denied',true);
 execute 'reset role';
 if exists(select 1 from public.bil_cloud_devices where owner_id=v_a)
    or exists(select 1 from public.bil_cloud_records where owner_id=v_a)
    or exists(select 1 from public.bil_cloud_operations where owner_id=v_a) then
  raise exception 'AUDIT denied RPC mutated cloud state';
 end if;
 v_checks:=v_checks||jsonb_build_object('no_consent_zero_remote_mutation',true);
 execute 'set local role authenticated';
 perform public.bil_record_consent('cloud_sync','1',true);
 if not exists(select 1 from public.bil_consent_receipts
    where user_id=v_a and purpose='cloud_sync' and policy_version='1' and granted) then
  raise exception 'AUDIT owner consent receipt readback missing';
 end if;
 v_checks:=v_checks||jsonb_build_object('exact_owner_consent_readback',true);
 v_result:=public.bil_sync_records(v_device,0,v_operation);
 if v_result->'acknowledged' is distinct from jsonb_build_array(v_marker)
    or jsonb_array_length(v_result->'records') is distinct from 1
    or v_result->'records'->0->>'owner_id' is distinct from v_a::text
    or (v_result->>'cursor') is null or (v_result->>'cursor')::bigint<=0 then
  raise exception 'AUDIT permitted write receipt mismatch'; end if;
 v_checks:=v_checks||jsonb_build_object('permitted_write_authoritative_owner_ack',true);
 v_result:=public.bil_sync_records(v_device,0,'[]');
 if jsonb_array_length(v_result->'records') is distinct from 1 then raise exception 'AUDIT permitted RPC read incomplete'; end if;
 v_checks:=v_checks||jsonb_build_object('permitted_rpc_read',true);
 if (select count(*) from public.bil_cloud_records)<>1 then raise exception 'AUDIT permitted direct owner read incorrect'; end if;
 v_checks:=v_checks||jsonb_build_object('permitted_direct_owner_read',true);
 perform set_config('request.jwt.claim.sub',v_b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b,'role','authenticated')::text,true);
 perform public.bil_record_consent('cloud_sync','1',true);
 if exists(select 1 from public.bil_cloud_records) or exists(select 1 from public.bil_cloud_operations) then
  raise exception 'AUDIT consented foreign owner can read ownerA records/ops';
 end if;
 v_checks:=v_checks||jsonb_build_object('consented_foreign_owner_isolated',true);
 perform set_config('request.jwt.claim.sub',v_a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a,'role','authenticated')::text,true);
 perform public.bil_record_consent('cloud_sync','1',false);
 select last_seen_at into strict v_before_seen from public.bil_cloud_devices where owner_id=v_a and device_id=v_device;
 v_rejected:=false;
 begin
  perform public.bil_sync_records(v_device,0,v_operation);
 exception when insufficient_privilege then
  if sqlerrm<>'cloud_sync_consent_required' then raise; end if; v_rejected:=true;
 end;
 if not v_rejected then raise exception 'AUDIT revoked replay/write allowed'; end if;
 begin
  perform public.bil_sync_records(v_device,0,'[]');
  raise exception 'AUDIT revoked RPC read allowed';
 exception when insufficient_privilege then
  if sqlerrm<>'cloud_sync_consent_required' then raise; end if;
 end;
 v_checks:=v_checks||jsonb_build_object('same_version_revoke_rpc_read_write_denied',true);
 if exists(select 1 from public.bil_cloud_records) or exists(select 1 from public.bil_cloud_operations) then
  raise exception 'AUDIT revoked direct read exposed rows';
 end if;
 v_checks:=v_checks||jsonb_build_object('revoked_direct_rows_hidden',true);
 if (select last_seen_at from public.bil_cloud_devices where owner_id=v_a and device_id=v_device)
    is distinct from v_before_seen then raise exception 'AUDIT revoked call touched device'; end if;
 v_checks:=v_checks||jsonb_build_object('revoked_device_last_seen_unchanged',true);
 perform public.bil_record_consent('cloud_sync','1',true);
 perform public.bil_record_consent('cloud_sync','other-policy',false);
 begin
  perform public.bil_sync_records(v_device,0,'[]');
  raise exception 'AUDIT latest other-version denial did not win';
 exception when insufficient_privilege then
  if sqlerrm<>'cloud_sync_consent_required' then raise; end if;
 end;
 v_checks:=v_checks||jsonb_build_object('latest_cross_version_denial_wins',true);
 perform public.bil_record_consent('cloud_sync','other-policy',true);
 begin
  perform public.bil_sync_records(v_device,0,'[]');
  raise exception 'AUDIT unknown-version grant authorizes current disclosure';
 exception when insufficient_privilege then
  if sqlerrm<>'cloud_sync_consent_required' then raise; end if;
 end;
 v_checks:=v_checks||jsonb_build_object('latest_unknown_version_grant_denied',true);
 perform public.bil_record_consent('cloud_sync','1',true);
 v_result:=public.bil_sync_records(v_device,0,'[]');
 if jsonb_array_length(v_result->'records') is distinct from 1 or (select count(*) from public.bil_cloud_records)<>1 then
  raise exception 'AUDIT exact current regrant does not restore owner access';
 end if;
 v_checks:=v_checks||jsonb_build_object('current_version_regrant_works',true);
 v_result:=public.bil_sync_records(v_device,0,v_operation);
 if v_result->'acknowledged' is distinct from jsonb_build_array(v_marker)
    or (select count(*) from public.bil_cloud_records)<>1
    or (select count(*) from public.bil_cloud_operations)<>1 then
  raise exception 'AUDIT original idempotency changed';
 end if;
 v_checks:=v_checks||jsonb_build_object('original_idempotency_preserved',true);
 execute 'reset role';
 if (select count(*) from jsonb_object_keys(v_checks))<>18
    or exists(select 1 from jsonb_each(v_checks) where value is distinct from 'true'::jsonb) then
  raise exception 'AUDIT incomplete cloud assertion inventory';
 end if;
 perform set_config('bil.cloud_audit_assertions',v_checks::text,true);
 perform set_config('bil.cloud_audit_failure','',true);
 perform set_config('bil.cloud_audit_result','PASS',true);
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{}',true);
exception when others or query_canceled or assert_failure then
 -- PostgreSQL first rolls back ALL body writes/role settings in the block
 -- subtransaction. Handler reports FAILURE, never partial successes as PASS.
 get stacked diagnostics v_error_state=returned_sqlstate,
  v_error_message=message_text,v_error_context=pg_exception_context;
 perform set_config('bil.cloud_audit_result','FAIL',true);
 perform set_config('bil.cloud_audit_assertions','{}',true);
 perform set_config('bil.cloud_audit_failure',jsonb_build_object('sqlstate',v_error_state,
  'error',v_error_message,'stack_context',v_error_context,
  'checks_reached_before_failure',v_checks)::text,true);
end
$cloud_audit$;
select statement_timestamp() as assertions_completed_at,
 coalesce(nullif(current_setting('bil.cloud_audit_result',true),''),'UNKNOWN') as transaction_result,
 nullif(current_setting('bil.cloud_audit_failure',true),'')::jsonb as exact_failure,
 coalesce(nullif(current_setting('bil.cloud_audit_assertions',true),'')::jsonb,'{}') as completed_assertions,
 (select count(*) from jsonb_object_keys(coalesce(nullif(current_setting('bil.cloud_audit_assertions',true),'')::jsonb,'{}'))) as completed_assertion_count;
rollback;
-- END SEGMENT TRANSACTION

-- BEGIN SEGMENT RESIDUE
with owners as(select array['c56534f4-b96f-498c-99e4-3a60f9ac2c9c','977a0ce5-c8a2-4046-b3db-1553f92daaab']::uuid[] as ids),
inventory as(
 select 'auth.users'::text as table_name,(select count(*) from auth.users) as total_rows,
   (select count(*) from auth.users t where t.id=any(owners.ids) or t.email in('bil_cloud_rollback_20261004_c56534f4-a@example.invalid','bil_cloud_rollback_20261004_c56534f4-b@example.invalid')) as synthetic_rows from owners
 union all select 'public.bil_cloud_devices',(select count(*) from public.bil_cloud_devices),
   (select count(*) from public.bil_cloud_devices t where t.owner_id=any(owners.ids)) from owners
 union all select 'public.bil_cloud_records',(select count(*) from public.bil_cloud_records),
   (select count(*) from public.bil_cloud_records t where t.owner_id=any(owners.ids) or t.record_id='bil_cloud_rollback_20261004_c56534f4') from owners
 union all select 'public.bil_cloud_operations',(select count(*) from public.bil_cloud_operations),
   (select count(*) from public.bil_cloud_operations t where t.owner_id=any(owners.ids) or t.operation_id='bil_cloud_rollback_20261004_c56534f4') from owners
 union all select 'public.bil_consent_receipts',(select count(*) from public.bil_consent_receipts),
   (select count(*) from public.bil_consent_receipts t where t.user_id=any(owners.ids)) from owners
 union all select 'auth.identities',(select count(*) from auth.identities),
   (select count(*) from auth.identities t where t.user_id=any(owners.ids)) from owners
)
select statement_timestamp() as readback_at,count(*) as inventoried_table_count,
 bool_and(synthetic_rows=0) as zero_synthetic_rows,
 jsonb_agg(to_jsonb(inventory) order by table_name) as table_counts from inventory;
-- END SEGMENT RESIDUE
