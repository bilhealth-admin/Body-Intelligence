begin;

-- bil_cloud_records existed before the durable ledger contract. The additive
-- ledger migration deliberately retained the legacy NOT NULL columns
-- (device_id/client_updated_at), so every write must keep both column pairs in
-- lockstep until a future destructive cleanup can be scheduled safely.
create or replace function public.bil_sync_records(
  p_device_id text,
  p_cursor bigint default 0,
  p_operations jsonb default '[]'::jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_operation jsonb;
  v_record jsonb;
  v_acknowledged jsonb := '[]'::jsonb;
  v_records jsonb;
  v_cursor bigint;
  v_operation_id text;
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

  if exists (
    select 1
    from public.bil_cloud_devices
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
      owner_id, entity_kind, record_id,
      device_id, revision_device_id,
      revision_sequence,
      client_updated_at, updated_at,
      deleted_at, schema_version, payload
    ) values (
      v_owner,
      v_record ->> 'entity_kind',
      v_record ->> 'record_id',
      v_record ->> 'revision_device_id',
      v_record ->> 'revision_device_id',
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
  from public.bil_cloud_records
  where owner_id = v_owner and change_sequence > greatest(p_cursor, 0);

  return jsonb_build_object(
    'acknowledged', v_acknowledged,
    'records', v_records,
    'cursor', v_cursor
  );
end;
$$;

revoke all on function public.bil_sync_records(text, bigint, jsonb)
  from public, anon;
grant execute on function public.bil_sync_records(text, bigint, jsonb)
  to authenticated;

commit;
