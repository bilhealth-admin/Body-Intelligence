-- Additive Coach/Smart Plan revision history. No user data rewrite or key changes.
begin;
create function bil_smart_plan_private.valid_payload_base_v1(p jsonb, actor uuid) returns boolean
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

-- A bounded reversible revision journal; the original payload validator above
-- remains byte-for-byte identical except its private function name.
create or replace function bil_smart_plan_private.valid_payload(p jsonb, actor uuid) returns boolean
language plpgsql immutable set search_path = '' as $$
declare base jsonb; change jsonb; before_day jsonb; dates text[]; setup jsonb;
  expected_revision bigint; previous_at timestamptz;
begin
  if jsonb_typeof(p) is distinct from 'object' or octet_length(p::text)>250000 then return false; end if;
  base := p - 'changes' - 'setup';
  if not bil_smart_plan_private.valid_payload_base_v1(base,actor) then return false; end if;
  if p ? 'setup' then
    setup:=p->'setup';
    if jsonb_typeof(setup) is distinct from 'object'
      or exists(select 1 from jsonb_object_keys(setup) k where k not in ('environment','experience','sessionMinutes','equipment','preferredTime','goalId'))
      or coalesce(setup->>'environment','') not in ('gym','home')
      or coalesce(setup->>'experience','') not in ('beginner','regular','experienced')
      or jsonb_typeof(setup->'sessionMinutes') is distinct from 'number'
      or setup->>'sessionMinutes' !~ '^[0-9]+$' or (setup->>'sessionMinutes')::integer not between 5 and 120
      or jsonb_typeof(setup->'equipment') is distinct from 'array' or jsonb_array_length(setup->'equipment')>12
      or exists(select 1 from jsonb_array_elements(setup->'equipment') e where jsonb_typeof(e)<>'string' or e#>>'{}' not in
        ('none','exercise mat','dumbbell pair','dumbbell single','long resistance band','mini loop band','flat resistance band','kettlebell single','gym'))
      or jsonb_array_length(setup->'equipment')<>(select count(distinct e) from jsonb_array_elements(setup->'equipment') e)
      or (setup->>'environment'='gym' and not setup->'equipment' ? 'gym')
      or (setup->>'environment'='home' and setup->'equipment' ? 'gym')
      or (setup ? 'preferredTime' and (jsonb_typeof(setup->'preferredTime') is distinct from 'string' or setup->>'preferredTime' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'))
      or (setup ? 'goalId' and (jsonb_typeof(setup->'goalId') is distinct from 'string' or setup->>'goalId' !~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$'))
      then return false; end if;
  end if;
  if not p ? 'changes' then return true; end if;
  if jsonb_typeof(p->'changes') is distinct from 'array' or jsonb_array_length(p->'changes')>32 then return false; end if;
  expected_revision := (p->>'revision')::bigint;
  for change in select value from jsonb_array_elements(p->'changes') loop
    if jsonb_typeof(change) is distinct from 'object'
      or exists(select 1 from jsonb_object_keys(change) k where k not in ('revision','at','previousUpdatedAt','reason','previousStatus','beforeDays'))
      or jsonb_typeof(change->'revision') is distinct from 'number'
      or change->>'revision' !~ '^[1-9][0-9]*$'
      or (change->>'revision')::numeric<>expected_revision or expected_revision<2
      or jsonb_typeof(change->'at') is distinct from 'string'
      or (change->>'at')::timestamptz<>(base->>'updatedAt')::timestamptz
      or jsonb_typeof(change->'previousUpdatedAt') is distinct from 'string'
      or coalesce(change->>'reason','') not in ('status','completion','correction','schedule','travel','fatigue','equipment','mealSwap')
      or coalesce(change->>'previousStatus','') not in ('draft','active','paused','completed')
      or jsonb_typeof(change->'beforeDays') is distinct from 'array'
      or jsonb_array_length(change->'beforeDays')>14 then return false; end if;
    previous_at := (change->>'previousUpdatedAt')::timestamptz;
    if previous_at>(change->>'at')::timestamptz or previous_at<(p->>'createdAt')::timestamptz then return false; end if;
    dates := '{}';
    for before_day in select value from jsonb_array_elements(change->'beforeDays') loop
      if jsonb_typeof(before_day) is distinct from 'object' or before_day->>'date'=any(dates)
        or not exists(select 1 from jsonb_array_elements(base->'days') d where d->>'date'=before_day->>'date') then return false; end if;
      dates := array_append(dates,before_day->>'date');
      base := jsonb_set(base,'{days}',(select jsonb_agg(case when d->>'date'=before_day->>'date' then before_day else d end order by n)
        from jsonb_array_elements(base->'days') with ordinality days(d,n)));
    end loop;
    base := base || jsonb_build_object('status',change->>'previousStatus','revision',expected_revision-1,'updatedAt',change->>'previousUpdatedAt');
    if not bil_smart_plan_private.valid_payload_base_v1(base,actor) then return false; end if;
    expected_revision := expected_revision-1;
  end loop;
  return true;
exception when others then return false;
end $$;
revoke all on function bil_smart_plan_private.valid_payload_base_v1(jsonb,uuid) from public,anon,authenticated;
revoke all on function bil_smart_plan_private.valid_payload(jsonb,uuid) from public,anon,authenticated;
commit;
