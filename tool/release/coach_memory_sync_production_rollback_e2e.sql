-- Controlled synthetic memory RLS/CAS audit. No DDL, real-user writes or key changes. Always ROLLBACK.

-- BEGIN SEGMENT PRECHECK
with owners as(select array['b1380039-0000-4000-8000-000000000001','b1380039-0000-4000-8000-000000000002']::uuid[] as ids), inventory as(
 select 'auth.users'::text as table_name,count(*) as synthetic_rows from auth.users,owners where id=any(ids)
 union all select 'auth.identities',count(*) from auth.identities,owners where user_id=any(ids)
 union all select 'public.bil_coach_memories',count(*) from public.bil_coach_memories,owners where owner_id=any(ids))
select count(*) as inventoried_table_count,bool_and(synthetic_rows=0) as zero_synthetic_rows,
 jsonb_agg(to_jsonb(inventory) order by table_name) as table_counts from inventory;
-- END SEGMENT PRECHECK

-- BEGIN SEGMENT TRANSACTION
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
do $coach_memory_audit$
declare
 a constant uuid:='b1380039-0000-4000-8000-000000000001';
 b constant uuid:='b1380039-0000-4000-8000-000000000002';
 memory constant uuid:='b1380039-0000-4000-8000-000000000003';
 marker constant text:='bil_coach_memory_v38_20261023';
 t0 constant timestamptz:='2026-10-23T00:00:00Z';
 t1 constant timestamptz:='2026-10-23T00:00:01Z';
 checks jsonb:='{}'; n integer; rejected boolean; error_state text; error_message text;
begin
 if exists(select 1 from auth.users where id in(a,b) or email in(marker||'-a@example.invalid',marker||'-b@example.invalid'))
   or exists(select 1 from public.bil_coach_memories where owner_id in(a,b) or id=memory) then
   raise exception 'AUDIT synthetic identifiers occupied'; end if;
 checks:=checks||jsonb_build_object('synthetic_identifiers_absent',true);
 if exists(select 1 from pg_trigger t where not t.tgisinternal and (
    t.tgrelid='public.bil_coach_memories'::regclass or
    (t.tgrelid='auth.users'::regclass and not(t.tgname='bil_remove_owned_circles_before_account_delete_v1'
      and t.tgtype=11 and t.tgenabled='O' and t.tgnargs=0 and t.tgqual is null
      and t.tgfoid=coalesce(to_regprocedure('private.bil_remove_owned_circles_before_account_delete_v1()')::oid,0)
      and (select md5(prosrc) from pg_proc where oid=t.tgfoid)='07e9bc31211219735ef172d3d9e6eee4')))) then
   raise exception 'AUDIT unreviewed external trigger'; end if;
 checks:=checks||jsonb_build_object('reviewed_trigger_inventory',true);
 if not(select relrowsecurity from pg_class where oid='public.bil_coach_memories'::regclass) then
   raise exception 'AUDIT RLS disabled'; end if;
 checks:=checks||jsonb_build_object('rls_enabled',true);
 insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_anonymous) values
  (a,'authenticated','authenticated',marker||'-a@example.invalid',now(),now(),now(),'{"provider":"email","providers":["email"]}','{}',false),
  (b,'authenticated','authenticated',marker||'-b@example.invalid',now(),now(),now(),'{"provider":"email","providers":["email"]}','{}',false);
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 insert into public.bil_coach_memories(id,owner_id,kind,memory_text,status,source,confidence,learned_at,updated_at)
 values(memory,a,'preference','Synthetic evening workout preference','confirmed','explicit_user_confirmation',1,t0,t0);
 if not exists(select 1 from public.bil_coach_memories where id=memory and owner_id=a and updated_at=t0) then
   raise exception 'AUDIT create readback mismatch'; end if;
 checks:=checks||jsonb_build_object('owner_create_and_timestamp_readback',true);
 update public.bil_coach_memories set memory_text='Must never apply' where id=memory and owner_id=a and updated_at=t1;
 get diagnostics n=row_count;
 if n<>0 then raise exception 'AUDIT stale version overwritten'; end if;
 checks:=checks||jsonb_build_object('stale_cas_writes_zero_rows',true);
 update public.bil_coach_memories set memory_text='Synthetic updated workout preference',updated_at=t1
 where id=memory and owner_id=a and updated_at=t0;
 get diagnostics n=row_count;
 if n<>1 or not exists(select 1 from public.bil_coach_memories where id=memory and updated_at=t1 and memory_text='Synthetic updated workout preference') then
   raise exception 'AUDIT CAS independent readback mismatch'; end if;
 checks:=checks||jsonb_build_object('matching_cas_and_independent_readback',true);
 rejected:=false;
 begin update public.bil_coach_memories set owner_id=b where id=memory;
 exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'AUDIT owner transfer accepted'; end if;
 checks:=checks||jsonb_build_object('owner_transfer_denied',true);
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated')::text,true);
 if exists(select 1 from public.bil_coach_memories where id=memory) then raise exception 'AUDIT foreign read accepted'; end if;
 checks:=checks||jsonb_build_object('foreign_owner_read_isolated',true);
 update public.bil_coach_memories set memory_text='Must never apply' where id=memory;
 get diagnostics n=row_count;
 if n<>0 then raise exception 'AUDIT foreign write accepted'; end if;
 checks:=checks||jsonb_build_object('foreign_owner_update_zero_rows',true);
 rejected:=false;
 begin insert into public.bil_coach_memories(owner_id,kind,memory_text,source) values(a,'preference','Must never apply','explicit_user_confirmation');
 exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'AUDIT foreign insert accepted'; end if;
 checks:=checks||jsonb_build_object('foreign_owner_insert_denied',true);
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 update public.bil_coach_memories set memory_text='[deleted]',metadata='{}',deleted_at=now(),updated_at=now()
 where id=memory and owner_id=a and updated_at=t1;
 get diagnostics n=row_count;
 if n<>1 or not exists(select 1 from public.bil_coach_memories where id=memory and memory_text='[deleted]' and metadata='{}' and deleted_at is not null) then
   raise exception 'AUDIT privacy deletion readback mismatch'; end if;
 checks:=checks||jsonb_build_object('confirmed_deletion_redacts_text_and_metadata',true);
 execute 'reset role';
 perform set_config('request.jwt.claim.sub','',true); perform set_config('request.jwt.claims','{}',true);
 execute 'set local role anon';
 rejected:=false;
 begin perform 1 from public.bil_coach_memories where id=memory;
 exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'AUDIT anonymous table access accepted'; end if;
 checks:=checks||jsonb_build_object('anonymous_access_denied',true);
 execute 'reset role';
 perform set_config('bil.coach_memory_audit_result','PASS',true);
 perform set_config('bil.coach_memory_audit_assertions',checks::text,true);
exception when others then
 get stacked diagnostics error_state=returned_sqlstate,error_message=message_text;
 perform set_config('bil.coach_memory_audit_result','FAIL',true);
 perform set_config('bil.coach_memory_audit_assertions','{}',true);
 perform set_config('bil.coach_memory_audit_failure',jsonb_build_object('sqlstate',error_state,'error',error_message,'checks_reached_before_failure',checks)::text,true);
end $coach_memory_audit$;
select coalesce(nullif(current_setting('bil.coach_memory_audit_result',true),''),'UNKNOWN') as transaction_result,
 nullif(current_setting('bil.coach_memory_audit_failure',true),'')::jsonb as exact_failure,
 coalesce(nullif(current_setting('bil.coach_memory_audit_assertions',true),'')::jsonb,'{}') as completed_assertions,
 (select count(*) from jsonb_object_keys(coalesce(nullif(current_setting('bil.coach_memory_audit_assertions',true),'')::jsonb,'{}'))) as completed_assertion_count;
rollback;
-- END SEGMENT TRANSACTION

-- BEGIN SEGMENT RESIDUE
with owners as(select array['b1380039-0000-4000-8000-000000000001','b1380039-0000-4000-8000-000000000002']::uuid[] as ids), inventory as(
 select 'auth.users'::text as table_name,count(*) as synthetic_rows from auth.users,owners where id=any(ids)
 union all select 'auth.identities',count(*) from auth.identities,owners where user_id=any(ids)
 union all select 'public.bil_coach_memories',count(*) from public.bil_coach_memories,owners where owner_id=any(ids))
select count(*) as inventoried_table_count,bool_and(synthetic_rows=0) as zero_synthetic_rows,
 jsonb_agg(to_jsonb(inventory) order by table_name) as table_counts from inventory;
-- END SEGMENT RESIDUE
