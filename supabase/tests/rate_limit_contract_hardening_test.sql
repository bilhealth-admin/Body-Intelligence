-- Transactional runtime proof for the canonical rate-limit contract. The
-- synthetic account and every bucket row are removed by the final ROLLBACK.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $test_preflight$
begin
  if pg_catalog.to_regprocedure(
       'public.bil_consume_rate_limit(text,integer,integer)'
     ) is null then
    raise exception 'rate_limit_contract_test_requires_migration';
  end if;

  if exists (
    select 1
    from auth.users account
    where account.id = '12000000-0000-4000-8000-000000000001'::uuid
  ) then
    raise exception 'rate_limit_contract_fixture_collision';
  end if;
end
$test_preflight$;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '12000000-0000-4000-8000-000000000001', 'authenticated',
  'authenticated', 'rate-limit-contract@bil-test.invalid', '',
  pg_catalog.clock_timestamp(),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
);

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '12000000-0000-4000-8000-000000000001',
  true
);
select pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"12000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

set local role authenticated;
do $test_rejects_arbitrary_bucket_keys$
begin
  begin
    perform public.bil_consume_rate_limit(
      'attacker_controlled_' || pg_catalog.gen_random_uuid()::text,
      2147483647,
      1
    );
    raise exception 'test_expected_arbitrary_action_rejection';
  exception
    when sqlstate '22023' then
      if sqlerrm <> 'invalid_rate_limit_contract' then
        raise;
      end if;
  end;

  begin
    perform public.bil_consume_rate_limit(
      pg_catalog.repeat('x', 65),
      10,
      60
    );
    raise exception 'test_expected_oversized_action_rejection';
  exception
    when sqlstate '22023' then
      if sqlerrm <> 'invalid_rate_limit_contract' then
        raise;
      end if;
  end;

  begin
    perform public.bil_consume_rate_limit(
      'food_search_minute',
      2147483647,
      60
    );
    raise exception 'test_expected_limit_mismatch_rejection';
  exception
    when sqlstate '22023' then
      if sqlerrm <> 'invalid_rate_limit_contract' then
        raise;
      end if;
  end;
end
$test_rejects_arbitrary_bucket_keys$;

do $test_canonical_tuple_and_limit$
declare
  v_iteration integer;
begin
  for v_iteration in 1..10 loop
    perform public.bil_consume_rate_limit('food_search_minute', 10, 60);
  end loop;

  begin
    perform public.bil_consume_rate_limit('food_search_minute', 10, 60);
    raise exception 'test_expected_rate_limit_rejection';
  exception
    when sqlstate 'P0001' then
      if sqlerrm <> 'rate limit exceeded' then
        raise;
      end if;
  end;
end
$test_canonical_tuple_and_limit$;
reset role;

do $test_bucket_write_is_bounded$
declare
  v_bucket_count integer;
  v_hit_count integer;
begin
  select pg_catalog.count(*), pg_catalog.max(bucket.hit_count)
  into v_bucket_count, v_hit_count
  from public.bil_rate_limit_buckets bucket
  where bucket.user_id =
    '12000000-0000-4000-8000-000000000001'::uuid;

  if v_bucket_count <> 1 or v_hit_count <> 10 then
    raise exception 'test_rate_limit_bucket_write_is_not_bounded';
  end if;
end
$test_bucket_write_is_bounded$;

do $test_rate_limit_rpc_acl$
declare
  v_function regprocedure :=
    'public.bil_consume_rate_limit(text,integer,integer)'::regprocedure;
begin
  if not pg_catalog.has_function_privilege(
       'authenticated', v_function, 'EXECUTE'
     )
     or not pg_catalog.has_function_privilege(
       'service_role', v_function, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege('anon', v_function, 'EXECUTE')
     or exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) privilege
       where procedure.oid = v_function
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'test_rate_limit_rpc_acl';
  end if;
end
$test_rate_limit_rpc_acl$;

rollback;
