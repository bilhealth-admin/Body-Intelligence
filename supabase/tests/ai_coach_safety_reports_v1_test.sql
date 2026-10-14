-- Transactional integration test for submit, authorized queue, idempotent
-- review and content minimization. Synthetic rows roll back at the end.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preflight$
begin
  if pg_catalog.to_regclass('private.bil_ai_coach_safety_reports_v1') is null
     or pg_catalog.to_regprocedure(
       'public.bil_submit_ai_coach_safety_report_v1(text,text,text,text,text,text,boolean)'
     ) is null
     or pg_catalog.to_regprocedure('public.bil_list_ai_coach_safety_reports_v1()') is null
     or pg_catalog.to_regprocedure(
       'public.bil_review_ai_coach_safety_report_v1(uuid,text,uuid)'
     ) is null then
    raise exception 'ai_coach_safety_report_test_requires_migration';
  end if;
  if pg_catalog.has_table_privilege(
       'authenticated', 'private.bil_ai_coach_safety_reports_v1', 'select'
     ) or pg_catalog.has_table_privilege(
       'anon', 'private.bil_ai_coach_safety_reports_v1', 'select'
     ) then
    raise exception 'ai_coach_safety_report_private_table_is_readable';
  end if;
end
$preflight$;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('14100000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'ai-report-owner@bil-test.invalid', '', pg_catalog.clock_timestamp(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
  ('14100000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'ai-report-moderator@bil-test.invalid', '', pg_catalog.clock_timestamp(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
  ('14100000-0000-4000-8000-000000000003', 'authenticated', 'authenticated',
   'ai-report-stranger@bil-test.invalid', '', pg_catalog.clock_timestamp(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp());
insert into public.bil_community_moderators(user_id)
values ('14100000-0000-4000-8000-000000000002');

create temporary table ai_coach_safety_report_test_state (
  first_report jsonb,
  duplicate_report jsonb,
  initial_queue jsonb,
  review_receipt jsonb,
  duplicate_review jsonb,
  reviewed_queue jsonb
);
grant all on table pg_temp.ai_coach_safety_report_test_state to authenticated;

-- The authenticated owner submits one exact answer. Repeating the same
-- response ID returns its receipt without replacing content or duplicating.
select pg_catalog.set_config('request.jwt.claim.sub', '14100000-0000-4000-8000-000000000001', true);
select pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
select pg_catalog.set_config('request.jwt.claims',
  '{"sub":"14100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
insert into pg_temp.ai_coach_safety_report_test_state(first_report)
select public.bil_submit_ai_coach_safety_report_v1(
  'coach-response-1410001', 'Only the answer; no prompt or profile.',
  'other', 'en-US', 'on_device', 'Please review this claim.', true
);
update pg_temp.ai_coach_safety_report_test_state
set duplicate_report = public.bil_submit_ai_coach_safety_report_v1(
  'coach-response-1410001', 'Retry text must not replace the answer.',
  'unsafe', 'fr', 'local_fallback', null, true
);
reset role;

do $retry_assert$
declare v_first jsonb; v_duplicate jsonb; v_count integer;
begin
  select first_report, duplicate_report into v_first, v_duplicate
  from pg_temp.ai_coach_safety_report_test_state;
  if v_first->>'status' <> 'open'
     or coalesce((v_first->>'duplicate')::boolean, true)
     or v_duplicate->>'report_id' <> v_first->>'report_id'
     or v_duplicate->>'status' <> 'open'
     or coalesce((v_duplicate->>'duplicate')::boolean, false) is not true then
    raise exception 'ai_coach_report_retry_receipt_invalid';
  end if;
  select pg_catalog.count(*)::integer into v_count
  from private.bil_ai_coach_safety_reports_v1
  where owner_id = '14100000-0000-4000-8000-000000000001'
    and response_id = 'coach-response-1410001';
  if v_count <> 1 then raise exception 'ai_coach_report_retry_not_unique'; end if;
end
$retry_assert$;

-- Authenticated users who are not a moderator cannot read the review queue.
select pg_catalog.set_config('request.jwt.claim.sub', '14100000-0000-4000-8000-000000000003', true);
select pg_catalog.set_config('request.jwt.claims',
  '{"sub":"14100000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;
do $non_moderator_assert$
declare v_denied boolean := false;
begin
  begin
    perform * from public.bil_list_ai_coach_safety_reports_v1();
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then raise exception 'non_moderator_read_ai_coach_report_queue'; end if;
end
$non_moderator_assert$;
reset role;

-- The moderator sees the exact answer and minimal metadata without the owner,
-- prompt, or surrounding conversation; review is idempotent and erases text.
select pg_catalog.set_config('request.jwt.claim.sub', '14100000-0000-4000-8000-000000000002', true);
select pg_catalog.set_config('request.jwt.claims',
  '{"sub":"14100000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
insert into pg_temp.ai_coach_safety_report_test_state(initial_queue)
select report_entry
from public.bil_list_ai_coach_safety_reports_v1() as queue(report_entry)
where report_entry->>'report_id' = (
  select first_report->>'report_id'
  from pg_temp.ai_coach_safety_report_test_state
);
insert into pg_temp.ai_coach_safety_report_test_state(review_receipt)
select public.bil_review_ai_coach_safety_report_v1(
  (first_report->>'report_id')::uuid,
  'confirmed_safety_issue',
  '14100000-0000-4000-8000-000000000098'
)
from pg_temp.ai_coach_safety_report_test_state;
update pg_temp.ai_coach_safety_report_test_state
set duplicate_review = public.bil_review_ai_coach_safety_report_v1(
  (first_report->>'report_id')::uuid,
  'confirmed_safety_issue',
  '14100000-0000-4000-8000-000000000098'
);
insert into pg_temp.ai_coach_safety_report_test_state(reviewed_queue)
select report_entry
from public.bil_list_ai_coach_safety_reports_v1() as queue(report_entry)
where report_entry->>'report_id' = (
  select first_report->>'report_id'
  from pg_temp.ai_coach_safety_report_test_state
);
reset role;

do $review_assert$
declare
  v_before jsonb;
  v_receipt jsonb;
  v_retry jsonb;
  v_after jsonb;
  v_answer text;
  v_note text;
  v_consented_at timestamptz;
begin
  select initial_queue, review_receipt, duplicate_review, reviewed_queue
  into v_before, v_receipt, v_retry, v_after
  from pg_temp.ai_coach_safety_report_test_state;
  if v_before is null
     or v_before->>'answer_text' <> 'Only the answer; no prompt or profile.'
     or v_before->>'user_note' <> 'Please review this claim.'
     or v_before ? 'owner_id' or v_before ? 'prompt' or v_before ? 'conversation'
     or v_receipt->>'status' <> 'reviewed'
     or v_receipt->>'decision' <> 'confirmed_safety_issue'
     or coalesce((v_retry->>'duplicate')::boolean, false) is not true
     or v_after->>'status' <> 'reviewed'
     or v_after->>'decision' <> 'confirmed_safety_issue'
     or v_after->'answer_text' is distinct from 'null'::jsonb
     or v_after->'user_note' is distinct from 'null'::jsonb then
    raise exception 'ai_coach_safety_review_contract_failed';
  end if;
  select answer_text, user_note, consented_at into v_answer, v_note, v_consented_at
  from private.bil_ai_coach_safety_reports_v1
  where report_id = (v_after->>'report_id')::uuid;
  if v_answer is not null or v_note is not null then
    raise exception 'reviewed_ai_report_content_not_erased';
  end if;
  if v_consented_at is null then raise exception 'ai_report_consent_not_recorded'; end if;
end
$review_assert$;

rollback;
