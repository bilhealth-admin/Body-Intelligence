begin;
do $bil$
declare
  v_owner_a uuid;
  v_owner_b uuid;
  v_cursor_a bigint;
  v_cursor_b bigint;
  v_upload jsonb;
  v_download jsonb;
  v_edit jsonb;
  v_redownload jsonb;
  v_stale jsonb;
  v_duplicate jsonb;
  v_isolation jsonb;
  v_record_id text := 'qa-prefinal-cloud-' || txid_current()::text;
  v_op1 text := 'qa-prefinal-op1-' || txid_current()::text;
  v_op2 text := 'qa-prefinal-op2-' || txid_current()::text;
  v_op_stale text := 'qa-prefinal-stale-' || txid_current()::text;
  v_device_a text := 'qa-prefinal-device-a';
  v_device_b text := 'qa-prefinal-device-b';
  v_device_iso text := 'qa-prefinal-device-isolation';
  v_t1 timestamptz := clock_timestamp();
  v_t2 timestamptz;
  v_payload1 jsonb := jsonb_build_object(
    '_bil_cipher_v', 1,
    'alg', 'A256GCM',
    'nonce', 'AAAAAAAAAAAAAAAA',
    'ciphertext', 'tYUsWCoBCBcldLGhz5bgXQP1tPc9fVBNDIEz142ylQ==',
    'qa_marker', 'device-a-upload'
  );
  v_payload2 jsonb;
  v_current jsonb;
  v_count int;
begin
  select id into v_owner_a from auth.users order by created_at, id limit 1;
  select id into v_owner_b from auth.users where id <> v_owner_a order by created_at, id limit 1;
  if v_owner_a is null or v_owner_b is null then raise exception 'two_auth_owners_required'; end if;

  select coalesce(max(change_sequence), 0) into v_cursor_a
    from public.bil_cloud_records where owner_id = v_owner_a;
  select coalesce(max(change_sequence), 0) into v_cursor_b
    from public.bil_cloud_records where owner_id = v_owner_b;

  perform set_config('request.jwt.claim.sub', v_owner_a::text, true);
  select public.bil_sync_records(
    v_device_a,
    v_cursor_a,
    jsonb_build_array(jsonb_build_object(
      'operation_id', v_op1,
      'mutation', 'upsert',
      'record', jsonb_build_object(
        'entity_kind', 'settings',
        'record_id', v_record_id,
        'revision_device_id', v_device_a,
        'revision_sequence', 1,
        'updated_at', v_t1,
        'deleted_at', null,
        'schema_version', 1,
        'payload', v_payload1
      )
    ))
  ) into v_upload;
  if not (v_upload->'acknowledged' @> jsonb_build_array(v_op1)) then raise exception 'upload_not_acknowledged'; end if;

  select public.bil_sync_records(v_device_b, v_cursor_a, '[]'::jsonb) into v_download;
  if not exists (
    select 1 from jsonb_array_elements(v_download->'records') r
    where r->>'record_id' = v_record_id and r->'payload' = v_payload1
  ) then raise exception 'device_b_download_payload_compare_failed'; end if;

  perform pg_sleep(0.02);
  v_t2 := clock_timestamp();
  v_payload2 := jsonb_set(v_payload1, '{qa_marker}', '"device-b-edit"'::jsonb, true);
  select public.bil_sync_records(
    v_device_b,
    (v_upload->>'cursor')::bigint,
    jsonb_build_array(jsonb_build_object(
      'operation_id', v_op2,
      'mutation', 'upsert',
      'record', jsonb_build_object(
        'entity_kind', 'settings',
        'record_id', v_record_id,
        'revision_device_id', v_device_b,
        'revision_sequence', 2,
        'updated_at', v_t2,
        'deleted_at', null,
        'schema_version', 1,
        'payload', v_payload2
      )
    ))
  ) into v_edit;
  if not (v_edit->'acknowledged' @> jsonb_build_array(v_op2)) then raise exception 'edit_not_acknowledged'; end if;

  select public.bil_sync_records(v_device_a, (v_upload->>'cursor')::bigint, '[]'::jsonb) into v_redownload;
  if not exists (
    select 1 from jsonb_array_elements(v_redownload->'records') r
    where r->>'record_id' = v_record_id
      and r->'payload'->>'qa_marker' = 'device-b-edit'
      and r->'payload'->>'ciphertext' = v_payload1->>'ciphertext'
  ) then raise exception 'device_a_redownload_edit_failed'; end if;

  select public.bil_sync_records(
    v_device_a,
    (v_redownload->>'cursor')::bigint,
    jsonb_build_array(jsonb_build_object(
      'operation_id', v_op_stale,
      'mutation', 'upsert',
      'record', jsonb_build_object(
        'entity_kind', 'settings',
        'record_id', v_record_id,
        'revision_device_id', v_device_a,
        'revision_sequence', 99,
        'updated_at', v_t1,
        'deleted_at', null,
        'schema_version', 1,
        'payload', jsonb_set(v_payload1, '{qa_marker}', '"stale-must-not-win"'::jsonb, true)
      )
    ))
  ) into v_stale;
  if not (v_stale->'acknowledged' @> jsonb_build_array(v_op_stale)) then raise exception 'stale_not_acknowledged'; end if;

  select payload into v_current
    from public.bil_cloud_records
    where owner_id = v_owner_a and entity_kind = 'settings' and record_id = v_record_id;
  if v_current->>'qa_marker' <> 'device-b-edit' then raise exception 'stale_payload_overwrote_newer_data'; end if;

  select public.bil_sync_records(
    v_device_b,
    (v_edit->>'cursor')::bigint,
    jsonb_build_array(jsonb_build_object(
      'operation_id', v_op2,
      'mutation', 'upsert',
      'record', jsonb_build_object(
        'entity_kind', 'settings',
        'record_id', v_record_id,
        'revision_device_id', v_device_b,
        'revision_sequence', 2,
        'updated_at', v_t2,
        'deleted_at', null,
        'schema_version', 1,
        'payload', v_payload2
      )
    ))
  ) into v_duplicate;
  if not (v_duplicate->'acknowledged' @> jsonb_build_array(v_op2)) then raise exception 'duplicate_not_acknowledged'; end if;

  select count(*) into v_count from public.bil_cloud_operations
    where owner_id = v_owner_a and operation_id = v_op2;
  if v_count <> 1 then raise exception 'idempotency_row_count_%', v_count; end if;

  perform set_config('request.jwt.claim.sub', v_owner_b::text, true);
  select public.bil_sync_records(v_device_iso, v_cursor_b, '[]'::jsonb) into v_isolation;
  if exists (
    select 1 from jsonb_array_elements(v_isolation->'records') r
    where r->>'record_id' = v_record_id
  ) then raise exception 'cross_account_isolation_failed'; end if;
end
$bil$;
select
  true as live_cloud_roundtrip,
  true as device_download_payload_bytes,
  true as edit_redownload,
  true as stale_conflict,
  true as duplicate_idempotency,
  true as account_isolation,
  'ROLLBACK_ENFORCED'::text as persistence;
rollback;
