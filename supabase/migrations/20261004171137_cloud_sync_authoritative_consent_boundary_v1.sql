-- Server-authoritative cloud-sync disclosure boundary, verified against LIVE
-- 2026-10-04: health envelopes must not cross RPC or direct SELECT after decline.
-- Device inventory/revocation and consent readback remain available when OFF.
-- Payload encryption is not a substitute for transport/storage consent.
set local lock_timeout='3s';
set local statement_timeout='30s';

do $cloud_consent_drift$
begin
  if not exists (select 1 from pg_catalog.pg_proc p
      where p.oid=pg_catalog.to_regprocedure('public.bil_sync_records(text,bigint,jsonb)')
        and pg_catalog.md5(p.prosrc)='d3237c2b3beac0ba7adbdd8f15f3d71f'
        and p.prosecdef and p.proowner='postgres'::regrole
        and p.proconfig=array['search_path=pg_catalog, public'])
     or not exists (select 1 from pg_catalog.pg_proc p
      where p.oid=pg_catalog.to_regprocedure('public.bil_record_consent(text,text,boolean)')
        and pg_catalog.md5(p.prosrc)='f24db8e42092990a5d01e16df26ec165'
        and p.prosecdef and p.proowner='postgres'::regrole
        and p.proconfig=array['search_path=public, pg_temp']) then
    raise exception 'cloud_consent_source_drift' using errcode='55000';
  end if;
  if (select count(*) from pg_catalog.pg_class c
      where c.oid in ('public.bil_cloud_records'::regclass,
        'public.bil_cloud_operations'::regclass,'public.bil_consent_receipts'::regclass)
        and c.relrowsecurity and c.relowner='postgres'::regrole)<>3
     or exists (select 1 from pg_catalog.pg_policy p
      where p.polrelid in ('public.bil_cloud_records'::regclass,
        'public.bil_cloud_operations'::regclass)
        and p.polname in ('bil_cloud_records_current_consent_select_v1',
          'bil_cloud_operations_current_consent_select_v1')) then
    raise exception 'cloud_consent_policy_drift' using errcode='55000';
  end if;
end
$cloud_consent_drift$;

-- Transactional, short DDL. Existing payload/receipt writes finish first;
-- timeouts abort the whole forward change rather than leaving partial guards.
lock table public.bil_cloud_operations, public.bil_cloud_records,
  public.bil_consent_receipts in share row exclusive mode;

CREATE OR REPLACE FUNCTION public.bil_sync_records(p_device_id text, p_cursor bigint DEFAULT 0, p_operations jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_owner uuid := auth.uid();
  v_operation jsonb;
  v_record jsonb;
  v_acknowledged jsonb := '[]'::jsonb;
  v_records jsonb;
  v_cursor bigint;
  v_operation_id text;
  v_has_more boolean := false;
  v_cloud_consent boolean;
begin
  if v_owner is null then
    raise exception 'authentication_required';
  end if;
  if p_device_id is null
     or length(trim(p_device_id)) < 8
     or length(trim(p_device_id)) > 200 then
    raise exception 'invalid_device_id';
  end if;
  if jsonb_typeof(p_operations) <> 'array'
     or jsonb_array_length(p_operations) > 100 then
    raise exception 'invalid_sync_batch';
  end if;

  -- All writes for one owner pass this lock before allocating a sequence.
  -- Therefore a committed cursor cannot jump over a later commit carrying a
  -- lower sequence number.
  perform pg_advisory_xact_lock(
    hashtextextended('bil.sync.' || v_owner::text, 0)
  );

  -- Exact current disclosure must be the latest purpose receipt; a newer
  -- denial/unknown version or any denial tied at the same timestamp wins.
  -- bil_record_consent uses this SAME owner lock, including absent receipts.
  select receipt.granted and receipt.policy_version = '1'
    into v_cloud_consent
  from public.bil_consent_receipts receipt
  where receipt.user_id = v_owner and receipt.purpose = 'cloud_sync'
  order by receipt.recorded_at desc, receipt.granted asc,
    receipt.policy_version desc
  limit 1;
  if v_cloud_consent is distinct from true then
    raise exception 'cloud_sync_consent_required' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.bil_cloud_devices
    where owner_id = v_owner
      and device_id = p_device_id
      and revoked_at is not null
  ) then
    raise exception 'device_revoked';
  end if;

  insert into public.bil_cloud_devices(
    owner_id, device_id, platform, app_version, created_at, last_seen_at
  ) values (
    v_owner, p_device_id, 'unknown', null, now(), now()
  )
  on conflict (owner_id, device_id) do update
  set last_seen_at = now();

  for v_operation in select value from jsonb_array_elements(p_operations)
  loop
    v_record := v_operation -> 'record';
    v_operation_id := trim(v_operation ->> 'operation_id');
    if v_operation_id is null
       or length(v_operation_id) < 3
       or length(v_operation_id) > 512 then
      raise exception 'invalid_operation_id';
    end if;
    if v_operation ->> 'mutation' not in ('upsert', 'delete') then
      raise exception 'invalid_mutation';
    end if;
    if v_record ->> 'entity_kind' not in (
      'profile', 'goal', 'weight', 'measurement', 'nutrition', 'hydration',
      'sleep', 'activity', 'decisionMemory', 'intelligenceOutput', 'coach',
      'community', 'file', 'settings'
    ) then
      raise exception 'invalid_entity_kind';
    end if;
    if (v_operation ->> 'mutation' = 'delete') <>
       (v_record ->> 'deleted_at' is not null) then
      raise exception 'mutation_tombstone_mismatch';
    end if;
    if v_record ->> 'revision_device_id' <> p_device_id then
      raise exception 'device_revision_mismatch';
    end if;
    if (v_record ->> 'updated_at')::timestamptz > now() + interval '5 minutes'
       or (v_record ->> 'schema_version')::integer < 1
       or (v_record ->> 'revision_sequence')::bigint < 0
       or length(v_record ->> 'record_id') > 512
       or pg_column_size(coalesce(v_record -> 'payload', '{}'::jsonb)) > 1048576 then
      raise exception 'invalid_record';
    end if;
    if exists (
      select 1 from public.bil_cloud_operations
      where owner_id = v_owner and operation_id = v_operation_id
    ) then
      v_acknowledged := v_acknowledged || jsonb_build_array(v_operation_id);
      continue;
    end if;

    insert into public.bil_cloud_records (
      owner_id, entity_kind, record_id, device_id, revision_device_id,
      revision_sequence, client_updated_at, updated_at, deleted_at,
      schema_version, payload
    ) values (
      v_owner, v_record ->> 'entity_kind', v_record ->> 'record_id',
      v_record ->> 'revision_device_id', v_record ->> 'revision_device_id',
      (v_record ->> 'revision_sequence')::bigint,
      (v_record ->> 'updated_at')::timestamptz,
      (v_record ->> 'updated_at')::timestamptz,
      nullif(v_record ->> 'deleted_at', '')::timestamptz,
      (v_record ->> 'schema_version')::integer,
      coalesce(v_record -> 'payload', '{}'::jsonb)
    )
    on conflict (owner_id, entity_kind, record_id) do update set
      device_id = excluded.device_id,
      revision_device_id = excluded.revision_device_id,
      revision_sequence = excluded.revision_sequence,
      client_updated_at = excluded.client_updated_at,
      updated_at = excluded.updated_at,
      deleted_at = excluded.deleted_at,
      schema_version = excluded.schema_version,
      payload = excluded.payload,
      change_sequence = nextval('public.bil_cloud_change_sequence')
    where excluded.updated_at > bil_cloud_records.updated_at
       or (excluded.updated_at = bil_cloud_records.updated_at
           and excluded.revision_sequence > bil_cloud_records.revision_sequence);

    insert into public.bil_cloud_operations(owner_id, operation_id, device_id)
    values (v_owner, v_operation_id, p_device_id);
    v_acknowledged := v_acknowledged || jsonb_build_array(v_operation_id);
  end loop;

  with page as (
    select owner_id, entity_kind, record_id, revision_device_id,
      revision_sequence, updated_at, deleted_at, schema_version, payload,
      change_sequence
    from public.bil_cloud_records
    where owner_id = v_owner
      and change_sequence > greatest(p_cursor, 0)
    order by change_sequence
    limit 100
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'owner_id', owner_id,
    'entity_kind', entity_kind,
    'record_id', record_id,
    'revision_device_id', revision_device_id,
    'revision_sequence', revision_sequence,
    'updated_at', updated_at,
    'deleted_at', deleted_at,
    'schema_version', schema_version,
    'payload', payload
  ) order by change_sequence), '[]'::jsonb),
  coalesce(max(change_sequence), greatest(p_cursor, 0))
  into v_records, v_cursor
  from page;

  select exists (
    select 1 from public.bil_cloud_records
    where owner_id = v_owner and change_sequence > v_cursor
  ) into v_has_more;

  return jsonb_build_object(
    'acknowledged', v_acknowledged,
    'records', v_records,
    'cursor', v_cursor,
    'has_more', v_has_more
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.bil_record_consent(p_purpose text, p_policy_version text, p_granted boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_recorded_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if p_purpose not in (
      'health','camera','microphone','photos','notifications','devices',
      'remote_ai','cloud_sync','meal_vision_ai'
    )
    or length(trim(p_policy_version)) not between 1 and 64 then
    raise exception 'invalid_consent';
  end if;
  if p_purpose = 'cloud_sync' then
    -- One order for grant/revoke versus sync, including first-ever receipt and
    -- different policy versions. Row locks alone do not serialize those cases.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('bil.sync.' || auth.uid()::text, 0)
    );
    -- Stamp AFTER waiting: transaction-start now() can misorder a later
    -- committed revocation from an earlier-started transaction.
    v_recorded_at := pg_catalog.clock_timestamp();
  else
    -- All other purpose validation/upsert/timestamp behavior is unchanged.
    v_recorded_at := pg_catalog.now();
  end if;
  insert into public.bil_consent_receipts(
    user_id, purpose, policy_version, granted, recorded_at
  ) values (
    auth.uid(), p_purpose, trim(p_policy_version), coalesce(p_granted, false), v_recorded_at
  )
  on conflict(user_id, purpose, policy_version) do update
    set granted = excluded.granted, recorded_at = excluded.recorded_at;
end;
$function$;

-- Keep the existing ownership policies and ACLs, but AND a statement-scoped
-- consent gate with EVERY permissive authenticated SELECT. No new table grants,
-- exposed helper, or direct-write capability. The independent scalar lookup is
-- eligible for an initPlan; receipt PK already indexes (user_id,purpose,...).
-- A SELECT is authorized against its statement snapshot. A read already begun
-- before a concurrent revoke cannot be retroactively unsent; subsequent reads
-- see the denial. RPC writes are serialized with revocation by the owner lock.
create policy bil_cloud_records_current_consent_select_v1
on public.bil_cloud_records as restrictive for select to authenticated
using (coalesce((select receipt.granted and receipt.policy_version='1'
  from public.bil_consent_receipts receipt
  where receipt.user_id=(select auth.uid()) and receipt.purpose='cloud_sync'
  order by receipt.recorded_at desc, receipt.granted asc, receipt.policy_version desc
  limit 1),false));

create policy bil_cloud_operations_current_consent_select_v1
on public.bil_cloud_operations as restrictive for select to authenticated
using (coalesce((select receipt.granted and receipt.policy_version='1'
  from public.bil_consent_receipts receipt
  where receipt.user_id=(select auth.uid()) and receipt.purpose='cloud_sync'
  order by receipt.recorded_at desc, receipt.granted asc, receipt.policy_version desc
  limit 1),false));

-- CREATE OR REPLACE retains exact existing function ownership and ACLs;
-- public/anon cannot execute either RPC, sync is authenticated-only, and the
-- existing service_role consent permission is not expanded to table CRUD.
