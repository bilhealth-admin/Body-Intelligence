-- Disposable PostgreSQL/Supabase fixture contract for BIL-05.
-- NOT_RUN in this handoff because the execution environment has no postgres/psql.
-- Run only after BASE schema + bil05_activity_reward_receipts_v1.sql are loaded
-- into a disposable loopback database. Never point this at Production.

begin;

-- Structural assertions that must be true before seeded behavior cases run.
do $test$
begin
  if to_regprocedure('public.bil_community_moderation_polls_v1(uuid[])') is null then
    raise exception 'missing_moderation_poll_projection';
  end if;
  if to_regprocedure('private.bil_emit_post_moderation_author_receipt_v1(uuid,jsonb)') is null then
    raise exception 'missing_author_receipt_emitter';
  end if;
  if has_function_privilege('authenticated',
       'private.bil_emit_post_moderation_author_receipt_v1(uuid,jsonb)',
       'EXECUTE') then
    raise exception 'private_receipt_emitter_exposed_to_authenticated';
  end if;
  if has_function_privilege('service_role',
       'public.bil_community_moderation_polls_v1(uuid[])',
       'EXECUTE') then
    raise exception 'moderation_poll_projection_exposed_to_service_role';
  end if;
end
$test$;

-- Seeded behavior matrix required when a disposable Supabase auth fixture is
-- available:
-- 1. approved + granted -> one reward_earned receipt, metadata +5/granted.
-- 2. approved + daily cap -> one challenge_update receipt, 0 tokens.
-- 3. rejected -> one challenge_update receipt, 0 tokens.
-- 4. same approval/retry -> source_key remains one row; no second credit grant.
-- 5. non-moderator calling poll RPC -> 42501.
-- 6. moderator poll RPC exposes question/options but zero vote totals/selection.
-- 7. notification recipient is post author; actor_id is null.
-- 8. deleting/recreating client call cannot create a duplicate receipt source_key.

rollback;
