-- LOCAL ONLY. Genuine RPCs and ordinary roles; no app table grants,
-- outbound HTTP, real provider tokens, Auth service or Production claims.
begin;
set local statement_timeout='20s';
select public.qa_push_assert((select relrowsecurity from pg_class
  where oid='private.bil_push_delivery_preferences_v1'::regclass),'private desired-state table has RLS');
select public.qa_push_assert(not exists(
  select 1 from unnest(array['anon','authenticated','service_role']) role_name
  where has_table_privilege(role_name,'private.bil_push_delivery_preferences_v1','SELECT,INSERT,UPDATE,DELETE')
),'RPC-only desired state denies direct CRUD to all API roles');
select public.qa_push_assert(not has_function_privilege('anon',
  'public.bil_get_my_push_delivery_categories_v1()','EXECUTE')
  and not has_function_privilege('service_role','public.bil_get_my_push_delivery_categories_v1()','EXECUTE'),
  'getter is authenticated-owner only');
select public.qa_push_assert(not has_function_privilege('authenticated',
  'private.bil_write_my_push_delivery_categories_v1(boolean,boolean,boolean,bigint)','EXECUTE'),
  'legacy-compatible internal writer is not callable by app');
select public.qa_push_assert(not has_function_privilege('authenticated',
  'public.bil_claim_push_deliveries(uuid,integer)','EXECUTE')
  and not has_function_privilege('anon','public.bil_claim_push_deliveries(uuid,integer)','EXECUTE'),
  'provider token claim remains service-only');
select public.qa_push_assert(not exists(
  select 1 from pg_proc where oid in (
    'public.bil_get_my_push_delivery_categories_v1()'::regprocedure,
    'public.bil_set_my_push_delivery_categories_v1(boolean,boolean,boolean,bigint)'::regprocedure,
    'private.bil_write_my_push_delivery_categories_v1(boolean,boolean,boolean,bigint)'::regprocedure,
    'public.bil_register_push_token_v2(text,text,text,boolean,boolean,boolean,boolean)'::regprocedure,
    'public.bil_claim_push_deliveries(uuid,integer)'::regprocedure)
  and (not prosecdef or not ('search_path=""'=any(proconfig)))
),'all privileged new/changed functions have explicit empty search_path');
select public.qa_push_assert(md5(pg_get_functiondef('public.bil_get_push_preferences()'::regprocedure))
  ='788164ef199b4b210917541536a00997','legacy master getter body/signature is unchanged');

set local role anon;
do $deny$
begin
  begin perform public.bil_get_my_push_delivery_categories_v1();
    raise exception 'anonymous getter unexpectedly allowed';
  exception when insufficient_privilege then null; end;
end
$deny$;
reset role;
set local role service_role;
do $deny$
begin
  begin perform public.bil_get_my_push_delivery_categories_v1();
    raise exception 'service getter unexpectedly allowed';
  exception when insufficient_privilege then null; end;
end
$deny$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
do $no_subject$
begin
  begin perform public.bil_get_my_push_delivery_categories_v1();
    raise exception 'missing Auth owner unexpectedly allowed';
  exception when insufficient_privilege then null; end;
end
$no_subject$;

select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
do $active_divergence$
declare j jsonb:=public.bil_get_my_push_delivery_categories_v1();
begin
  perform public.qa_push_assert(j->>'owner_id'='11111111-1111-4111-8111-111111111111',
    'backfilled envelope is exact current owner');
  perform public.qa_push_assert(j @> '{"initialized":true,"revision":1,
    "message_enabled":true,"friend_request_enabled":true,"friend_accepted_enabled":false,
    "effective_message_enabled":true,"effective_friend_request_enabled":true,
    "effective_friend_accepted_enabled":false,"synchronized":false}'::jsonb,
    'ANY active-device backfill preserves delivery and exposes divergence honestly');
end
$active_divergence$;

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $inactive$
declare j jsonb:=public.bil_get_my_push_delivery_categories_v1();
begin
  perform public.qa_push_assert(j->>'owner_id'='22222222-2222-4222-8222-222222222222',
    'second owner cannot read first owner preferences');
  perform public.qa_push_assert(j @> '{"initialized":false,"revision":0,"message_enabled":null,
    "friend_request_enabled":null,"friend_accepted_enabled":null,
    "effective_message_enabled":false,"effective_friend_request_enabled":false,
    "effective_friend_accepted_enabled":false,"synchronized":false}'::jsonb,
    'inactive-only device history is UNKNOWN, not inferred desired opt-in/out');
end
$inactive$;

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
do $zero_tokens$
declare j jsonb:=public.bil_get_my_push_delivery_categories_v1();
begin
  perform public.qa_push_assert(j @> '{"initialized":false,"revision":0,"message_enabled":null,
    "friend_request_enabled":null,"friend_accepted_enabled":null,"synchronized":false}'::jsonb,
    'no-token owner starts UNKNOWN');
  j:=public.bil_set_my_push_delivery_categories_v1(false,false,false,0);
  perform public.qa_push_assert(j @> '{"initialized":true,"revision":1,"message_enabled":false,
    "friend_request_enabled":false,"friend_accepted_enabled":false,
    "effective_message_enabled":false,"effective_friend_request_enabled":false,
    "effective_friend_accepted_enabled":false,"synchronized":true}'::jsonb,
    'zero-token opt-out has actual durable authoritative receipt');
  perform public.qa_push_assert(public.bil_get_my_push_delivery_categories_v1()=j,
    'independent server readback equals strict zero-token write receipt');
  perform public.qa_push_assert(public.bil_set_my_push_delivery_categories_v1(false,false,false,1)=j,
    'identical valid-revision request is idempotent without revision inflation');
  begin perform public.bil_set_my_push_delivery_categories_v1(true,true,true,0);
    raise exception 'stale revision unexpectedly allowed';
  exception when serialization_failure then null; end;
  perform public.qa_push_assert(public.bil_get_my_push_delivery_categories_v1()=j,
    'stale full-snapshot CAS has no desired/effective mutation');
  begin perform public.bil_set_my_push_delivery_categories_v1(null,false,false,1);
    raise exception 'null category unexpectedly allowed';
  exception when invalid_parameter_value then null; end;
  begin perform public.bil_set_my_push_delivery_categories_v1(true,true,true,null);
    raise exception 'missing expected revision unexpectedly allowed';
  exception when invalid_parameter_value then null; end;
  begin perform public.bil_set_my_push_delivery_categories_v1(true,true,true,-1);
    raise exception 'negative revision unexpectedly allowed';
  exception when invalid_parameter_value then null; end;
  perform public.qa_push_assert(public.bil_get_my_push_delivery_categories_v1()=j,
    'invalid writes are fail-closed and preserve owner state');
  begin perform 1 from private.bil_push_delivery_preferences_v1;
    raise exception 'direct private state unexpectedly readable';
  exception when insufficient_privilege then null; end;
end
$zero_tokens$;
reset role;
select public.qa_push_assert(not exists(select 1 from public.bil_push_device_tokens
  where user_id='33333333-3333-4333-8333-333333333333'),
  'preference opt-out never creates a token or opts in master delivery');

set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select public.bil_register_push_token_v2('fixture-only-zero-owner-rotated-v2','fcm','UTC',true,true,true,true);
select public.bil_register_push_token('fixture-only-zero-owner-legacy-v1','apns','UTC',true);
do $registration$
declare j jsonb:=public.bil_get_my_push_delivery_categories_v1();
begin
  perform public.qa_push_assert(j @> '{"initialized":true,"revision":1,"message_enabled":false,
    "friend_request_enabled":false,"friend_accepted_enabled":false,
    "effective_message_enabled":false,"effective_friend_request_enabled":false,
    "effective_friend_accepted_enabled":false,"synchronized":true}'::jsonb,
    'new/legacy registration parameters cannot reset durable owner opt-out');
  perform public.bil_set_push_delivery_categories_v2(false,true,false);
  j:=public.bil_get_my_push_delivery_categories_v1();
  perform public.qa_push_assert(j @> '{"revision":2,"message_enabled":false,
    "friend_request_enabled":true,"friend_accepted_enabled":false,"synchronized":true}'::jsonb,
    'legacy void setter delegates real durable write while retaining legacy LWW contract');
  perform public.bil_set_my_push_delivery_categories_v1(false,false,false,2);
end
$registration$;
reset role;
select public.qa_push_assert((select count(*)=2 and not bool_or(sensitive_preview_allowed)
  and not bool_or(message_enabled or friend_request_enabled or friend_accepted_enabled)
  from public.bil_push_device_tokens where user_id='33333333-3333-4333-8333-333333333333'),
  'both token versions preserve false sensitive previews and actual opt-out flags');
select public.qa_push_assert((select enabled=false from public.bil_push_device_tokens
  where user_id='22222222-2222-4222-8222-222222222222'),
  'unrelated owner inactive master state is unchanged');

-- Account/non-category delivery remains eligible: the repair must not silently
-- suppress unrelated account/AI alerts or expand the three-category contract.
insert into public.bil_push_outbox(id,recipient_id,category,copy_key)
values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','33333333-3333-4333-8333-333333333333','account','account_fixture_v1');
set local role service_role;
select public.qa_push_assert((select count(*)=2 from public.bil_claim_push_deliveries(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',60)), 'unrelated account delivery eligibility is preserved');
select public.qa_push_assert((select count(*)=0 from public.bil_claim_push_deliveries(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',60)), 'active leases still prevent duplicate claims');
reset role;

-- Reassignment of a real registered fixture token must not deliver an old
-- owner's cached attempt to the new owner; no direct token mutation is used.
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select public.bil_register_push_token_v2('fixture-only-owner-transition-token','fcm','UTC',false,true,true,true);
reset role;
insert into public.bil_push_outbox(id,recipient_id,category,copy_key)
values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2','44444444-4444-4444-8444-444444444444','message','message_fixture_v1');
set local role service_role;
do $owner_claim$
declare v_device uuid;
begin
  select device_token_id into strict v_device from public.bil_claim_push_deliveries(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',60);
  perform public.bil_record_push_delivery_result('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    v_device,false,'fixture_network_failure',false);
end
$owner_claim$;
reset role;
update public.bil_push_delivery_attempts set next_attempt_at=clock_timestamp()
where outbox_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.bil_register_push_token_v2('fixture-only-owner-transition-token','fcm','UTC',false,false,false,false);
select public.qa_push_assert(public.bil_get_my_push_delivery_categories_v1() @>
  '{"owner_id":"22222222-2222-4222-8222-222222222222","initialized":true,
    "message_enabled":false,"friend_request_enabled":false,"friend_accepted_enabled":false,
    "synchronized":true}'::jsonb,'new token owner receives only their own initialized state');
reset role;
set local role service_role;
select public.qa_push_assert((select count(*)=0 from public.bil_claim_push_deliveries(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',60)), 'old-owner retry cannot target reassigned token');
reset role;
select public.qa_push_assert((select attempt_count=1 from public.bil_push_delivery_attempts
  where outbox_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'),'reassigned token consumes no old-owner retry');

-- First registration initializes explicit choices only for a genuinely
-- unknown owner. Its independent receipt is not confused with local defaults.
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.qa_push_assert(public.bil_get_my_push_delivery_categories_v1()->>'revision'='1',
  'foreign owner writes never mutate first-owner revision');
reset role;
select 'AUTHORITATIVE_OWNER_PREFERENCE_ASSERTIONS_PASS';
rollback;

