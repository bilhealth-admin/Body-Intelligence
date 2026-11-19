-- Add only the separately disclosed Gemini nutrition-estimation purpose.
-- Existing photo consent, owner/RLS/ACL, cloud locks and withdrawal semantics
-- remain unchanged. No consent rows are inserted, granted or rewritten.
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
do $source_guard$
begin
  if not exists(select 1 from pg_catalog.pg_proc p
    where p.oid=pg_catalog.to_regprocedure('public.bil_record_consent(text,text,boolean)')
      and pg_catalog.md5(pg_catalog.replace(p.prosrc,E'\r\n',E'\n'))='d6190a543d5c621d3f781d20c14e3c68'
      and p.prosecdef and p.proowner='postgres'::regrole
      and p.proconfig=array['search_path=public, pg_temp']) then
    raise exception 'vision_nutrition_consent_writer_drift' using errcode='55000';
  end if;
  if not exists(select 1 from pg_catalog.pg_constraint c
    where c.conrelid='public.bil_consent_receipts'::regclass
      and c.conname='bil_consent_receipts_purpose_check' and c.contype='c'
      and pg_catalog.regexp_replace(pg_catalog.pg_get_expr(c.conbin,c.conrelid), '[[:space:]()]', '', 'g')
        = $expected$purpose=ANYARRAY['health'::text,'camera'::text,'microphone'::text,'photos'::text,'notifications'::text,'devices'::text,'remote_ai'::text,'cloud_sync'::text,'meal_vision_ai'::text]$expected$) then
    raise exception 'vision_nutrition_consent_constraint_drift' using errcode='55000';
  end if;
end
$source_guard$;
lock table public.bil_consent_receipts in share row exclusive mode;
alter table public.bil_consent_receipts drop constraint bil_consent_receipts_purpose_check;
alter table public.bil_consent_receipts add constraint bil_consent_receipts_purpose_check
  check (purpose in ('health','camera','microphone','photos','notifications','devices',
    'remote_ai','cloud_sync','meal_vision_ai','meal_vision_nutrition_ai'));
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
      'remote_ai','cloud_sync','meal_vision_ai','meal_vision_nutrition_ai'
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
  elsif p_purpose in ('remote_ai', 'meal_vision_ai', 'meal_vision_nutrition_ai') then
    -- Every version for one AI purpose/owner follows the same lock order.
    -- A row lock alone cannot order different versions, and transaction-start
    -- now() can stamp an older-started, later-completed refusal before a grant.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('bil.consent.' || p_purpose || '.' || auth.uid()::text, 0)
    );
    v_recorded_at := pg_catalog.clock_timestamp();
  else
    -- Other OS/device-purpose validation/upsert/timestamp behavior unchanged.
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
commit;
