begin;
create table if not exists public.bil_coach_memories (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in (
    'user_fact','preference','constraint','goal','routine','pattern','commitment'
  )),
  memory_text text not null check (
    char_length(trim(memory_text)) between 1 and 500
  ),
  status text not null default 'confirmed' check (
    status in ('confirmed','inferred','expired')
  ),
  source text not null check (
    source in ('explicit_user_confirmation','verified_bil_record','coach_inference','experiment_outcome')
  ),
  confidence numeric(4,3) not null default 1 check (
    confidence between 0 and 1
  ),
  learned_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz,
  last_used_at timestamptz,
  deleted_at timestamptz,
  metadata jsonb not null default '{}'::jsonb check (
    jsonb_typeof(metadata) = 'object' and octet_length(metadata::text) <= 4000
  ),
  unique(owner_id,id)
);
create index if not exists bil_coach_memories_owner_active_idx
  on public.bil_coach_memories(owner_id, updated_at desc)
  where deleted_at is null;
create index if not exists bil_coach_memories_owner_kind_idx
  on public.bil_coach_memories(owner_id, kind)
  where deleted_at is null and status <> 'expired';
create table if not exists public.bil_coach_experiments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  hypothesis text not null check (char_length(trim(hypothesis)) between 1 and 800),
  changed_variable text not null check (char_length(trim(changed_variable)) between 1 and 300),
  controlled_factors text not null default '' check (char_length(controlled_factors) <= 1000),
  required_data text not null default '' check (char_length(required_data) <= 1000),
  started_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > started_at),
  adherence numeric(5,2) check (adherence between 0 and 100),
  result text check (result is null or char_length(result) <= 2000),
  confidence text not null default 'insufficient' check (
    confidence in ('insufficient','low','moderate')
  ),
  limitations text not null default '' check (char_length(limitations) <= 1500),
  status text not null default 'active' check (
    status in ('proposed','active','completed','cancelled')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique(owner_id,id)
);
create unique index if not exists bil_coach_experiments_one_active_idx
  on public.bil_coach_experiments(owner_id)
  where status = 'active' and deleted_at is null;
create index if not exists bil_coach_experiments_owner_history_idx
  on public.bil_coach_experiments(owner_id, started_at desc)
  where deleted_at is null;
alter table public.bil_coach_memories enable row level security;
alter table public.bil_coach_experiments enable row level security;
revoke all on public.bil_coach_memories, public.bil_coach_experiments
  from public, anon, authenticated;
grant select, insert, update, delete on
  public.bil_coach_memories, public.bil_coach_experiments
  to authenticated;
grant select, insert, update, delete on
  public.bil_coach_memories, public.bil_coach_experiments
  to service_role;
create policy bil_coach_memories_select_own
  on public.bil_coach_memories for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy bil_coach_memories_insert_own
  on public.bil_coach_memories for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy bil_coach_memories_update_own
  on public.bil_coach_memories for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy bil_coach_memories_delete_own
  on public.bil_coach_memories for delete to authenticated
  using ((select auth.uid()) = owner_id);
create policy bil_coach_experiments_select_own
  on public.bil_coach_experiments for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy bil_coach_experiments_insert_own
  on public.bil_coach_experiments for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy bil_coach_experiments_update_own
  on public.bil_coach_experiments for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy bil_coach_experiments_delete_own
  on public.bil_coach_experiments for delete to authenticated
  using ((select auth.uid()) = owner_id);
-- A privacy-safe observatory for the later allowance design. It exposes only
-- the signed-in user's aggregate request, token, latency, and provider cost.
create or replace function public.bil_get_ai_coach_cost_observatory()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_owner uuid := auth.uid();
  v_result jsonb := '{}'::jsonb;
  v_rows jsonb;
  v_days integer;
  v_label text;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  foreach v_days in array array[7,30,365] loop
    v_label := case v_days when 7 then 'weekly' when 30 then 'monthly' else 'annual' end;
    select coalesce(jsonb_agg(to_jsonb(summary) order by summary.capability, summary.model), '[]'::jsonb)
      into v_rows
      from (
        select
          capability,
          coalesce(model,'unknown') as model,
          count(*)::integer as requests,
          coalesce(sum(input_tokens),0)::bigint as input_tokens,
          coalesce(sum(output_tokens),0)::bigint as output_tokens,
          round(coalesce(avg(latency_ms),0),0)::integer as average_latency_ms,
          round(coalesce(sum(cost_usd),0),8) as cost_usd
        from public.bil_ai_usage_events
        where owner_id = v_owner
          and state = 'succeeded'
          and completed_at >= now() - make_interval(days => v_days)
        group by capability, coalesce(model,'unknown')
      ) summary;
    v_result := v_result || jsonb_build_object(v_label, v_rows);
  end loop;
  return jsonb_build_object('generated_at', now(), 'periods', v_result);
end
$$;
revoke all on function public.bil_get_ai_coach_cost_observatory()
  from public, anon;
grant execute on function public.bil_get_ai_coach_cost_observatory()
  to authenticated;
commit;
