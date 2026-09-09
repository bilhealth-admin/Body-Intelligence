-- Transactional proof for 20260908182300. Synthetic users, shares, blocks,
-- snapshots, and rate buckets are removed by the final ROLLBACK.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $test_preflight$
begin
  if pg_catalog.to_regprocedure(
       'public.bil_read_shared_diary(uuid,date,text)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_consume_rate_limit(text,integer,integer)'
     ) is null then
    raise exception 'shared_diary_hardening_test_requires_migration';
  end if;

  if exists (
    select 1
    from auth.users account
    where account.id in (
      '13000000-0000-4000-8000-000000000001'::uuid,
      '13000000-0000-4000-8000-000000000002'::uuid
    )
  ) then
    raise exception 'shared_diary_hardening_fixture_collision';
  end if;
end
$test_preflight$;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '13000000-0000-4000-8000-000000000001', 'authenticated',
    'authenticated', 'diary-owner@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  ),
  (
    '13000000-0000-4000-8000-000000000002', 'authenticated',
    'authenticated', 'diary-viewer@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  );

insert into public.bil_diary_share_settings(
  owner_id, visibility, access_key_sha256
) values (
  '13000000-0000-4000-8000-000000000001',
  'locked',
  pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to('correct-hardened-diary-key', 'UTF8'),
      'sha256'
    ),
    'hex'
  )
);

insert into public.bil_shared_diary_snapshots(
  owner_id, diary_day, payload, source_revision
) values (
  '13000000-0000-4000-8000-000000000001',
  date '2026-09-08',
  '{"fixture":"shared-diary-hardening"}'::jsonb,
  1
);

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '13000000-0000-4000-8000-000000000002',
  true
);
select pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"13000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

set local role authenticated;
do $test_constant_failure_and_success_shape$
declare
  v_value jsonb;
  v_correct_key text := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to('correct-hardened-diary-key', 'UTF8'),
      'sha256'
    ),
    'hex'
  );
begin
  select public.bil_read_shared_diary(
    '13000000-0000-4000-8000-000000000001',
    date '2026-09-08',
    null
  ) into v_value;
  if v_value is not null then
    raise exception 'test_locked_share_without_key_was_visible';
  end if;

  select public.bil_read_shared_diary(
    '13000000-0000-4000-8000-000000000001',
    date '2026-09-08',
    pg_catalog.repeat('0', 64)
  ) into v_value;
  if v_value is not null then
    raise exception 'test_wrong_diary_key_was_accepted';
  end if;

  -- A nonexistent target consumes the same caller-wide bucket and returns the
  -- same null result. The caller cannot allocate one bucket per guessed UUID.
  select public.bil_read_shared_diary(
    '13000000-0000-4000-8000-000000000099',
    date '2026-09-08',
    pg_catalog.repeat('1', 64)
  ) into v_value;
  if v_value is not null then
    raise exception 'test_nonexistent_diary_target_was_visible';
  end if;

  select public.bil_read_shared_diary(
    '13000000-0000-4000-8000-000000000001',
    date '2026-09-08',
    v_correct_key
  ) into v_value;
  if v_value <> '{"fixture":"shared-diary-hardening"}'::jsonb then
    raise exception 'test_correct_legacy_digest_did_not_read_snapshot';
  end if;
end
$test_constant_failure_and_success_shape$;
reset role;

insert into public.bil_blocks(blocker_id, blocked_id)
values (
  '13000000-0000-4000-8000-000000000001',
  '13000000-0000-4000-8000-000000000002'
);

set local role authenticated;
do $test_block_remains_authoritative$
declare
  v_value jsonb;
  v_correct_key text := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to('correct-hardened-diary-key', 'UTF8'),
      'sha256'
    ),
    'hex'
  );
begin
  select public.bil_read_shared_diary(
    '13000000-0000-4000-8000-000000000001',
    date '2026-09-08',
    v_correct_key
  ) into v_value;
  if v_value is not null then
    raise exception 'test_blocked_shared_diary_was_visible';
  end if;
end
$test_block_remains_authoritative$;

do $test_caller_wide_rate_limit$
declare
  v_iteration integer;
  v_value jsonb;
begin
  -- Four non-empty attempts have already succeeded. Reach exactly 30.
  for v_iteration in 1..26 loop
    select public.bil_read_shared_diary(
      '13000000-0000-4000-8000-000000000099',
      date '2026-09-08',
      pg_catalog.repeat('2', 64)
    ) into v_value;
  end loop;

  begin
    perform public.bil_read_shared_diary(
      '13000000-0000-4000-8000-000000000099',
      date '2026-09-08',
      pg_catalog.repeat('3', 64)
    );
    raise exception 'test_expected_shared_diary_rate_limit';
  exception
    when sqlstate 'P0001' then
      if sqlerrm <> 'rate limit exceeded' then
        raise;
      end if;
  end;
end
$test_caller_wide_rate_limit$;
reset role;

do $test_single_bounded_bucket$
declare
  v_bucket_count integer;
  v_hit_count integer;
begin
  select pg_catalog.count(*), pg_catalog.max(bucket.hit_count)
  into v_bucket_count, v_hit_count
  from public.bil_rate_limit_buckets bucket
  where bucket.user_id =
      '13000000-0000-4000-8000-000000000002'::uuid
    and bucket.action = 'shared_diary_locked_read';

  if v_bucket_count <> 1 or v_hit_count <> 30 then
    raise exception 'test_shared_diary_bucket_is_not_caller_wide_and_bounded';
  end if;
end
$test_single_bounded_bucket$;

do $test_reader_security_contract$
declare
  v_reader regprocedure :=
    'public.bil_read_shared_diary(uuid,date,text)'::regprocedure;
begin
  if (
       select procedure.provolatile <> 'v' or not procedure.prosecdef
       from pg_catalog.pg_proc procedure
       where procedure.oid = v_reader
     )
     or not exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.unnest(procedure.proconfig)
         configuration(setting)
       where procedure.oid = v_reader
         and configuration.setting in ('search_path=', 'search_path=""')
     )
     or not pg_catalog.has_function_privilege(
       'authenticated', v_reader, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege('anon', v_reader, 'EXECUTE')
     or pg_catalog.has_function_privilege('service_role', v_reader, 'EXECUTE')
     or exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) privilege
       where procedure.oid = v_reader
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'test_shared_diary_reader_security_contract';
  end if;
end
$test_reader_security_contract$;

rollback;
