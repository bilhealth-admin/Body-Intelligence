-- STAGED PROPOSAL ONLY. DO NOT APPLY TO PRODUCTION WITHOUT REVIEW.
-- Build a new migration with Supabase CLI after confirming live schema and permissions.
-- Cloud sync is NOT yet wired to Flutter local repository in this handoff.
begin;

create table if not exists public.bil_smart_plans (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  schema_version integer not null default 1 check (schema_version = 1),
  revision bigint not null default 1 check (revision > 0),
  horizon text not null check (horizon in ('week','month','threeMonths','sixMonths')),
  focus text not null check (focus in ('training','nutrition','combined')),
  status text not null check (status in ('draft','active','paused','completed')),
  start_day date not null,
  payload jsonb not null check (
    jsonb_typeof(payload) = 'object'
    and octet_length(payload::text) <= 250000
    and (payload->>'schema')::integer = 1
    and payload->>'ownerId' = owner_id::text
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (owner_id, id)
);

create unique index if not exists bil_smart_plans_one_active_per_owner_idx
  on public.bil_smart_plans(owner_id)
  where status='active' and deleted_at is null;

create index if not exists bil_smart_plans_owner_updated_idx
  on public.bil_smart_plans(owner_id, updated_at desc)
  where deleted_at is null;

create table if not exists public.bil_smart_plan_events (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  sequence bigint not null check (sequence > 0),
  event_type text not null check (
    event_type in ('created','approved','paused','resumed','workout_completed',
                   'workout_undone','plan_revision','deleted')
  ),
  payload jsonb not null default '{}'::jsonb check (
    jsonb_typeof(payload)='object' and octet_length(payload::text) <= 4096
  ),
  created_at timestamptz not null default now(),
  unique(plan_id, sequence),
  foreign key(owner_id, plan_id) references public.bil_smart_plans(owner_id, id)
    on delete cascade
);

alter table public.bil_smart_plans enable row level security;
alter table public.bil_smart_plan_events enable row level security;
revoke all on public.bil_smart_plans, public.bil_smart_plan_events
  from public, anon, authenticated;
grant select, insert, update, delete on public.bil_smart_plans
  to authenticated;
grant select, insert on public.bil_smart_plan_events
  to authenticated;
grant all on public.bil_smart_plans, public.bil_smart_plan_events
  to service_role;

create policy bil_smart_plans_select_own
  on public.bil_smart_plans for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy bil_smart_plans_insert_own
  on public.bil_smart_plans for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy bil_smart_plans_update_own
  on public.bil_smart_plans for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy bil_smart_plans_delete_own
  on public.bil_smart_plans for delete to authenticated
  using ((select auth.uid()) = owner_id);

create policy bil_smart_plan_events_select_own
  on public.bil_smart_plan_events for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy bil_smart_plan_events_insert_own
  on public.bil_smart_plan_events for insert to authenticated
  with check ((select auth.uid()) = owner_id);

-- Before deployment replace direct client UPDATE with an atomic
-- owner-verified compare-and-swap RPC, or UPDATE id+owner_id+revision
-- with readback. Do not use SECURITY DEFINER as an RLS shortcut.
-- Apply export/deletion integration and cleanup semantics before launch.
commit;
