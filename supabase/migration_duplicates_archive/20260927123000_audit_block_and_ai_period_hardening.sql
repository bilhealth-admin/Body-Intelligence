begin;

-- RLS on bil_blocks intentionally exposes only blocks created by the signed-in
-- member.  A narrow definer helper is therefore required for bilateral policy
-- checks without disclosing the identities of members who blocked that user.
create or replace function private.bil_is_blocked_with(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is null
    or p_other is null
    or exists (
      select 1
      from public.bil_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p_other)
         or (b.blocker_id = p_other and b.blocked_id = auth.uid())
    );
$$;

revoke all on function private.bil_is_blocked_with(uuid)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.bil_is_blocked_with(uuid)
  to authenticated;

drop policy if exists bil_posts_read on public.bil_community_posts;
create policy bil_posts_read on public.bil_community_posts
for select to authenticated
using (
  deleted_at is null
  and moderation_visibility = 'visible'
  and (
    author_id = (select auth.uid())
    or (
      moderation_status = 'approved'
      and not private.bil_is_blocked_with(author_id)
      and (
        visibility = 'community'
        or exists (
          select 1
          from public.bil_friendships f
          where f.status = 'accepted'
            and (
              (f.requester_id = author_id and f.addressee_id = (select auth.uid()))
              or
              (f.addressee_id = author_id and f.requester_id = (select auth.uid()))
            )
        )
      )
    )
  )
);

drop policy if exists bil_profiles_privacy_read on public.bil_public_profiles;
create policy bil_profiles_privacy_read on public.bil_public_profiles
for select to authenticated
using (
  user_id = (select auth.uid())
  or (
    not private.bil_is_blocked_with(user_id)
    and (
      (profile_visibility = 'public' and discoverable = true)
      or (
        profile_visibility = 'friends'
        and exists (
          select 1
          from public.bil_friendships f
          where f.status = 'accepted'
            and (
              (f.requester_id = (select auth.uid()) and f.addressee_id = user_id)
              or
              (f.addressee_id = (select auth.uid()) and f.requester_id = user_id)
            )
        )
      )
    )
  )
);

-- Attribute every weekly delta to the period represented by that weekly row,
-- never to the wall-clock month in which a later settlement happens.
create or replace function public.bil_sync_ai_monthly_usage()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_plan text := public.bil_resolve_ai_allowance_plan(new.owner_id);
  v_month date;
  v_used_delta bigint;
  v_reserved_delta bigint;
  v_limit bigint;
  v_total bigint;
begin
  if v_plan = 'trial' then
    v_month := new.week_start;
  else
    v_month := date_trunc('month', new.week_start)::date;
  end if;

  if tg_op = 'INSERT' then
    v_used_delta := new.used;
    v_reserved_delta := new.reserved;
  else
    v_used_delta := new.used - old.used;
    v_reserved_delta := new.reserved - old.reserved;
  end if;

  insert into public.bil_ai_credit_monthly_usage(owner_id, month_start)
    values(new.owner_id, v_month) on conflict do nothing;
  select monthly_limit into v_limit
  from public.bil_ai_credit_config
  where plan_id = v_plan;

  update public.bil_ai_credit_monthly_usage set
    used = greatest(used + v_used_delta, 0),
    reserved = greatest(reserved + v_reserved_delta, 0),
    updated_at = now()
  where owner_id = new.owner_id and month_start = v_month
  returning used + reserved into v_total;

  if v_used_delta + v_reserved_delta > 0
     and v_limit is not null
     and v_total > v_limit then
    raise exception 'ai_monthly_usage_exhausted';
  end if;
  return new;
end
$$;

-- Serialize reserve and settle for one owner before either implementation
-- takes period-row locks.  This removes the opposing month/week lock cycle
-- without serializing unrelated accounts.
alter function public.bil_reserve_ai_usage(uuid,text,text,numeric)
  rename to bil_reserve_ai_usage_unserialized;
alter function public.bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric)
  rename to bil_settle_ai_usage_unserialized;

revoke all on function public.bil_reserve_ai_usage_unserialized(uuid,text,text,numeric)
  from public, anon, authenticated, service_role;
revoke all on function public.bil_settle_ai_usage_unserialized(uuid,text,text,boolean,text,text,integer,integer,integer,numeric)
  from public, anon, authenticated, service_role;

create function public.bil_reserve_ai_usage(
  p_owner_id uuid,
  p_request_id text,
  p_capability text,
  p_units numeric default 1
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if p_owner_id is null then raise exception 'owner_required'; end if;
  perform pg_advisory_xact_lock(
    hashtextextended('bil.ai.' || p_owner_id::text, 0)
  );
  return public.bil_reserve_ai_usage_unserialized(
    p_owner_id, p_request_id, p_capability, p_units
  );
end
$$;

create function public.bil_settle_ai_usage(
  p_owner_id uuid,
  p_request_id text,
  p_capability text,
  p_succeeded boolean,
  p_provider text default null,
  p_model text default null,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_latency_ms integer default null,
  p_cost_usd numeric default null
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if p_owner_id is null then raise exception 'owner_required'; end if;
  perform pg_advisory_xact_lock(
    hashtextextended('bil.ai.' || p_owner_id::text, 0)
  );
  return public.bil_settle_ai_usage_unserialized(
    p_owner_id, p_request_id, p_capability, p_succeeded, p_provider, p_model,
    p_input_tokens, p_output_tokens, p_latency_ms, p_cost_usd
  );
end
$$;

revoke all on function public.bil_reserve_ai_usage(uuid,text,text,numeric)
  from public, anon, authenticated;
grant execute on function public.bil_reserve_ai_usage(uuid,text,text,numeric)
  to service_role;
revoke all on function public.bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric)
  from public, anon, authenticated;
grant execute on function public.bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric)
  to service_role;

commit;
