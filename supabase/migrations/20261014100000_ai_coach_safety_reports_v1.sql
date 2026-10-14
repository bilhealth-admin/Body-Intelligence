-- Local additive contract only. Do not apply to Production without review.
-- Reports expose the exact AI answer the user chooses, plus an optional note;
-- the user's prompt, surrounding conversation, and health profile are excluded.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

create table private.bil_ai_coach_safety_reports_v1 (
  report_id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  response_id text not null check (length(response_id) between 8 and 128),
  answer_text text,
  user_note text,
  -- privacy remains valid for read-only compatibility with historical reports.
  reason text not null check (reason in (
    'unsafe', 'offensive', 'medical_accuracy', 'other', 'privacy'
  )),
  locale text not null check (locale ~ '^[a-z0-9-]{2,16}$'),
  runtime text not null check (runtime in (
    'cloud_personalized', 'on_device', 'local_fallback'
  )),
  check (answer_text is null or (
    length(btrim(answer_text)) between 1 and 12000
    and octet_length(answer_text) <= 60000
  )),
  check (user_note is null or (
    reason = 'other'
    and length(btrim(user_note)) between 1 and 1000
    and octet_length(user_note) <= 4000
  )),
  consented_at timestamptz,
  status text not null default 'open' check (status in ('open', 'reviewed')),
  decision text check (decision is null or decision in (
    'no_violation', 'confirmed_safety_issue'
  )),
  created_at timestamptz not null default clock_timestamp(),
  reviewed_by uuid,
  reviewed_at timestamptz,
  unique (owner_id, response_id),
  check (
    (status = 'open' and answer_text is not null and decision is null and reviewed_at is null)
    or
    (status = 'reviewed' and answer_text is null and decision is not null and reviewed_at is not null)
  )
);
create index bil_ai_coach_safety_reports_owner_created_v1_idx
  on private.bil_ai_coach_safety_reports_v1(owner_id, created_at desc);
create index bil_ai_coach_safety_reports_queue_v1_idx
  on private.bil_ai_coach_safety_reports_v1(status, created_at desc);
alter table private.bil_ai_coach_safety_reports_v1 enable row level security;
revoke all on table private.bil_ai_coach_safety_reports_v1
  from public, anon, authenticated, service_role;

create table private.bil_ai_coach_safety_report_decisions_v1 (
  actor_id uuid not null,
  operation_id uuid not null,
  report_id uuid not null references private.bil_ai_coach_safety_reports_v1(report_id) on delete cascade,
  request jsonb not null,
  receipt jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key (actor_id, operation_id)
);
alter table private.bil_ai_coach_safety_report_decisions_v1 enable row level security;
revoke all on table private.bil_ai_coach_safety_report_decisions_v1
  from public, anon, authenticated, service_role;

create function public.bil_submit_ai_coach_safety_report_v1(
  p_response_id text,
  p_answer_text text,
  p_reason text,
  p_locale text,
  p_runtime text,
  p_user_note text,
  p_consent_confirmed boolean
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_owner uuid := auth.uid();
  v_report private.bil_ai_coach_safety_reports_v1%rowtype;
  v_recent_count integer;
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_response_id is null or length(btrim(p_response_id)) not between 8 and 128
     or p_answer_text is null or length(btrim(p_answer_text)) not between 1 and 12000
     or octet_length(p_answer_text) > 60000
     or p_reason is null or p_reason not in ('unsafe', 'offensive', 'medical_accuracy', 'other')
     or p_locale is null or lower(btrim(p_locale)) !~ '^[a-z0-9-]{2,16}$'
     or p_runtime is null or p_runtime not in ('cloud_personalized', 'on_device', 'local_fallback')
     or p_consent_confirmed is distinct from true
     or (p_user_note is not null and (
       p_reason <> 'other'
       or length(btrim(p_user_note)) not between 1 and 1000
       or octet_length(p_user_note) > 4000
     )) then
    raise exception 'invalid_ai_coach_safety_report' using errcode = '22023';
  end if;
  if p_runtime = 'cloud_personalized' and not exists (
    select 1 from public.bil_ai_usage_events e
    where e.owner_id = v_owner
      and e.request_id = btrim(p_response_id)
      and e.capability = 'text'
      and e.state = 'succeeded'
  ) then
    raise exception 'unknown_ai_coach_response' using errcode = '42501';
  end if;

  -- Serialize retries for one owner before checking duplicate and daily quota.
  perform pg_advisory_xact_lock(
    hashtextextended('ai-coach-safety-report:' || v_owner::text, 0)
  );
  select * into v_report
  from private.bil_ai_coach_safety_reports_v1 r
  where r.owner_id = v_owner and r.response_id = btrim(p_response_id)
  for update;
  if found then
    return jsonb_build_object(
      'report_id', v_report.report_id,
      'status', v_report.status,
      'duplicate', true
    );
  end if;

  select count(*)::integer into v_recent_count
  from private.bil_ai_coach_safety_reports_v1 r
  where r.owner_id = v_owner and r.created_at >= clock_timestamp() - interval '24 hours';
  if v_recent_count >= 10 then
    raise exception 'ai_coach_safety_report_rate_limit_exceeded' using errcode = 'P0001';
  end if;

  insert into private.bil_ai_coach_safety_reports_v1(
    owner_id, response_id, answer_text, user_note, reason, locale, runtime, consented_at
  ) values (
    v_owner, btrim(p_response_id), p_answer_text, nullif(btrim(p_user_note), ''), p_reason,
    lower(btrim(p_locale)), p_runtime, clock_timestamp()
  ) returning * into v_report;
  return jsonb_build_object(
    'report_id', v_report.report_id,
    'status', v_report.status,
    'duplicate', false
  );
end
$$;
revoke all on function public.bil_submit_ai_coach_safety_report_v1(text, text, text, text, text, text, boolean)
  from public, anon;
grant execute on function public.bil_submit_ai_coach_safety_report_v1(text, text, text, text, text, text, boolean)
  to authenticated;

create function public.bil_list_ai_coach_safety_reports_v1()
returns setof jsonb
language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid();
begin
  perform private.bil_lock_community_authority_v1();
  return query
  select jsonb_build_object(
    'report_id', r.report_id,
    'reason', r.reason,
    'locale', r.locale,
    'runtime', r.runtime,
    'user_note', r.user_note,
    'status', r.status,
    'created_at', r.created_at,
    'answer_text', r.answer_text,
    'decision', r.decision,
    'reviewed_at', r.reviewed_at
  )
  from private.bil_ai_coach_safety_reports_v1 r
  where r.owner_id <> v_actor
    and (r.status = 'open' or r.reviewed_at >= clock_timestamp() - interval '30 days')
  order by r.created_at desc, r.report_id
  limit 100;
end
$$;
revoke all on function public.bil_list_ai_coach_safety_reports_v1()
  from public, anon;
grant execute on function public.bil_list_ai_coach_safety_reports_v1()
  to authenticated;

create function public.bil_review_ai_coach_safety_report_v1(
  p_report_id uuid,
  p_decision text,
  p_operation_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_report private.bil_ai_coach_safety_reports_v1%rowtype;
  v_prior record;
  v_request jsonb;
  v_receipt jsonb;
begin
  perform private.bil_lock_community_authority_v1();
  if v_actor is null or p_report_id is null or p_operation_id is null
     or p_decision is null or p_decision not in ('no_violation', 'confirmed_safety_issue') then
    raise exception 'invalid_ai_coach_safety_review' using errcode = '22023';
  end if;
  v_request := jsonb_build_object('report_id', p_report_id, 'decision', p_decision);
  perform pg_advisory_xact_lock(hashtextextended(
    'ai-coach-safety-review:' || v_actor::text || ':' || p_operation_id::text, 0
  ));
  select * into v_prior
  from private.bil_ai_coach_safety_report_decisions_v1 d
  where d.actor_id = v_actor and d.operation_id = p_operation_id;
  if found then
    if v_prior.request <> v_request then
      raise exception 'idempotency_conflict' using errcode = '22023';
    end if;
    return v_prior.receipt || jsonb_build_object('duplicate', true);
  end if;

  select * into v_report
  from private.bil_ai_coach_safety_reports_v1 r
  where r.report_id = p_report_id
  for update;
  if not found or v_report.status <> 'open' or v_report.owner_id = v_actor then
    raise exception 'ai_coach_report_unavailable' using errcode = '42501';
  end if;
  update private.bil_ai_coach_safety_reports_v1
  set status = 'reviewed',
      decision = p_decision,
      reviewed_by = v_actor,
      reviewed_at = clock_timestamp(),
      answer_text = null,
      user_note = null
  where report_id = p_report_id and status = 'open';
  if not found then
    raise exception 'ai_coach_report_review_readback_failed';
  end if;
  v_receipt := jsonb_build_object(
    'report_id', p_report_id,
    'status', 'reviewed',
    'decision', p_decision,
    'operation_id', p_operation_id,
    'duplicate', false
  );
  insert into private.bil_ai_coach_safety_report_decisions_v1(
    actor_id, operation_id, report_id, request, receipt
  ) values (v_actor, p_operation_id, p_report_id, v_request, v_receipt);
  return v_receipt;
end
$$;
revoke all on function public.bil_review_ai_coach_safety_report_v1(uuid, text, uuid)
  from public, anon;
grant execute on function public.bil_review_ai_coach_safety_report_v1(uuid, text, uuid)
  to authenticated;
commit;
