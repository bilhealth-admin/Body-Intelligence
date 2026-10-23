-- Owner-authorized additive Smart Plan sync for iOS38/Android33.
-- Existing account data, encryption keys and commerce authorities are unchanged.
begin;
create schema if not exists bil_smart_plan_private;
revoke all on schema bil_smart_plan_private from public, anon, authenticated;

-- Validate the same bounded schema as the client. Invalid content is refused,
-- never coerced. Catalog approval is checked by clients before suggestion/use.
create function bil_smart_plan_private.valid_payload(p jsonb, actor uuid) returns boolean
language plpgsql immutable set search_path = '' as $$
declare d jsonb; w jsonb; m jsonb; i integer:=0; start_day date;
  expected_days integer; slots text[]; ids text[];
begin
  if jsonb_typeof(p) is distinct from 'object' or octet_length(p::text)>250000
    or p->>'ownerId' is distinct from actor::text or p->'schema' is distinct from '1'::jsonb
    or jsonb_typeof(p->'id') is distinct from 'string' or p->>'id' !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$'
    or jsonb_typeof(p->'revision') is distinct from 'number' or p->>'revision' !~ '^[1-9][0-9]*$'
    or (p->>'revision')::numeric>2147483647
    or coalesce(p->>'status','') not in ('draft','active','paused','completed')
    or coalesce(p->>'horizon','') not in ('week','month','threeMonths','sixMonths')
    or coalesce(p->>'focus','') not in ('training','nutrition','combined')
    or jsonb_typeof(p->'startDate') is distinct from 'string' or p->>'startDate' !~ '^\d{4}-\d{2}-\d{2}$'
    or jsonb_typeof(p->'createdAt') is distinct from 'string' or jsonb_typeof(p->'updatedAt') is distinct from 'string'
    or p->>'createdAt' !~ '^\d{4}-\d{2}-\d{2}T' or p->>'updatedAt' !~ '^\d{4}-\d{2}-\d{2}T'
    or (p->>'updatedAt')::timestamptz < (p->>'createdAt')::timestamptz
    or jsonb_typeof(p->'days') is distinct from 'array'
    or exists(select 1 from jsonb_object_keys(p) k where k not in ('schema','id','ownerId','revision','status','horizon','focus','startDate','createdAt','updatedAt','days'))
    then return false; end if;
  start_day := (p->>'startDate')::date;
  expected_days := case p->>'horizon' when 'week' then 7
    when 'month' then (start_day+interval '1 month')::date-start_day
    when 'threeMonths' then (start_day+interval '3 months')::date-start_day
    else (start_day+interval '6 months')::date-start_day end;
  if jsonb_array_length(p->'days')<>expected_days then return false; end if;
  for d in select value from jsonb_array_elements(p->'days') loop
    if jsonb_typeof(d) is distinct from 'object'
      or d->>'date' is distinct from to_char(start_day+i,'YYYY-MM-DD')
      or jsonb_typeof(d->'phase') is distinct from 'string' or length(trim(d->>'phase')) not between 1 and 120
      or jsonb_typeof(d->'meals') is distinct from 'array' or not d ? 'workout'
      or exists(select 1 from jsonb_object_keys(d) k where k not in ('date','phase','workout','meals'))
      then return false; end if;
    if (p->>'focus'='training' and jsonb_array_length(d->'meals')<>0)
      or (p->>'focus'<>'training' and jsonb_array_length(d->'meals')<>3)
      or (p->>'focus'='nutrition' and d->'workout'<>'null'::jsonb) then return false; end if;
    slots:='{}';
    for m in select value from jsonb_array_elements(d->'meals') loop
      if jsonb_typeof(m) is distinct from 'object' or coalesce(m->>'slot','') not in ('breakfast','lunch','dinner')
        or m->>'slot'=any(slots) or jsonb_typeof(m->'recipeId') is distinct from 'string'
        or m->>'recipeId' !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$'
        or exists(select 1 from jsonb_object_keys(m) k where k not in ('slot','recipeId')) then return false; end if;
      slots:=array_append(slots,m->>'slot');
    end loop;
    w:=d->'workout';
    if w<>'null'::jsonb then
      if jsonb_typeof(w) is distinct from 'object'
        or jsonb_typeof(w->'templateId') is distinct from 'string' or w->>'templateId' !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$'
        or jsonb_typeof(w->'minutes') is distinct from 'number' or w->>'minutes' !~ '^[0-9]+$' or (w->>'minutes')::integer not between 5 and 120
        or jsonb_typeof(w->'completed') is distinct from 'boolean'
        or (p->>'status'='draft' and w->>'completed'='true')
        or (w->'effort' is not null and w->'effort'<>'null'::jsonb and (
          w->>'completed'<>'true' or jsonb_typeof(w->'effort')<>'number' or w->>'effort' !~ '^[0-9]+$' or (w->>'effort')::integer not between 1 and 10))
        or jsonb_typeof(w->'exerciseIds') is distinct from 'array' or jsonb_array_length(w->'exerciseIds') not between 1 and 12
        or exists(select 1 from jsonb_array_elements(w->'exerciseIds') e where jsonb_typeof(e)<>'string' or e#>>'{}' !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$')
        or exists(select 1 from jsonb_object_keys(w) k where k not in ('templateId','exerciseIds','minutes','completed','effort')) then return false; end if;
      select array_agg(value) into ids from jsonb_array_elements_text(w->'exerciseIds');
      if cardinality(ids)<>(select count(distinct x) from unnest(ids) x) then return false; end if;
    end if;
    i:=i+1;
  end loop;
  return true;
exception when others then return false;
end $$;
revoke all on function bil_smart_plan_private.valid_payload(jsonb,uuid) from public,anon,authenticated;

create table public.bil_smart_plan_sync_state (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null check (revision > 0),
  payload jsonb,
  updated_at timestamptz not null default now(),
  constraint smart_plan_payload_owner check (payload is null or
    bil_smart_plan_private.valid_payload(payload, owner_id) is true)
);
create table bil_smart_plan_private.consent (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  granted boolean not null,
  version text not null,
  updated_at timestamptz not null default now()
);
alter table public.bil_smart_plan_sync_state enable row level security;
alter table bil_smart_plan_private.consent enable row level security;
revoke all on public.bil_smart_plan_sync_state from public, anon, authenticated;
revoke all on bil_smart_plan_private.consent from public, anon, authenticated;
grant select on public.bil_smart_plan_sync_state to authenticated;
create policy smart_plan_read_owner on public.bil_smart_plan_sync_state
  for select to authenticated using ((select auth.uid()) = owner_id);

-- Definer is confined to this private schema because client table writes are
-- revoked. Explicit auth.uid ownership is mandatory; no owner argument exists.
create function bil_smart_plan_private.access_owner() returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if not exists (select 1 from bil_smart_plan_private.consent c
      where c.owner_id=actor and c.granted and c.version='smart-plan-cloud-v1') then
    raise exception 'smart_plan_consent_required' using errcode='42501';
  end if;
  return actor;
end $$;
revoke all on function bil_smart_plan_private.access_owner() from public, anon, authenticated;

create function public.bil_smart_plan_consent_v1(granted boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null or granted is null then raise exception 'authentication_required' using errcode='42501'; end if;
  -- Serialize consent revocation and all payload writes for this owner.
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 3822));
  insert into bil_smart_plan_private.consent(owner_id,granted,version)
    values(actor,granted,'smart-plan-cloud-v1') on conflict(owner_id) do update
      set granted=excluded.granted, version=excluded.version, updated_at=now();
  if not granted then
    update public.bil_smart_plan_sync_state set payload=null, revision=revision+1, updated_at=now()
      where owner_id=actor;
  end if;
end $$;

create function public.bil_smart_plan_read_v1() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := bil_smart_plan_private.access_owner(); result jsonb;
begin
  select jsonb_build_object('revision',s.revision,'payload',s.payload) into result
    from public.bil_smart_plan_sync_state s where s.owner_id=actor;
  return coalesce(result,jsonb_build_object('revision',0,'payload',null));
end $$;

create function public.bil_smart_plan_cas_v1(expected_revision bigint, next_payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result jsonb;
begin
  if actor is null then raise exception 'authentication_required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text,3822));
  perform bil_smart_plan_private.access_owner();
  if expected_revision is null or expected_revision < 0 then raise exception 'invalid_revision'; end if;
  if next_payload is not null and not public.bil_has_active_premium(actor) then
    raise exception 'verified_premium_required' using errcode='42501';
  end if;
  if expected_revision=0 then
    insert into public.bil_smart_plan_sync_state(owner_id,revision,payload)
      values(actor,1,next_payload) on conflict(owner_id) do nothing;
    if not found then raise exception 'smart_plan_revision_conflict' using errcode='40001'; end if;
  else
    update public.bil_smart_plan_sync_state set payload=next_payload,
      revision=revision+1,updated_at=now() where owner_id=actor and revision=expected_revision;
    if not found then raise exception 'smart_plan_revision_conflict' using errcode='40001'; end if;
  end if;
  select jsonb_build_object('revision',s.revision,'payload',s.payload) into result
    from public.bil_smart_plan_sync_state s where s.owner_id=actor;
  return result;
end $$;
revoke all on function public.bil_smart_plan_consent_v1(boolean),
  public.bil_smart_plan_read_v1(), public.bil_smart_plan_cas_v1(bigint,jsonb) from public, anon;
grant execute on function public.bil_smart_plan_consent_v1(boolean),
  public.bil_smart_plan_read_v1(), public.bil_smart_plan_cas_v1(bigint,jsonb) to authenticated;
commit;
