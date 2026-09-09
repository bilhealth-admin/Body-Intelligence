-- Transactional production-schema test for the Social v2 save and BIL public
-- code extension. Every synthetic account, receipt, post, moderation action,
-- code, relationship, and rate-limit row is rolled back.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $test_preflight$
begin
  if pg_catalog.to_regclass(
       'public.bil_social_post_saves_v2'
     ) is null
     or pg_catalog.to_regclass(
       'public.bil_social_public_codes_v2'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_save_v2(uuid,boolean)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_saved_state_v2(uuid[])'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_saved_posts_v2(timestamp with time zone,uuid,integer)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_public_code_v2()'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_rotate_public_code_v2()'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_resolve_public_code_v2(text)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_post_authors_v2(uuid[])'
     ) is null then
    raise exception 'community_social_extension_test_requires_migration';
  end if;

  if (select pg_catalog.count(*)
      from public.bil_content_policies policy
      where policy.active
        and policy.effective_at <= pg_catalog.clock_timestamp()) <> 1 then
    raise exception 'community_social_extension_test_requires_one_active_policy';
  end if;

  if exists (
    select 1
    from auth.users account
    where account.id in (
      '11000000-0000-4000-8000-000000000001'::uuid,
      '11000000-0000-4000-8000-000000000002'::uuid,
      '11000000-0000-4000-8000-000000000003'::uuid
    )
  ) then
    raise exception 'community_social_extension_fixture_collision';
  end if;
end
$test_preflight$;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '11000000-0000-4000-8000-000000000001', 'authenticated',
    'authenticated', 'social-save-actor@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  ),
  (
    '11000000-0000-4000-8000-000000000002', 'authenticated',
    'authenticated', 'social-code-target@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  ),
  (
    '11000000-0000-4000-8000-000000000003', 'authenticated',
    'authenticated', 'social-moderator@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  );

insert into public.bil_public_profiles (
  user_id, display_name, profile_visibility, discoverable,
  allow_friend_requests
) values
  (
    '11000000-0000-4000-8000-000000000001',
    'Save Actor', 'public', true, true
  ),
  (
    '11000000-0000-4000-8000-000000000002',
    'Code Target', 'public', true, true
  ),
  (
    '11000000-0000-4000-8000-000000000003',
    'Post Moderator', 'private', false, false
  )
on conflict (user_id) do update
set display_name = excluded.display_name,
    profile_visibility = excluded.profile_visibility,
    discoverable = excluded.discoverable,
    allow_friend_requests = excluded.allow_friend_requests;

insert into public.bil_community_moderators(user_id)
values ('11000000-0000-4000-8000-000000000003');

-- The real client boundary creates the actor's exact-version receipt and post.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000001',
  true
);
select pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

set local role authenticated;
insert into public.bil_content_policy_acceptances(
  user_id, policy_version
)
select
  '11000000-0000-4000-8000-000000000001'::uuid,
  policy.version
from public.bil_content_policies policy
where policy.active
  and policy.effective_at <= pg_catalog.clock_timestamp();

insert into public.bil_community_posts(id, author_id, body, visibility)
values (
  '11000000-0000-4000-8000-000000000101',
  '11000000-0000-4000-8000-000000000001',
  'Safe Social v2 save test post',
  'community'
);
reset role;

-- Human moderation uses the real moderator RPC; all reward effects remain
-- inside this test transaction and disappear on ROLLBACK.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000003',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select public.bil_moderate_community_post(
  '11000000-0000-4000-8000-000000000101',
  'approved'
);
reset role;

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000001',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

do $test_save_round_trip$
declare
  v_result jsonb;
  v_state jsonb;
  v_saved_count integer;
begin
  select public.bil_social_save_v2(
    '11000000-0000-4000-8000-000000000101', true
  ) into v_result;

  if v_result->>'post_id' <>
       '11000000-0000-4000-8000-000000000101'
     or v_result->>'saved' <> 'true' then
    raise exception 'test_social_save_create_payload';
  end if;

  select public.bil_social_saved_state_v2(array[
    '11000000-0000-4000-8000-000000000101'::uuid
  ]) into v_state;
  if pg_catalog.jsonb_array_length(v_state) <> 1
     or v_state->0->>'saved' <> 'true' then
    raise exception 'test_social_saved_state_payload';
  end if;

  select pg_catalog.count(*) into v_saved_count
  from public.bil_social_saved_posts_v2(null, null, 30) saved
  where saved.post_id =
    '11000000-0000-4000-8000-000000000101'::uuid;
  if v_saved_count <> 1 then
    raise exception 'test_social_saved_feed';
  end if;

  select public.bil_social_save_v2(
    '11000000-0000-4000-8000-000000000101', false
  ) into v_result;
  if v_result->>'saved' <> 'false' then
    raise exception 'test_social_save_delete_payload';
  end if;
end
$test_save_round_trip$;

do $test_deleted_root_hides_replies$
declare
  v_visible_count integer;
  v_stats jsonb;
begin
  perform public.bil_social_add_comment_v2(
    '11000000-0000-4000-8000-000000000101',
    'Visible root comment',
    null,
    '11000000-0000-4000-8000-000000000201'
  );
  perform public.bil_social_add_comment_v2(
    '11000000-0000-4000-8000-000000000101',
    'Visible reply comment',
    '11000000-0000-4000-8000-000000000201',
    '11000000-0000-4000-8000-000000000202'
  );

  select pg_catalog.count(*) into v_visible_count
  from public.bil_social_comments_v2(
    '11000000-0000-4000-8000-000000000101', null, null, 30
  );
  select public.bil_social_stats_v2(array[
    '11000000-0000-4000-8000-000000000101'::uuid
  ]) into v_stats;
  if v_visible_count <> 2 or v_stats->0->>'comment_count' <> '2' then
    raise exception 'test_social_reply_setup';
  end if;

  perform public.bil_social_delete_comment_v2(
    '11000000-0000-4000-8000-000000000201'
  );

  select pg_catalog.count(*) into v_visible_count
  from public.bil_social_comments_v2(
    '11000000-0000-4000-8000-000000000101', null, null, 30
  );
  select public.bil_social_stats_v2(array[
    '11000000-0000-4000-8000-000000000101'::uuid
  ]) into v_stats;
  if v_visible_count <> 0 or v_stats->0->>'comment_count' <> '0' then
    raise exception 'test_social_deleted_root_exposes_reply';
  end if;

  begin
    perform public.bil_social_like_comment_v2(
      '11000000-0000-4000-8000-000000000202', true
    );
    raise exception 'test_expected_orphan_reply_like_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'comment_unavailable' then
        raise;
      end if;
  end;

  begin
    perform public.bil_social_report_comment_v2(
      '11000000-0000-4000-8000-000000000202',
      'Hidden reply report must fail closed'
    );
    raise exception 'test_expected_orphan_reply_report_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'comment_unavailable' then
        raise;
      end if;
  end;
end
$test_deleted_root_hides_replies$;

do $test_actor_public_code_round_trip$
declare
  v_initial jsonb;
  v_repeat jsonb;
  v_rotated jsonb;
  v_resolved jsonb;
begin
  select public.bil_social_public_code_v2() into v_initial;
  select public.bil_social_public_code_v2() into v_repeat;

  if v_initial->>'code' !~ '^[a-f0-9]{32}$'
     or v_initial->>'uri' <>
       'bil://community/member/' || (v_initial->>'code')
     or v_initial->>'handle' is null
     or v_repeat->>'code' <> v_initial->>'code' then
    raise exception 'test_social_public_code_payload';
  end if;

  select public.bil_social_rotate_public_code_v2() into v_rotated;
  if v_rotated->>'code' = v_initial->>'code'
     or v_rotated->>'code' !~ '^[a-f0-9]{32}$' then
    raise exception 'test_social_public_code_rotation';
  end if;

  select public.bil_social_resolve_public_code_v2(
    v_initial->>'code'
  ) into v_resolved;
  if v_resolved is not null then
    raise exception 'test_social_rotated_code_still_resolves';
  end if;

  select public.bil_social_resolve_public_code_v2(
    v_rotated->>'code'
  ) into v_resolved;
  if v_resolved->>'relationship' <> 'self'
     or v_resolved->>'user_id' <>
       '11000000-0000-4000-8000-000000000001' then
    raise exception 'test_social_self_code_resolution';
  end if;
end
$test_actor_public_code_round_trip$;
reset role;

-- Create a target code as that real synthetic user, then resolve it as actor.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000002',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select pg_catalog.set_config(
  'bil.test.target_code',
  public.bil_social_public_code_v2()->>'code',
  true
);
reset role;

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000001',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
do $test_target_code_resolution$
declare
  v_resolved jsonb;
begin
  select public.bil_social_resolve_public_code_v2(
    pg_catalog.current_setting('bil.test.target_code')
  ) into v_resolved;

  if v_resolved->>'user_id' <>
       '11000000-0000-4000-8000-000000000002'
     or v_resolved->>'display_name' <> 'Code Target'
     or v_resolved->>'relationship' <> 'none' then
    raise exception 'test_social_target_code_resolution';
  end if;

  if public.bil_social_resolve_public_code_v2('not-a-bil-code') is not null then
    raise exception 'test_social_invalid_code_must_fail_closed';
  end if;
end
$test_target_code_resolution$;

do $test_post_authors_batch$
declare
  v_count integer;
  v_target_count integer;
  v_self_count integer;
  v_oversized uuid[];
begin
  select
    pg_catalog.count(*),
    pg_catalog.count(*) filter (
      where author.user_id =
              '11000000-0000-4000-8000-000000000002'::uuid
        and author.handle is not null
        and author.relationship = 'none'
        and author.can_request
    ),
    pg_catalog.count(*) filter (
      where author.user_id =
              '11000000-0000-4000-8000-000000000001'::uuid
        and author.handle is not null
        and author.relationship = 'self'
        and not author.can_request
    )
  into v_count, v_target_count, v_self_count
  from public.bil_social_post_authors_v2(array[
    '11000000-0000-4000-8000-000000000002'::uuid,
    '11000000-0000-4000-8000-000000000001'::uuid,
    '11000000-0000-4000-8000-000000000002'::uuid,
    null
  ]) as author;

  if v_count <> 2 or v_target_count <> 1 or v_self_count <> 1 then
    raise exception 'test_social_post_authors_initial_state';
  end if;

  select pg_catalog.array_agg(pg_catalog.gen_random_uuid())
  into v_oversized
  from pg_catalog.generate_series(1, 101);

  begin
    perform public.bil_social_post_authors_v2(v_oversized);
    raise exception 'test_expected_post_authors_size_rejection';
  exception
    when sqlstate '22023' then
      if sqlerrm <> 'too_many_members' then
        raise;
      end if;
  end;
end
$test_post_authors_batch$;
reset role;

-- Private profiles and blocked pairs are intentionally indistinguishable.
update public.bil_public_profiles
set profile_visibility = 'private'
where user_id = '11000000-0000-4000-8000-000000000002';
set local role authenticated;
do $test_private_code_hidden$
begin
  if public.bil_social_resolve_public_code_v2(
       pg_catalog.current_setting('bil.test.target_code')
     ) is not null then
    raise exception 'test_social_private_code_visible';
  end if;

  if exists (
    select 1
    from public.bil_social_post_authors_v2(array[
      '11000000-0000-4000-8000-000000000002'::uuid
    ])
  ) then
    raise exception 'test_social_private_post_author_visible';
  end if;
end
$test_private_code_hidden$;
reset role;

update public.bil_public_profiles
set profile_visibility = 'public'
where user_id = '11000000-0000-4000-8000-000000000002';
insert into public.bil_blocks(blocker_id, blocked_id)
values (
  '11000000-0000-4000-8000-000000000002',
  '11000000-0000-4000-8000-000000000001'
);
set local role authenticated;
do $test_blocked_code_hidden$
begin
  if public.bil_social_resolve_public_code_v2(
       pg_catalog.current_setting('bil.test.target_code')
     ) is not null then
    raise exception 'test_social_blocked_code_visible';
  end if;

  if exists (
    select 1
    from public.bil_social_post_authors_v2(array[
      '11000000-0000-4000-8000-000000000002'::uuid
    ])
  ) then
    raise exception 'test_social_blocked_post_author_visible';
  end if;
end
$test_blocked_code_hidden$;
reset role;

delete from public.bil_blocks
where blocker_id = '11000000-0000-4000-8000-000000000002'
  and blocked_id = '11000000-0000-4000-8000-000000000001';

insert into private.bil_community_member_access(
  user_id, suspended, reason, suspended_by
) values (
  '11000000-0000-4000-8000-000000000001', true,
  'Synthetic Social v2 extension test suspension',
  '11000000-0000-4000-8000-000000000003'
);
set local role authenticated;
do $test_suspended_actor_fails_closed$
begin
  begin
    perform public.bil_social_save_v2(
      '11000000-0000-4000-8000-000000000101', true
    );
    raise exception 'test_expected_suspended_social_save_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'post_unavailable' then
        raise;
      end if;
  end;

  begin
    perform public.bil_social_public_code_v2();
    raise exception 'test_expected_suspended_public_code_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_unavailable' then
        raise;
      end if;
  end;

  begin
    perform public.bil_social_post_authors_v2(array[
      '11000000-0000-4000-8000-000000000002'::uuid
    ]);
    raise exception 'test_expected_suspended_post_authors_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_unavailable' then
        raise;
      end if;
  end;
end
$test_suspended_actor_fails_closed$;
reset role;

-- Direct table access stays closed while the reviewed authenticated RPCs work.
set local role authenticated;
do $test_rpc_only_tables$
begin
  begin
    perform pg_catalog.count(*)
    from public.bil_social_post_saves_v2;
    raise exception 'test_expected_direct_save_table_denial';
  exception
    when sqlstate '42501' then null;
  end;

  begin
    perform pg_catalog.count(*)
    from public.bil_social_public_codes_v2;
    raise exception 'test_expected_direct_code_table_denial';
  exception
    when sqlstate '42501' then null;
  end;
end
$test_rpc_only_tables$;
reset role;

rollback;
