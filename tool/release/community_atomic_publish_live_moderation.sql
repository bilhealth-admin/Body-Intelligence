
-- Live read-only moderation dependency extension, captured 2026-10-04 UTC.
create table public.bil_ai_credit_balances(
owner_id uuid not null,
granted bigint default 0 not null,
used bigint default 0 not null,
reserved bigint default 0 not null,
updated_at timestamp with time zone default now() not null,
refund_debt bigint default 0 not null
);
create table public.bil_community_post_approval_grants(
post_id uuid not null,
owner_id uuid not null,
approved_by uuid,
reward_day date default (timezone('UTC'::text, now()))::date not null,
tokens integer default 5 not null,
reward_reason text default 'granted'::text not null,
granted_at timestamp with time zone default now() not null
);
create table public.bil_community_post_reward_policy(
singleton boolean default true not null,
tokens_per_approval integer default 5 not null,
max_rewarded_posts_per_owner_per_utc_day integer default 5 not null,
updated_at timestamp with time zone default now() not null
);
create table public.bil_community_post_reward_usage(
owner_id uuid not null,
reward_day date not null,
rewarded_posts integer default 0 not null,
granted_tokens integer default 0 not null,
updated_at timestamp with time zone default now() not null
);
alter table public.bil_ai_credit_balances add constraint bil_ai_credit_balance_not_overdrawn CHECK (((used + reserved) <= granted));
alter table public.bil_ai_credit_balances add constraint bil_ai_credit_balances_granted_check CHECK ((granted >= 0));
alter table public.bil_ai_credit_balances add constraint bil_ai_credit_balances_pkey PRIMARY KEY (owner_id);
alter table public.bil_ai_credit_balances add constraint bil_ai_credit_balances_refund_debt_check CHECK ((refund_debt >= 0));
alter table public.bil_ai_credit_balances add constraint bil_ai_credit_balances_reserved_check CHECK ((reserved >= 0));
alter table public.bil_ai_credit_balances add constraint bil_ai_credit_balances_used_check CHECK ((used >= 0));
alter table public.bil_community_post_approval_grants add constraint bil_community_post_approval_grants_pkey PRIMARY KEY (post_id);
alter table public.bil_community_post_approval_grants add constraint bil_community_post_approval_grants_reward_reason_check CHECK ((reward_reason = ANY (ARRAY['granted'::text, 'daily_cap_reached'::text])));
alter table public.bil_community_post_approval_grants add constraint bil_community_post_approval_grants_tokens_check CHECK ((tokens = ANY (ARRAY[0, 5])));
alter table public.bil_community_post_reward_policy add constraint bil_community_post_reward_po_max_rewarded_posts_per_owner_check CHECK (((max_rewarded_posts_per_owner_per_utc_day >= 1) AND (max_rewarded_posts_per_owner_per_utc_day <= 100)));
alter table public.bil_community_post_reward_policy add constraint bil_community_post_reward_policy_pkey PRIMARY KEY (singleton);
alter table public.bil_community_post_reward_policy add constraint bil_community_post_reward_policy_singleton_check CHECK (singleton);
alter table public.bil_community_post_reward_policy add constraint bil_community_post_reward_policy_tokens_per_approval_check CHECK ((tokens_per_approval = 5));
alter table public.bil_community_post_reward_usage add constraint bil_community_post_reward_usage_check CHECK ((granted_tokens = (rewarded_posts * 5)));
alter table public.bil_community_post_reward_usage add constraint bil_community_post_reward_usage_granted_tokens_check CHECK ((granted_tokens >= 0));
alter table public.bil_community_post_reward_usage add constraint bil_community_post_reward_usage_pkey PRIMARY KEY (owner_id, reward_day);
alter table public.bil_community_post_reward_usage add constraint bil_community_post_reward_usage_rewarded_posts_check CHECK ((rewarded_posts >= 0));
alter table public.bil_ai_credit_balances add constraint bil_ai_credit_balances_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_community_post_approval_grants add constraint bil_community_post_approval_grants_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.bil_community_post_approval_grants add constraint bil_community_post_approval_grants_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_community_post_reward_usage add constraint bil_community_post_reward_usage_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE OR REPLACE FUNCTION public.bil_collect_ai_credit_refund_debt()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_collect bigint;
begin
  v_collect := least(new.refund_debt,greatest(new.granted-new.used-new.reserved,0));
  new.granted := new.granted-v_collect;
  new.refund_debt := new.refund_debt-v_collect;
  return new;
end
$function$;
CREATE TRIGGER bil_collect_ai_credit_refund_debt BEFORE INSERT OR UPDATE ON public.bil_ai_credit_balances FOR EACH ROW EXECUTE FUNCTION bil_collect_ai_credit_refund_debt();
CREATE OR REPLACE FUNCTION public.bil_moderate_community_post(p_post_id uuid, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := (select auth.uid());
  v_post public.bil_community_posts%rowtype;
  v_decision text := lower(trim(coalesce(p_decision, '')));
  v_reward_day date :=
    (pg_catalog.timezone('UTC', pg_catalog.clock_timestamp())::date);
  v_reward_tokens integer := 0;
  v_reward_reason text := 'not_applicable';
  v_daily_cap integer;
  v_rewarded_posts integer;
  v_grant_inserted integer := 0;
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_actor) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;
  if v_decision not in ('approved', 'rejected') then
    raise exception 'invalid_post_moderation_decision';
  end if;

  select p.* into v_post
  from public.bil_community_posts p
  where p.id = p_post_id
  for update;

  if not found or v_post.deleted_at is not null then
    raise exception 'post_not_found';
  end if;
  if v_post.author_id = v_actor then
    raise exception 'moderator_cannot_review_own_post'
      using errcode = '42501';
  end if;

  -- A retry of the same completed request is a read-only success. A different
  -- second decision is rejected instead of silently rewriting human history.
  if v_post.moderation_status = v_decision then
    return jsonb_build_object(
      'post_id', v_post.id,
      'decision', v_decision,
      'duplicate', true,
      'tokens_granted', 0,
      'reward_reason', 'duplicate_decision'
    );
  end if;
  if v_post.moderation_status <> 'pending' then
    raise exception 'post_already_moderated';
  end if;

  update public.bil_community_posts p
  set moderation_status = v_decision,
      reviewed_at = now()
  where p.id = v_post.id;

  if v_decision = 'approved' then
    select
      policy.tokens_per_approval,
      policy.max_rewarded_posts_per_owner_per_utc_day
      into v_reward_tokens, v_daily_cap
    from public.bil_community_post_reward_policy policy
    where policy.singleton
    for share;

    if not found then
      raise exception 'community_reward_policy_unavailable';
    end if;

    insert into public.bil_community_post_reward_usage(
      owner_id,
      reward_day
    ) values (
      v_post.author_id,
      v_reward_day
    )
    on conflict (owner_id, reward_day) do nothing;

    select usage.rewarded_posts
      into v_rewarded_posts
    from public.bil_community_post_reward_usage usage
    where usage.owner_id = v_post.author_id
      and usage.reward_day = v_reward_day
    for update;

    if v_rewarded_posts >= v_daily_cap then
      v_reward_tokens := 0;
      v_reward_reason := 'daily_cap_reached';
    else
      v_reward_reason := 'granted';
    end if;

    insert into public.bil_community_post_approval_grants(
      post_id,
      owner_id,
      approved_by,
      reward_day,
      tokens,
      reward_reason
    ) values (
      v_post.id,
      v_post.author_id,
      v_actor,
      v_reward_day,
      v_reward_tokens,
      v_reward_reason
    )
    on conflict (post_id) do nothing;
    get diagnostics v_grant_inserted = row_count;

    if v_grant_inserted = 1 and v_reward_tokens > 0 then
      update public.bil_community_post_reward_usage usage
      set rewarded_posts = usage.rewarded_posts + 1,
          granted_tokens = usage.granted_tokens + v_reward_tokens,
          updated_at = pg_catalog.clock_timestamp()
      where usage.owner_id = v_post.author_id
        and usage.reward_day = v_reward_day;

      insert into public.bil_ai_credit_balances(owner_id, granted)
      values (v_post.author_id, v_reward_tokens)
      on conflict (owner_id) do update set
        granted = public.bil_ai_credit_balances.granted + excluded.granted,
        updated_at = pg_catalog.clock_timestamp();
    elsif v_grant_inserted = 0 then
      -- A pre-existing immutable receipt wins over a malformed replay. No
      -- second balance mutation is ever attempted.
      v_reward_tokens := 0;
      v_reward_reason := 'duplicate_receipt';
    end if;
  end if;

  insert into public.bil_community_audit_events(
    actor_id,
    event_kind,
    target_kind,
    target_id,
    metadata
  ) values (
    v_actor,
    'POST_REVIEW',
    'community_post',
    v_post.id::text,
    jsonb_build_object(
      'decision', v_decision,
      'tokens_granted', case
        when v_grant_inserted = 1 then v_reward_tokens
        else 0
      end,
      'reward_reason', v_reward_reason,
      'reward_day', case
        when v_decision = 'approved' then v_reward_day::text
        else null
      end,
      'daily_reward_cap', case
        when v_decision = 'approved' then v_daily_cap
        else null
      end
    )
  );

  return jsonb_build_object(
    'post_id', v_post.id,
    'decision', v_decision,
    'duplicate', false,
    'tokens_granted', case
      when v_grant_inserted = 1 then v_reward_tokens
      else 0
    end,
    'reward_reason', v_reward_reason
  );
end
$function$;
revoke all on function public.bil_moderate_community_post(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.bil_moderate_community_post(uuid,text) to authenticated;
alter table public.bil_ai_credit_balances enable row level security;
revoke all on table public.bil_ai_credit_balances from public,anon,authenticated,service_role;
alter table public.bil_community_post_approval_grants enable row level security;
revoke all on table public.bil_community_post_approval_grants from public,anon,authenticated,service_role;
alter table public.bil_community_post_reward_policy enable row level security;
revoke all on table public.bil_community_post_reward_policy from public,anon,authenticated,service_role;
alter table public.bil_community_post_reward_usage enable row level security;
revoke all on table public.bil_community_post_reward_usage from public,anon,authenticated,service_role;

