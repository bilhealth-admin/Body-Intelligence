-- Transactional runtime proof for the push-claim conflict fix. The synthetic
-- account, token, outbox, attempt, and lease are removed by ROLLBACK.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $test_preflight$
begin
  if pg_catalog.to_regprocedure(
       'public.bil_claim_push_deliveries(uuid,integer)'
     ) is null
     or pg_catalog.to_regprocedure(
       'private.bil_social_public_code_payload_v2(boolean)'
     ) is null then
    raise exception 'backend_function_lint_test_requires_migration';
  end if;

  if exists (
    select 1
    from auth.users account
    where account.id = '13000000-0000-4000-8000-000000000001'::uuid
  ) then
    raise exception 'backend_function_lint_fixture_collision';
  end if;
end
$test_preflight$;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '13000000-0000-4000-8000-000000000001', 'authenticated',
  'authenticated', 'push-claim-lint@bil-test.invalid', '',
  pg_catalog.clock_timestamp(),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
);

insert into public.bil_push_device_tokens(
  id, user_id, token_ciphertext, token_fingerprint, platform, timezone,
  enabled, sensitive_preview_allowed
) values (
  '13000000-0000-4000-8000-000000000002',
  '13000000-0000-4000-8000-000000000001',
  'synthetic-provider-token-not-for-delivery',
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'fcm', 'UTC', true, false
);

insert into public.bil_push_outbox(
  id, recipient_id, category, title, body, deep_link,
  copy_key, source_key
) values (
  '13000000-0000-4000-8000-000000000003',
  '13000000-0000-4000-8000-000000000001',
  'community', 'BIL', 'Synthetic push claim test',
  'bil://community', 'community.push.test',
  'backend-function-lint-closure-test'
);

set local role service_role;
do $test_push_claim_round_trip$
declare
  v_claim record;
  v_second_claim_count integer;
begin
  select * into v_claim
  from public.bil_claim_push_deliveries(
    '13000000-0000-4000-8000-000000000003',
    60
  );

  if not found
     or v_claim.device_token_id <>
       '13000000-0000-4000-8000-000000000002'::uuid
     or v_claim.provider_token <>
       'synthetic-provider-token-not-for-delivery'
     or v_claim.platform <> 'fcm'
     or v_claim.sensitive_preview_allowed
     or v_claim.delivery_key <>
       '13000000-0000-4000-8000-000000000003:' ||
       '13000000-0000-4000-8000-000000000002' then
    raise exception 'test_push_claim_payload';
  end if;

  select pg_catalog.count(*) into v_second_claim_count
  from public.bil_claim_push_deliveries(
    '13000000-0000-4000-8000-000000000003',
    60
  );
  if v_second_claim_count <> 0 then
    raise exception 'test_push_claim_lease_not_respected';
  end if;
end
$test_push_claim_round_trip$;
reset role;

do $test_push_claim_attempt_state$
begin
  if not exists (
    select 1
    from public.bil_push_delivery_attempts attempt
    where attempt.outbox_id =
      '13000000-0000-4000-8000-000000000003'::uuid
      and attempt.device_token_id =
        '13000000-0000-4000-8000-000000000002'::uuid
      and attempt.attempt_count = 1
      and attempt.leased_until > pg_catalog.clock_timestamp()
      and attempt.last_attempt_at is not null
      and attempt.delivered_at is null
      and attempt.terminal_at is null
  ) then
    raise exception 'test_push_claim_attempt_state';
  end if;
end
$test_push_claim_attempt_state$;

do $test_push_claim_acl$
declare
  v_function regprocedure :=
    'public.bil_claim_push_deliveries(uuid,integer)'::regprocedure;
begin
  if not pg_catalog.has_function_privilege(
       'service_role', v_function, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated', v_function, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'anon', v_function, 'EXECUTE'
     ) then
    raise exception 'test_push_claim_acl';
  end if;
end
$test_push_claim_acl$;

rollback;
