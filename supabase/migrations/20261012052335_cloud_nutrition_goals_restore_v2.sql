-- Additive encrypted nutrition/goals restoration. V1 tables/RPC and their
-- response shape are deliberately untouched: Android32/iOS35 cannot see V2.
-- Deployment is NOT authorized by this file. Tested only on isolated fixtures.
create schema if not exists private;
create sequence public.bil_cloud_restore_change_sequence_v2;

create table public.bil_cloud_restore_consents_v2 (
  owner_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope in ('nutrition','goals')),
  policy_version text not null check (length(policy_version) between 1 and 64),
  granted boolean not null,
  recorded_at timestamptz not null,
  primary key(owner_id,scope)
);
create table public.bil_cloud_restore_records_v2 (
  owner_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope in ('nutrition','goals')),
  record_type text not null,
  record_id text not null check (length(record_id) between 1 and 200),
  server_revision bigint not null check (server_revision > 0),
  change_sequence bigint not null default nextval('public.bil_cloud_restore_change_sequence_v2'),
  deleted boolean not null default false,
  payload_version integer not null check (payload_version = 2),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  updated_at timestamptz not null,
  device_id text not null check (length(device_id) between 8 and 200),
  primary key(owner_id,scope,record_type,record_id),
  check ((scope='nutrition' and record_type in ('food','recipe','meal'))
    or (scope='goals' and record_type='goals' and record_id='nutrition-goals'))
);
create index bil_cloud_restore_pull_v2 on public.bil_cloud_restore_records_v2
  (owner_id,scope,change_sequence);
create table public.bil_cloud_restore_operations_v2 (
  owner_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope in ('nutrition','goals')),
  operation_id text not null check (length(operation_id) between 3 and 512),
  request_sha256 text not null check (length(request_sha256)=64),
  receipt jsonb not null,
  recorded_at timestamptz not null,
  primary key(owner_id,scope,operation_id)
);

alter table public.bil_cloud_restore_consents_v2 enable row level security;
alter table public.bil_cloud_restore_records_v2 enable row level security;
alter table public.bil_cloud_restore_operations_v2 enable row level security;
revoke all on public.bil_cloud_restore_consents_v2,
  public.bil_cloud_restore_records_v2,public.bil_cloud_restore_operations_v2
  from public,anon,authenticated;
revoke all on sequence public.bil_cloud_restore_change_sequence_v2
  from public,anon,authenticated;
-- Defense in depth; no direct table grant is given to a phone. All record
-- access also verifies device trust in the RPC. These policies cannot turn an
-- authenticated role into a cross-owner reader if a grant is added by mistake.
create policy bil_cloud_restore_consent_owner_v2
  on public.bil_cloud_restore_consents_v2 for select to authenticated
  using(owner_id=(select auth.uid()));
create policy bil_cloud_restore_record_owner_v2
  on public.bil_cloud_restore_records_v2 for select to authenticated
  using(owner_id=(select auth.uid()));
create policy bil_cloud_restore_operation_owner_v2
  on public.bil_cloud_restore_operations_v2 for select to authenticated
  using(owner_id=(select auth.uid()));

create function private.bil_cloud_restore_base_consent_v2(p_owner uuid)
returns boolean language sql stable security definer
set search_path=pg_catalog,public as $$
  select coalesce((select granted and policy_version='1'
    from public.bil_consent_receipts
    where user_id=p_owner and purpose='cloud_sync'
    order by recorded_at desc,granted asc,policy_version desc limit 1),false)
$$;
revoke all on function private.bil_cloud_restore_base_consent_v2(uuid)
  from public,anon,authenticated;

create function public.bil_cloud_restore_capabilities_v2()
returns jsonb language plpgsql security invoker
set search_path=pg_catalog,public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  return jsonb_build_object('protocol_version',2,'scopes',jsonb_build_array('nutrition','goals'),
    'consent_policy_version','1','max_batch_size',100,'max_page_size',100);
end $$;

create function public.bil_cloud_restore_consent_v2()
returns jsonb language plpgsql security definer
set search_path=pg_catalog,public as $$
declare v_owner uuid:=auth.uid(); v_result jsonb; begin
  if v_owner is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select jsonb_object_agg(s.scope,jsonb_build_object('scope',s.scope,
    'granted',coalesce(c.granted and c.policy_version='1',false),
    'policy_version',coalesce(c.policy_version,'1'),'recorded_at',c.recorded_at))
    into v_result from (values('nutrition'),('goals')) s(scope)
    left join public.bil_cloud_restore_consents_v2 c on c.owner_id=v_owner and c.scope=s.scope;
  return v_result;
end $$;

create function public.bil_record_cloud_restore_consent_v2(
  p_scope text,p_granted boolean,p_policy_version text default '1')
returns jsonb language plpgsql security definer
set search_path=pg_catalog,public as $$
declare v_owner uuid:=auth.uid(); v_recorded timestamptz; begin
  if v_owner is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_scope is null or p_scope not in ('nutrition','goals') or p_granted is null
    or p_policy_version is null or length(trim(p_policy_version)) not between 1 and 64
    or (p_granted and p_policy_version<>'1') then
    raise exception 'invalid_restore_consent' using errcode='22023';
  end if;
  -- The same lock as the existing base consent writer / V1 sync serializes
  -- base withdrawal, scope withdrawal and all V2 work, including absent rows.
  perform pg_advisory_xact_lock(hashtextextended('bil.sync.'||v_owner::text,0));
  if p_granted and not private.bil_cloud_restore_base_consent_v2(v_owner) then
    raise exception 'cloud_sync_consent_required' using errcode='42501';
  end if;
  v_recorded:=clock_timestamp();
  insert into public.bil_cloud_restore_consents_v2 values
    (v_owner,p_scope,trim(p_policy_version),p_granted,v_recorded)
  on conflict(owner_id,scope) do update set policy_version=excluded.policy_version,
    granted=excluded.granted,recorded_at=excluded.recorded_at;
  return jsonb_build_object('scope',p_scope,'granted',p_granted,
    'policy_version',trim(p_policy_version),'recorded_at',v_recorded);
end $$;

create function public.bil_revoke_cloud_restore_device_v2(p_device_id text)
returns void language plpgsql security definer
set search_path=pg_catalog,public as $$
declare v_owner uuid:=auth.uid(); begin
  if v_owner is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_device_id is null or length(trim(p_device_id)) not between 8 and 200 then
    raise exception 'invalid_device_id' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bil.sync.'||v_owner::text,0));
  insert into public.bil_cloud_devices(owner_id,device_id,revoked_at)
    values(v_owner,p_device_id,clock_timestamp())
  on conflict(owner_id,device_id) do update set revoked_at=excluded.revoked_at;
end $$;

create function public.bil_sync_records_v2(p_device_id text,p_scope text,
  p_cursor bigint default 0,p_operations jsonb default '[]'::jsonb,p_limit integer default 100)
returns jsonb language plpgsql security definer
set search_path=pg_catalog,public as $$
declare
  v_owner uuid:=auth.uid(); v_op jsonb; v_old public.bil_cloud_restore_records_v2;
  v_prior public.bil_cloud_restore_operations_v2; v_op_id text; v_type text; v_id text;
  v_expected bigint; v_revision bigint; v_hash text; v_receipt jsonb; v_current jsonb;
  v_receipts jsonb:='[]'; v_records jsonb; v_cursor bigint; v_deleted boolean; v_more boolean;
begin
  if v_owner is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_device_id is null or length(trim(p_device_id)) not between 8 and 200 then
    raise exception 'invalid_device_id' using errcode='22023'; end if;
  if p_scope is null or p_scope not in ('nutrition','goals') or p_cursor is null or p_cursor<0
    or p_limit is null or p_limit not between 1 and 100 or p_operations is null
    or jsonb_typeof(p_operations)<>'array' or jsonb_array_length(p_operations)>100 then
    raise exception 'invalid_restore_batch' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bil.sync.'||v_owner::text,0));
  if not private.bil_cloud_restore_base_consent_v2(v_owner) then
    raise exception 'cloud_sync_consent_required' using errcode='42501'; end if;
  if not exists(select 1 from public.bil_cloud_restore_consents_v2
    where owner_id=v_owner and scope=p_scope and granted and policy_version='1') then
    raise exception 'cloud_restore_scope_consent_required' using errcode='42501'; end if;
  if exists(select 1 from public.bil_cloud_devices where owner_id=v_owner
    and device_id=p_device_id and revoked_at is not null) then
    raise exception 'device_revoked' using errcode='42501'; end if;
  insert into public.bil_cloud_devices(owner_id,device_id,last_seen_at)
    values(v_owner,p_device_id,clock_timestamp())
  on conflict(owner_id,device_id) do update set last_seen_at=excluded.last_seen_at;
  -- The row lock also orders direct authorized revocation with an admitted
  -- transaction. A committed withdrawal blocks the following operation.
  perform 1 from public.bil_cloud_devices where owner_id=v_owner and device_id=p_device_id for share;
  -- Recheck after a possible wait on a direct registry revocation. The earlier
  -- snapshot must not authorize work after that revocation has committed.
  if exists(select 1 from public.bil_cloud_devices where owner_id=v_owner
    and device_id=p_device_id and revoked_at is not null) then
    raise exception 'device_revoked' using errcode='42501'; end if;

  for v_op in select value from jsonb_array_elements(p_operations) loop
    if jsonb_typeof(v_op)<>'object' or
      v_op - array['operation_id','record_type','record_id','expected_revision','mutation','payload_version','payload'] <> '{}'::jsonb then
      raise exception 'invalid_restore_operation' using errcode='22023'; end if;
    v_op_id:=v_op->>'operation_id'; v_type:=v_op->>'record_type'; v_id:=v_op->>'record_id';
    if v_op_id is null or length(v_op_id) not between 3 and 512
      or v_id is null or length(v_id) not between 1 and 200
      or v_type is null or not ((p_scope='nutrition' and v_type in ('food','recipe','meal'))
        or (p_scope='goals' and v_type='goals' and v_id='nutrition-goals'))
      or (v_op->>'expected_revision') is null or (v_op->>'expected_revision') !~ '^[0-9]{1,18}$'
      or (v_op->>'mutation') is null or v_op->>'mutation' not in ('upsert','delete')
      or (v_op->'payload_version') is distinct from '2'::jsonb
      or jsonb_typeof(v_op->'payload') is distinct from 'object'
      or (v_op#>'{payload,_bil_cipher_v}') is distinct from '1'::jsonb
      or (v_op#>>'{payload,alg}') is distinct from 'A256GCM'
      or jsonb_typeof(v_op#>'{payload,nonce}') is distinct from 'string'
      or jsonb_typeof(v_op#>'{payload,ciphertext}') is distinct from 'string'
      or length(v_op#>>'{payload,nonce}') not between 16 and 24
      or length(v_op#>>'{payload,ciphertext}')<24
      or pg_column_size(v_op->'payload')>1048576 then
      raise exception 'invalid_restore_record' using errcode='22023'; end if;
    v_expected:=(v_op->>'expected_revision')::bigint;
    v_hash:=encode(sha256(convert_to(jsonb_build_object('device',p_device_id,'operation',v_op)::text,'UTF8')),'hex');
    select * into v_prior from public.bil_cloud_restore_operations_v2
      where owner_id=v_owner and scope=p_scope and operation_id=v_op_id;
    if found then
      if v_prior.request_sha256<>v_hash then raise exception 'restore_idempotency_conflict' using errcode='22023'; end if;
      v_receipts:=v_receipts||jsonb_build_array(v_prior.receipt||jsonb_build_object('replayed',true));
      continue;
    end if;
    select * into v_old from public.bil_cloud_restore_records_v2
      where owner_id=v_owner and scope=p_scope and record_type=v_type and record_id=v_id;
    v_revision:=coalesce(v_old.server_revision,0);
    v_current:=case when v_revision=0 then null else to_jsonb(v_old)-'device_id' end;
    if v_expected<>v_revision or (coalesce(v_old.deleted,false) and v_op->>'mutation'='upsert') then
      v_receipt:=jsonb_build_object('operation_id',v_op_id,'outcome','conflict',
        'server_revision',v_revision,'replayed',false,'current_record',v_current);
    else
      v_revision:=v_revision+1; v_deleted:=v_op->>'mutation'='delete';
      insert into public.bil_cloud_restore_records_v2(owner_id,scope,record_type,record_id,
        server_revision,deleted,payload_version,payload,updated_at,device_id)
      values(v_owner,p_scope,v_type,v_id,v_revision,v_deleted,2,v_op->'payload',clock_timestamp(),p_device_id)
      on conflict(owner_id,scope,record_type,record_id) do update set
        server_revision=excluded.server_revision,deleted=excluded.deleted,payload_version=excluded.payload_version,
        payload=excluded.payload,updated_at=excluded.updated_at,device_id=excluded.device_id,
        change_sequence=nextval('public.bil_cloud_restore_change_sequence_v2');
      v_receipt:=jsonb_build_object('operation_id',v_op_id,'outcome','accepted',
        'server_revision',v_revision,'replayed',false);
    end if;
    insert into public.bil_cloud_restore_operations_v2 values
      (v_owner,p_scope,v_op_id,v_hash,v_receipt,clock_timestamp());
    v_receipts:=v_receipts||jsonb_build_array(v_receipt);
  end loop;
  with page as (select * from public.bil_cloud_restore_records_v2
    where owner_id=v_owner and scope=p_scope and change_sequence>p_cursor
    order by change_sequence limit p_limit)
  select coalesce(jsonb_agg(to_jsonb(page)-'device_id' order by change_sequence),'[]'::jsonb),
    coalesce(max(change_sequence),p_cursor) into v_records,v_cursor from page;
  select exists(select 1 from public.bil_cloud_restore_records_v2
    where owner_id=v_owner and scope=p_scope and change_sequence>v_cursor) into v_more;
  return jsonb_build_object('protocol_version',2,'scope',p_scope,'receipts',v_receipts,
    'records',v_records,'cursor',v_cursor,'has_more',v_more);
end $$;

revoke all on function public.bil_cloud_restore_capabilities_v2(),
  public.bil_cloud_restore_consent_v2(),
  public.bil_record_cloud_restore_consent_v2(text,boolean,text),
  public.bil_revoke_cloud_restore_device_v2(text),
  public.bil_sync_records_v2(text,text,bigint,jsonb,integer) from public,anon;
grant execute on function public.bil_cloud_restore_capabilities_v2(),
  public.bil_cloud_restore_consent_v2(),
  public.bil_record_cloud_restore_consent_v2(text,boolean,text),
  public.bil_revoke_cloud_restore_device_v2(text),
  public.bil_sync_records_v2(text,text,bigint,jsonb,integer) to authenticated;
