-- Additive sender-owned erasure. Existing Delete for me RPC is unchanged.
-- Erasure is not publication/contact: it remains possible after unfriend,
-- block, suspension or a new unaccepted Community policy. No new contact is
-- sent, and no recipient identity is disclosed for foreign/missing UUIDs.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '10s';

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint c
    join pg_catalog.pg_attribute a on a.attrelid=c.conrelid
      and a.attnum=any(c.conkey)
    where c.conrelid='private.bil_community_message_deliveries_v2'::regclass
      and c.confrelid='public.bil_messages'::regclass and c.contype='f'
      and c.confdeltype='n' and a.attname='message_id'
  ) or exists (
    select 1 from pg_catalog.pg_attribute
    where attrelid='private.bil_community_message_deliveries_v2'::regclass
      and attname='body' and attnum>0 and not attisdropped
  ) then
    raise exception 'community_message_erasure_receipt_contract_changed';
  end if;
end;
$$;

-- FK actions for message erasure/account cleanup must not scan every retained
-- idempotency receipt as conversations grow. The owner FK uses the PK prefix.
create index bil_community_message_deliveries_v2_message_id_idx
  on private.bil_community_message_deliveries_v2 (message_id);
create index bil_community_message_deliveries_v2_recipient_id_idx
  on private.bil_community_message_deliveries_v2 (recipient_id);

create function public.bil_delete_message_for_everyone_v1(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_recipient uuid;
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_message_id is null then
    raise exception 'invalid_message_delete_request' using errcode='22023';
  end if;
  -- Sender-scoped lookup has no row lock before the established pair lock.
  -- Missing, foreign and repeated requests share the same non-disclosing no-op.
  select recipient_id into v_recipient
    from public.bil_messages where id=p_message_id and sender_id=v_actor;
  if not found then return; end if;
  -- Same pair lock as legacy INSERT and idempotent send, before row locking.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'community_block_pair:' || least(v_actor::text,v_recipient::text)
      || ':' || greatest(v_actor::text,v_recipient::text),0));
  -- Recheck after any lock wait, including a concurrent For-me/account cleanup.
  perform 1 from public.bil_messages
    where id=p_message_id and sender_id=v_actor and recipient_id=v_recipient
    for update;
  if not found then return; end if;
  -- Canonical body is physically removed; receipt FK ON DELETE SET NULL keeps
  -- its owner/request/recipient/body-hash tombstone, so replay cannot recreate it.
  -- Current push producer contains only generic text; audit stores IDs/actions.
  delete from public.bil_messages
    where id=p_message_id and sender_id=v_actor and recipient_id=v_recipient;
end;
$$;

revoke all on function public.bil_delete_message_for_everyone_v1(uuid)
  from public,anon;
grant execute on function public.bil_delete_message_for_everyone_v1(uuid)
  to authenticated;
commit;
