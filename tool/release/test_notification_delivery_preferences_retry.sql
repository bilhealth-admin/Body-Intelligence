-- The SAME assertion is run against the verbatim LIVE baseline (must FAIL)
-- and the exact forward migration (must PASS). No provider network calls.
begin;
set local statement_timeout='15s';
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select public.bil_register_push_token_v2('fixture-only-not-a-provider-token-retry','fcm','UTC',false,true,true,true);
reset role;
insert into public.bil_push_outbox(id,recipient_id,category,copy_key)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  '44444444-4444-4444-8444-444444444444',:'category',:'copy_key');
set local role service_role;
do $claim$
declare v_device uuid;
begin
  select device_token_id into strict v_device from public.bil_claim_push_deliveries(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',60);
  perform public.qa_push_assert(v_device is not null, 'first delivery is genuinely claimed');
  perform public.bil_record_push_delivery_result('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    v_device,false,'fixture_network_failure',false);
end
$claim$;
reset role;
-- LOCAL fixture clock setup only: release the previous claim and make its
-- retry due. It exercises the real eligible CTE, not a 30-second wall wait.
select public.qa_push_assert((select leased_until is null and failure_code='fixture_network_failure'
  and attempt_count=1 from public.bil_push_delivery_attempts),
  'real result RPC released failed delivery with retry backoff');
update public.bil_push_delivery_attempts set next_attempt_at=clock_timestamp();
set local role authenticated;
select public.bil_set_push_delivery_categories_v2(false,false,false);
reset role;
select public.qa_push_assert((select count(*)=1 and not bool_or(message_enabled
  or friend_request_enabled or friend_accepted_enabled) from public.bil_push_device_tokens
  where user_id='44444444-4444-4444-8444-444444444444'),
  'real authenticated opt-out RPC stored all categories OFF');
set local role service_role;
select public.qa_push_assert((select count(*)=0 from public.bil_claim_push_deliveries(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',60)), 'retry must honor committed category opt-out');
reset role;
select public.qa_push_assert((select attempt_count=1 from public.bil_push_delivery_attempts),
  'opted-out retry does not consume another attempt');
set local role service_role;
select public.qa_push_assert(public.bil_finalize_push_outbox(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')->>'reason'='no_eligible_tokens',
  'opted-out backlog finalizes without false delivery');
reset role;
select 'RETRY_CATEGORY_OPT_OUT_ASSERTIONS_PASS';
rollback;
