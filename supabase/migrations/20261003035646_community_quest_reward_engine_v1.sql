-- Community Quest / Reward Engine v1.
-- No quest is active by default and reward caps default to zero. This keeps
-- production fail-closed until product copy, destinations, and economics are
-- deliberately configured.
set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_quest_definitions') is not null
     or to_regclass('public.bil_community_quest_progress') is not null
     or to_regclass('public.bil_community_quest_progress_events') is not null
     or to_regclass('public.bil_community_reward_policy') is not null
     or to_regclass('public.bil_community_reward_claim_audit') is not null then
    raise exception 'community_quest_reward_v1_already_exists';
  end if;
  if to_regprocedure(
    'private.bil_post_gold_ledger_v1(uuid,bigint,text,text,text,text,text,bigint)'
  ) is null then
    raise exception 'bil_gold_v1_required';
  end if;
  if to_regprocedure(
    'private.bil_post_community_xp_v1(uuid,bigint,text,text,text,text,text,bigint)'
  ) is null then
    raise exception 'community_xp_v1_required';
  end if;
  if to_regprocedure(
    'public.bil_list_community_activity_v2(timestamptz,uuid,text[],integer)'
  ) is null then
    raise exception 'community_activity_v2_required';
  end if;
end
$$;

create table public.bil_community_reward_policy (
  singleton boolean primary key default true check (singleton),
  max_quest_gold_per_owner_per_utc_day bigint not null default 0
    check (max_quest_gold_per_owner_per_utc_day between 0 and 1000000000),
  max_quest_gold_per_owner_per_utc_week bigint not null default 0
    check (max_quest_gold_per_owner_per_utc_week between 0 and 5000000000),
  max_quest_xp_per_owner_per_utc_day bigint not null default 0
    check (max_quest_xp_per_owner_per_utc_day between 0 and 1000000000),
  max_quest_xp_per_owner_per_utc_week bigint not null default 0
    check (max_quest_xp_per_owner_per_utc_week between 0 and 5000000000),
  updated_at timestamptz not null default pg_catalog.clock_timestamp()
);

insert into public.bil_community_reward_policy(singleton) values(true);

create table public.bil_community_quest_definitions (
  quest_key text primary key
    check (quest_key ~ '^[a-z][a-z0-9_]{2,39}$'),
  cadence text not null check (cadence in ('daily','weekly','one_time')),
  title_copy_key text not null
    check (title_copy_key ~ '^[a-z][a-z0-9_]{2,63}$'),
  subtitle_copy_key text not null
    check (subtitle_copy_key ~ '^[a-z][a-z0-9_]{2,63}$'),
  action_kind text not null
    check (action_kind ~ '^[a-z][a-z0-9_]{2,47}$'),
  target_count integer not null check (target_count between 1 and 1000000),
  claim_mode text not null check (claim_mode in ('manual','auto')),
  gold_reward bigint not null default 0
    check (gold_reward between 0 and 1000000000),
  xp_reward bigint not null default 0
    check (xp_reward between 0 and 1000000000),
  policy_version integer not null default 1
    check (policy_version between 1 and 1000000),
  active boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint bil_community_quest_has_reward
    check (gold_reward > 0 or xp_reward > 0),
  constraint bil_community_quest_window
    check (starts_at is null or ends_at is null or starts_at < ends_at)
);

create index bil_community_quest_active_action_idx
  on public.bil_community_quest_definitions(action_kind,quest_key)
  where active;

create table public.bil_community_quest_progress (
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_key text not null
    references public.bil_community_quest_definitions(quest_key)
    on delete restrict,
  period_key text not null check (char_length(period_key) between 4 and 16),
  progress bigint not null default 0 check (progress >= 0),
  target_snapshot bigint not null check (target_snapshot between 1 and 1000000),
  gold_reward_snapshot bigint not null check (
    gold_reward_snapshot between 0 and 1000000000
  ),
  xp_reward_snapshot bigint not null check (
    xp_reward_snapshot between 0 and 1000000000
  ),
  policy_version_snapshot integer not null
    check (policy_version_snapshot between 1 and 1000000),
  state text not null check (
    state in ('pending','ready_to_claim','claimed')
  ),
  started_at timestamptz not null default pg_catalog.clock_timestamp(),
  completed_at timestamptz,
  claimed_at timestamptz,
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(owner_id,quest_key,period_key),
  constraint bil_community_quest_progress_state_times check (
    (state='pending' and completed_at is null and claimed_at is null)
    or
    (state='ready_to_claim' and completed_at is not null and claimed_at is null)
    or
    (state='claimed' and completed_at is not null and claimed_at is not null)
  )
);

create index bil_community_quest_progress_quest_idx
  on public.bil_community_quest_progress(quest_key,owner_id,period_key);

create table public.bil_community_quest_progress_events (
  id bigint generated by default as identity primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_key text not null
    references public.bil_community_quest_definitions(quest_key)
    on delete restrict,
  period_key text not null check (char_length(period_key) between 4 and 16),
  source_key text not null check (char_length(source_key) between 16 and 160),
  increment bigint not null check (increment between 1 and 1000000),
  reference_kind text
    check (reference_kind is null or reference_kind ~ '^[a-z][a-z0-9_]{2,47}$'),
  reference_id text
    check (reference_id is null or char_length(reference_id) between 1 and 160),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint bil_community_quest_progress_event_unique
    unique(owner_id,quest_key,period_key,source_key),
  constraint bil_community_quest_progress_event_reference_pair
    check ((reference_kind is null)=(reference_id is null))
);

create index bil_community_quest_events_quest_idx
  on public.bil_community_quest_progress_events(
    quest_key,owner_id,period_key,created_at desc,id desc
  );

create table public.bil_community_reward_claim_audit (
  id bigint generated by default as identity primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  quest_key text not null,
  period_key text not null,
  action text not null check (
    action in (
      'manual_attempt',
      'manual_success',
      'auto_success',
      'blocked',
      'duplicate'
    )
  ),
  gold_reward bigint not null default 0 check (gold_reward >= 0),
  xp_reward bigint not null default 0 check (xp_reward >= 0),
  reason text not null check (char_length(reason) between 2 and 120),
  created_at timestamptz not null default pg_catalog.clock_timestamp()
);

create index bil_community_reward_claim_audit_owner_idx
  on public.bil_community_reward_claim_audit(
    owner_id,created_at desc,id desc
  );

alter table public.bil_community_reward_policy enable row level security;
alter table public.bil_community_quest_definitions enable row level security;
alter table public.bil_community_quest_progress enable row level security;
alter table public.bil_community_quest_progress_events enable row level security;
alter table public.bil_community_reward_claim_audit enable row level security;

revoke all on table public.bil_community_reward_policy
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_quest_definitions
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_quest_progress
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_quest_progress_events
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_reward_claim_audit
  from public,anon,authenticated,service_role;

create or replace function private.bil_community_quest_period_key_v1(
  p_cadence text,
  p_at timestamptz default pg_catalog.clock_timestamp()
)
returns text
language plpgsql
stable
set search_path=''
as $$
begin
  return case p_cadence
    when 'daily' then pg_catalog.to_char(
      pg_catalog.timezone('UTC',p_at),
      'YYYY-MM-DD'
    )
    when 'weekly' then pg_catalog.to_char(
      pg_catalog.timezone('UTC',p_at),
      'IYYY-"W"IW'
    )
    when 'one_time' then 'once'
    else null
  end;
end
$$;

revoke all on function private.bil_community_quest_period_key_v1(
  text,timestamptz
) from public,anon,authenticated,service_role;

create or replace function private.bil_emit_community_activity_v2(
  p_recipient uuid,
  p_actor uuid,
  p_kind text,
  p_source_key text,
  p_entity_kind text,
  p_entity_id text,
  p_copy_key text,
  p_deep_link_path text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_existing public.bil_community_notifications%rowtype;
  v_id uuid;
begin
  if p_recipient is null or not exists(
    select 1 from auth.users u where u.id=p_recipient
  ) then
    raise exception 'activity_recipient_invalid' using errcode='22023';
  end if;
  if p_actor is not null and not exists(
    select 1 from auth.users u where u.id=p_actor
  ) then
    raise exception 'activity_actor_invalid' using errcode='22023';
  end if;
  if p_source_key is null
     or char_length(p_source_key) not between 16 and 128 then
    raise exception 'activity_source_key_invalid' using errcode='22023';
  end if;
  if p_metadata is null
     or pg_catalog.jsonb_typeof(p_metadata)<>'object'
     or pg_catalog.octet_length(p_metadata::text)>4096 then
    raise exception 'activity_metadata_invalid' using errcode='22023';
  end if;

  select * into v_existing
  from public.bil_community_notifications n
  where n.source_key=p_source_key;

  if found then
    if v_existing.recipient_id is distinct from p_recipient
       or v_existing.actor_id is distinct from p_actor
       or v_existing.kind is distinct from p_kind
       or v_existing.entity_kind is distinct from p_entity_kind
       or v_existing.entity_id is distinct from p_entity_id
       or v_existing.copy_key is distinct from p_copy_key
       or v_existing.deep_link_path is distinct from p_deep_link_path
       or v_existing.metadata is distinct from p_metadata then
      raise exception 'activity_source_payload_mismatch'
        using errcode='22023';
    end if;
    return v_existing.id;
  end if;

  insert into public.bil_community_notifications(
    recipient_id,
    actor_id,
    kind,
    friendship_id,
    source_key,
    entity_kind,
    entity_id,
    copy_key,
    deep_link_path,
    metadata
  ) values(
    p_recipient,
    p_actor,
    p_kind,
    null,
    p_source_key,
    p_entity_kind,
    p_entity_id,
    p_copy_key,
    p_deep_link_path,
    p_metadata
  )
  returning id into v_id;

  return v_id;
end
$$;

revoke all on function private.bil_emit_community_activity_v2(
  uuid,uuid,text,text,text,text,text,text,jsonb
) from public,anon,authenticated,service_role;

create or replace function private.bil_settle_community_quest_reward_v1(
  p_owner uuid,
  p_quest_key text,
  p_period_key text,
  p_trigger text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_progress public.bil_community_quest_progress%rowtype;
  v_policy public.bil_community_reward_policy%rowtype;
  v_now timestamptz:=pg_catalog.clock_timestamp();
  v_day_start timestamptz:=pg_catalog.date_trunc('day',v_now at time zone 'UTC') at time zone 'UTC';
  v_week_start timestamptz:=pg_catalog.date_trunc('week',v_now at time zone 'UTC') at time zone 'UTC';
  v_day_gold bigint;
  v_week_gold bigint;
  v_day_xp bigint;
  v_week_xp bigint;
  v_gold_result jsonb;
  v_xp_result jsonb;
  v_reason text;
begin
  if p_trigger not in ('manual','auto') then
    raise exception 'quest_claim_trigger_invalid' using errcode='22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('bil_community_rewards:'||p_owner::text,0)
  );

  select * into v_progress
  from public.bil_community_quest_progress p
  where p.owner_id=p_owner
    and p.quest_key=p_quest_key
    and p.period_key=p_period_key
  for update;

  if not found then
    return pg_catalog.jsonb_build_object(
      'status','not_ready',
      'reason','progress_missing'
    );
  end if;

  if v_progress.state='claimed' then
    insert into public.bil_community_reward_claim_audit(
      owner_id,quest_key,period_key,action,gold_reward,xp_reward,reason
    ) values(
      p_owner,p_quest_key,p_period_key,'duplicate',
      v_progress.gold_reward_snapshot,v_progress.xp_reward_snapshot,
      'already_claimed'
    );
    return pg_catalog.jsonb_build_object(
      'status','claimed',
      'duplicate',true,
      'gold',v_progress.gold_reward_snapshot,
      'xp',v_progress.xp_reward_snapshot
    );
  end if;

  if v_progress.state<>'ready_to_claim' then
    return pg_catalog.jsonb_build_object(
      'status','not_ready',
      'reason','target_not_reached'
    );
  end if;

  select * into v_policy
  from public.bil_community_reward_policy
  where singleton
  for share;

  if not found then
    raise exception 'community_reward_policy_unavailable';
  end if;

  select coalesce(sum(l.delta),0) into v_day_gold
  from public.bil_gold_ledger l
  where l.owner_id=p_owner
    and l.source_kind='quest_reward'
    and l.delta>0
    and l.created_at>=v_day_start;

  select coalesce(sum(l.delta),0) into v_week_gold
  from public.bil_gold_ledger l
  where l.owner_id=p_owner
    and l.source_kind='quest_reward'
    and l.delta>0
    and l.created_at>=v_week_start;

  select coalesce(sum(l.delta),0) into v_day_xp
  from public.bil_community_xp_ledger l
  where l.owner_id=p_owner
    and l.source_kind='quest_reward'
    and l.delta>0
    and l.created_at>=v_day_start;

  select coalesce(sum(l.delta),0) into v_week_xp
  from public.bil_community_xp_ledger l
  where l.owner_id=p_owner
    and l.source_kind='quest_reward'
    and l.delta>0
    and l.created_at>=v_week_start;

  v_reason:=case
    when v_progress.gold_reward_snapshot>0
      and v_day_gold+v_progress.gold_reward_snapshot>
        v_policy.max_quest_gold_per_owner_per_utc_day
      then 'daily_gold_cap'
    when v_progress.gold_reward_snapshot>0
      and v_week_gold+v_progress.gold_reward_snapshot>
        v_policy.max_quest_gold_per_owner_per_utc_week
      then 'weekly_gold_cap'
    when v_progress.xp_reward_snapshot>0
      and v_day_xp+v_progress.xp_reward_snapshot>
        v_policy.max_quest_xp_per_owner_per_utc_day
      then 'daily_xp_cap'
    when v_progress.xp_reward_snapshot>0
      and v_week_xp+v_progress.xp_reward_snapshot>
        v_policy.max_quest_xp_per_owner_per_utc_week
      then 'weekly_xp_cap'
    else null
  end;

  if v_reason is not null then
    insert into public.bil_community_reward_claim_audit(
      owner_id,quest_key,period_key,action,gold_reward,xp_reward,reason
    ) values(
      p_owner,p_quest_key,p_period_key,'blocked',
      v_progress.gold_reward_snapshot,v_progress.xp_reward_snapshot,v_reason
    );
    return pg_catalog.jsonb_build_object(
      'status','blocked',
      'reason',v_reason
    );
  end if;

  if v_progress.gold_reward_snapshot>0 then
    v_gold_result:=private.bil_post_gold_ledger_v1(
      p_owner,
      v_progress.gold_reward_snapshot,
      'quest_reward',
      'quest_reward:'||p_quest_key||':'||p_period_key||':gold',
      'gold_quest_reward',
      'quest',
      p_quest_key||':'||p_period_key,
      null
    );
  end if;

  if v_progress.xp_reward_snapshot>0 then
    v_xp_result:=private.bil_post_community_xp_v1(
      p_owner,
      v_progress.xp_reward_snapshot,
      'quest_reward',
      'quest_reward:'||p_quest_key||':'||p_period_key||':xp',
      'community_xp_quest_reward',
      'quest',
      p_quest_key||':'||p_period_key,
      null
    );
  end if;

  update public.bil_community_quest_progress
  set state='claimed',
      claimed_at=v_now,
      updated_at=v_now
  where owner_id=p_owner
    and quest_key=p_quest_key
    and period_key=p_period_key;

  perform private.bil_emit_community_activity_v2(
    p_owner,
    null,
    'reward_earned',
    'quest_reward:'||p_owner::text||':'||p_quest_key||':'||p_period_key,
    'reward',
    p_quest_key||':'||p_period_key,
    'reward_earned_v1',
    '/community/rewards',
    pg_catalog.jsonb_build_object(
      'quest_key',p_quest_key,
      'gold',v_progress.gold_reward_snapshot,
      'xp',v_progress.xp_reward_snapshot
    )
  );

  insert into public.bil_community_reward_claim_audit(
    owner_id,quest_key,period_key,action,gold_reward,xp_reward,reason
  ) values(
    p_owner,p_quest_key,p_period_key,
    case when p_trigger='auto' then 'auto_success' else 'manual_success' end,
    v_progress.gold_reward_snapshot,v_progress.xp_reward_snapshot,'granted'
  );

  return pg_catalog.jsonb_build_object(
    'status','claimed',
    'duplicate',false,
    'gold',v_progress.gold_reward_snapshot,
    'xp',v_progress.xp_reward_snapshot,
    'gold_entry_id',v_gold_result->>'entry_id',
    'xp_entry_id',v_xp_result->>'entry_id'
  );
end
$$;

revoke all on function private.bil_settle_community_quest_reward_v1(
  uuid,text,text,text
) from public,anon,authenticated,service_role;

create or replace function private.bil_record_community_quest_progress_v1(
  p_owner uuid,
  p_quest_key text,
  p_increment bigint,
  p_source_key text,
  p_reference_kind text default null,
  p_reference_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_definition public.bil_community_quest_definitions%rowtype;
  v_progress public.bil_community_quest_progress%rowtype;
  v_period text;
  v_inserted integer;
  v_now timestamptz:=pg_catalog.clock_timestamp();
  v_new_progress bigint;
  v_completed_now boolean:=false;
  v_settlement jsonb;
begin
  if p_owner is null or not exists(
    select 1 from auth.users u where u.id=p_owner
  ) then
    raise exception 'quest_owner_invalid' using errcode='22023';
  end if;
  if exists(
    select 1
    from private.bil_community_member_access a
    where a.user_id=p_owner and a.suspended
  ) then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;
  if p_increment is null or p_increment<1 or p_increment>1000000 then
    raise exception 'quest_increment_invalid' using errcode='22023';
  end if;
  if p_source_key is null or char_length(p_source_key) not between 16 and 160 then
    raise exception 'quest_progress_source_invalid' using errcode='22023';
  end if;
  if (p_reference_kind is null)<>(p_reference_id is null) then
    raise exception 'quest_progress_reference_invalid' using errcode='22023';
  end if;

  select * into v_definition
  from public.bil_community_quest_definitions q
  where q.quest_key=p_quest_key
    and q.active
    and (q.starts_at is null or q.starts_at<=v_now)
    and (q.ends_at is null or q.ends_at>v_now)
  for share;

  if not found then
    return pg_catalog.jsonb_build_object(
      'status','inactive',
      'duplicate',false
    );
  end if;

  v_period:=private.bil_community_quest_period_key_v1(
    v_definition.cadence,
    v_now
  );
  if v_period is null then
    raise exception 'quest_cadence_invalid';
  end if;

  insert into public.bil_community_quest_progress(
    owner_id,
    quest_key,
    period_key,
    progress,
    target_snapshot,
    gold_reward_snapshot,
    xp_reward_snapshot,
    policy_version_snapshot,
    state
  ) values(
    p_owner,
    p_quest_key,
    v_period,
    0,
    v_definition.target_count,
    v_definition.gold_reward,
    v_definition.xp_reward,
    v_definition.policy_version,
    'pending'
  )
  on conflict(owner_id,quest_key,period_key) do nothing;

  select * into v_progress
  from public.bil_community_quest_progress p
  where p.owner_id=p_owner
    and p.quest_key=p_quest_key
    and p.period_key=v_period
  for update;

  if v_progress.state='claimed' then
    return pg_catalog.jsonb_build_object(
      'status','claimed',
      'duplicate',true,
      'period_key',v_period,
      'progress',v_progress.progress,
      'target',v_progress.target_snapshot
    );
  end if;

  insert into public.bil_community_quest_progress_events(
    owner_id,quest_key,period_key,source_key,increment,
    reference_kind,reference_id
  ) values(
    p_owner,p_quest_key,v_period,p_source_key,p_increment,
    p_reference_kind,p_reference_id
  )
  on conflict(owner_id,quest_key,period_key,source_key) do nothing;
  get diagnostics v_inserted=row_count;

  if v_inserted=0 then
    return pg_catalog.jsonb_build_object(
      'status',v_progress.state,
      'duplicate',true,
      'period_key',v_period,
      'progress',v_progress.progress,
      'target',v_progress.target_snapshot
    );
  end if;

  v_new_progress:=least(
    v_progress.progress+p_increment,
    v_progress.target_snapshot
  );

  if v_progress.state='pending'
     and v_new_progress>=v_progress.target_snapshot then
    v_completed_now:=true;
    update public.bil_community_quest_progress
    set progress=v_new_progress,
        state='ready_to_claim',
        completed_at=v_now,
        updated_at=v_now
    where owner_id=p_owner
      and quest_key=p_quest_key
      and period_key=v_period;

    perform private.bil_emit_community_activity_v2(
      p_owner,
      null,
      'quest_completed',
      'quest_complete:'||p_owner::text||':'||p_quest_key||':'||v_period,
      'quest',
      p_quest_key||':'||v_period,
      'quest_completed_v1',
      '/community/rewards',
      pg_catalog.jsonb_build_object(
        'quest_key',p_quest_key,
        'period_key',v_period
      )
    );

    if v_definition.claim_mode='auto' then
      v_settlement:=private.bil_settle_community_quest_reward_v1(
        p_owner,p_quest_key,v_period,'auto'
      );
    end if;
  else
    update public.bil_community_quest_progress
    set progress=v_new_progress,
        updated_at=v_now
    where owner_id=p_owner
      and quest_key=p_quest_key
      and period_key=v_period;
  end if;

  select * into v_progress
  from public.bil_community_quest_progress p
  where p.owner_id=p_owner
    and p.quest_key=p_quest_key
    and p.period_key=v_period;

  return pg_catalog.jsonb_build_object(
    'status',v_progress.state,
    'duplicate',false,
    'completed_now',v_completed_now,
    'period_key',v_period,
    'progress',v_progress.progress,
    'target',v_progress.target_snapshot,
    'settlement',v_settlement
  );
end
$$;

revoke all on function private.bil_record_community_quest_progress_v1(
  uuid,text,bigint,text,text,text
) from public,anon,authenticated,service_role;

create or replace function private.bil_record_community_action_v1(
  p_owner uuid,
  p_action_kind text,
  p_source_key text,
  p_reference_kind text default null,
  p_reference_id text default null
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_quest record;
  v_count integer:=0;
  v_now timestamptz:=pg_catalog.clock_timestamp();
begin
  if p_action_kind is null
     or p_action_kind !~ '^[a-z][a-z0-9_]{2,47}$' then
    raise exception 'community_action_kind_invalid' using errcode='22023';
  end if;
  if p_source_key is null or char_length(p_source_key) not between 16 and 160 then
    raise exception 'community_action_source_invalid' using errcode='22023';
  end if;

  for v_quest in
    select q.quest_key
    from public.bil_community_quest_definitions q
    where q.active
      and q.action_kind=p_action_kind
      and (q.starts_at is null or q.starts_at<=v_now)
      and (q.ends_at is null or q.ends_at>v_now)
    order by q.quest_key
  loop
    perform private.bil_record_community_quest_progress_v1(
      p_owner,
      v_quest.quest_key,
      1,
      p_source_key,
      p_reference_kind,
      p_reference_id
    );
    v_count:=v_count+1;
  end loop;

  return v_count;
end
$$;

revoke all on function private.bil_record_community_action_v1(
  uuid,text,text,text,text
) from public,anon,authenticated,service_role;

create or replace function public.bil_list_community_quests_v1()
returns table(
  quest_key text,
  cadence text,
  title_copy_key text,
  subtitle_copy_key text,
  action_kind text,
  target_count integer,
  claim_mode text,
  gold_reward bigint,
  xp_reward bigint,
  period_key text,
  progress bigint,
  state text,
  completed_at timestamptz,
  claimed_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_owner uuid:=(select auth.uid());
  v_now timestamptz:=pg_catalog.clock_timestamp();
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if exists(
    select 1
    from private.bil_community_member_access a
    where a.user_id=v_owner and a.suspended
  ) then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;

  return query
  select
    q.quest_key,
    q.cadence,
    q.title_copy_key,
    q.subtitle_copy_key,
    q.action_kind,
    q.target_count,
    q.claim_mode,
    q.gold_reward,
    q.xp_reward,
    private.bil_community_quest_period_key_v1(q.cadence,v_now),
    coalesce(p.progress,0),
    coalesce(p.state,'go'),
    p.completed_at,
    p.claimed_at
  from public.bil_community_quest_definitions q
  left join public.bil_community_quest_progress p
    on p.owner_id=v_owner
   and p.quest_key=q.quest_key
   and p.period_key=private.bil_community_quest_period_key_v1(q.cadence,v_now)
  where q.active
    and (q.starts_at is null or q.starts_at<=v_now)
    and (q.ends_at is null or q.ends_at>v_now)
  order by
    case q.cadence when 'daily' then 1 when 'weekly' then 2 else 3 end,
    q.quest_key;
end
$$;

create or replace function public.bil_claim_community_quest_v1(
  p_quest_key text,
  p_period_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_owner uuid:=(select auth.uid());
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_quest_key is null
     or p_quest_key !~ '^[a-z][a-z0-9_]{2,39}$'
     or p_period_key is null
     or char_length(p_period_key) not between 4 and 16 then
    raise exception 'quest_claim_input_invalid' using errcode='22023';
  end if;
  if exists(
    select 1
    from private.bil_community_member_access a
    where a.user_id=v_owner and a.suspended
  ) then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;

  insert into public.bil_community_reward_claim_audit(
    owner_id,quest_key,period_key,action,gold_reward,xp_reward,reason
  )
  select
    v_owner,p_quest_key,p_period_key,'manual_attempt',
    p.gold_reward_snapshot,p.xp_reward_snapshot,'requested'
  from public.bil_community_quest_progress p
  where p.owner_id=v_owner
    and p.quest_key=p_quest_key
    and p.period_key=p_period_key;

  return private.bil_settle_community_quest_reward_v1(
    v_owner,p_quest_key,p_period_key,'manual'
  );
end
$$;

revoke all on function public.bil_list_community_quests_v1()
  from public,anon,service_role;
grant execute on function public.bil_list_community_quests_v1()
  to authenticated;

revoke all on function public.bil_claim_community_quest_v1(text,text)
  from public,anon,service_role;
grant execute on function public.bil_claim_community_quest_v1(text,text)
  to authenticated;

do $$
begin
  if to_regprocedure('private.bil_emit_community_activity_v2(uuid,uuid,text,text,text,text,text,text,jsonb)') is null
     or to_regprocedure('private.bil_record_community_action_v1(uuid,text,text,text,text)') is null
     or to_regprocedure('private.bil_record_community_quest_progress_v1(uuid,text,bigint,text,text,text)') is null
     or to_regprocedure('private.bil_settle_community_quest_reward_v1(uuid,text,text,text)') is null
     or to_regprocedure('public.bil_list_community_quests_v1()') is null
     or to_regprocedure('public.bil_claim_community_quest_v1(text,text)') is null then
    raise exception 'community_quest_reward_v1_postcondition_failed';
  end if;
end
$$;
