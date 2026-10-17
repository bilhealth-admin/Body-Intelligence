-- Real production function bodies + synthetic schema, no production users or secrets.
CREATE ROLE service_role NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE SCHEMA bil_admin_private;
CREATE TABLE auth.users(id uuid PRIMARY KEY, email text UNIQUE NOT NULL, deleted_at timestamptz);
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $FN$
 SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb);
$FN$;
CREATE TABLE private.bil_ai_coach_admins(user_id uuid PRIMARY KEY REFERENCES auth.users(id),active boolean NOT NULL DEFAULT false);
CREATE TABLE bil_admin_private.subscription_grants(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 plan_id text NOT NULL CHECK(plan_id IN ('premium','premium_ai_coach')),
 created_at timestamptz NOT NULL DEFAULT now(),expires_at timestamptz,
 granted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 reason text NOT NULL DEFAULT '' CHECK(char_length(reason)<=160),
 revoked_at timestamptz,revoked_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 CHECK(expires_at IS NULL OR expires_at > created_at)
);
CREATE TABLE bil_admin_private.subscription_commands(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 idempotency_key text NOT NULL CHECK(idempotency_key~'^[A-Za-z0-9:_-]{16,128}$'),
 payload jsonb NOT NULL,result jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(actor_id,idempotency_key)
);
CREATE OR REPLACE FUNCTION bil_admin_private.require_administrator(p_actor_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' or p_actor_id is null then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  perform 1 from private.bil_ai_coach_admins a
    where a.user_id = p_actor_id and a.active for share;
  if not found then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
end;
$function$
;
CREATE OR REPLACE FUNCTION bil_admin_private.manage_subscription(p_actor_id uuid, p_operation text, p_idempotency_key text, p_email text DEFAULT NULL::text, p_plan_id text DEFAULT NULL::text, p_duration_days integer DEFAULT NULL::integer, p_reason text DEFAULT ''::text, p_grant_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_email text := lower(btrim(p_email));
  v_reason text := btrim(coalesce(p_reason, ''));
  v_owner uuid; v_matches integer; v_payload jsonb; v_result jsonb;
  v_prior bil_admin_private.subscription_commands%rowtype;
  v_grant bil_admin_private.subscription_grants%rowtype;
begin
  perform bil_admin_private.require_administrator(p_actor_id);
  if p_idempotency_key is null or p_idempotency_key !~ '^[A-Za-z0-9:_-]{16,128}$'
     or p_operation is null or p_operation not in ('grant', 'revoke')
     or char_length(v_reason) > 160 or v_reason ~ '[[:cntrl:]]' then
    raise exception 'invalid_subscription_request' using errcode = '22023';
  end if;
  if p_operation = 'grant' and (
    v_email is null or char_length(v_email) > 254 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    or p_plan_id is null or p_plan_id not in ('premium', 'premium_ai_coach')
    or (p_duration_days is not null and p_duration_days not in (30, 90, 365))
  ) then raise exception 'invalid_subscription_request' using errcode = '22023'; end if;
  if p_operation = 'revoke' and p_grant_id is null then
    raise exception 'invalid_subscription_request' using errcode = '22023';
  end if;
  v_payload := case when p_operation = 'grant' then jsonb_build_object(
    'operation', p_operation, 'email_hash', encode(sha256(convert_to(v_email, 'UTF8')), 'hex'), 'plan', p_plan_id,
    'duration_days', p_duration_days, 'reason_hash', encode(sha256(convert_to(v_reason, 'UTF8')), 'hex')
  ) else jsonb_build_object('operation', p_operation, 'grant_id', p_grant_id) end;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_actor_id::text || ':' || p_idempotency_key, 710));
  select * into v_prior from bil_admin_private.subscription_commands
    where actor_id = p_actor_id and idempotency_key = p_idempotency_key;
  if found then
    if v_prior.payload <> v_payload then raise exception 'idempotency_conflict' using errcode = '22023'; end if;
    return v_prior.result;
  end if;
  if p_operation = 'grant' then
    select count(*), (array_agg(id))[1] into v_matches, v_owner
      from auth.users where lower(email) = v_email and deleted_at is null;
    if v_matches <> 1 then
      v_result := jsonb_build_object('matched', false, 'changed', false, 'grant_id', null);
    else
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::text, 711));
      select * into v_grant from bil_admin_private.subscription_grants
        where owner_id = v_owner and revoked_at is null for update;
      if found and (v_grant.expires_at is null or v_grant.expires_at > now()) then
        -- No silent downgrade/upgrade, period extension, or usage reset on repeated grants.
        if v_grant.plan_id <> p_plan_id then
          raise exception 'existing_admin_subscription' using errcode = '22023';
        end if;
        v_result := jsonb_build_object('matched', true, 'changed', false, 'grant_id', v_grant.id);
      else
        update bil_admin_private.subscription_grants set revoked_at = now(), revoked_by = p_actor_id
          where owner_id = v_owner and revoked_at is null;
        insert into bil_admin_private.subscription_grants(owner_id, plan_id, expires_at, granted_by, reason)
          values(v_owner, p_plan_id, case when p_duration_days is null then null
            else now() + pg_catalog.make_interval(days => p_duration_days) end, p_actor_id, v_reason)
          returning * into v_grant;
        v_result := jsonb_build_object('matched', true, 'changed', true, 'grant_id', v_grant.id);
      end if;
    end if;
  else
    select owner_id into v_owner from bil_admin_private.subscription_grants where id = p_grant_id;
    if v_owner is null then
      v_result := jsonb_build_object('matched', false, 'changed', false, 'grant_id', null);
    else
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::text, 711));
      update bil_admin_private.subscription_grants set revoked_at = now(), revoked_by = p_actor_id
        where id = p_grant_id and revoked_at is null;
      v_result := jsonb_build_object('matched', true, 'changed', found, 'grant_id', p_grant_id);
    end if;
  end if;
  insert into bil_admin_private.subscription_commands(actor_id, idempotency_key, payload, result)
    values(p_actor_id, p_idempotency_key, v_payload, v_result);
  return v_result;
end $function$
;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',false);
INSERT INTO auth.users(id,email) VALUES
('11111111-1111-4111-8111-111111111111','admin-testing@example.invalid'),
('22222222-2222-4222-8222-222222222222','recipient-testing@example.invalid'),
('33333333-3333-4333-8333-333333333333','reviewer-testing@example.invalid');
INSERT INTO private.bil_ai_coach_admins(user_id,active)
VALUES('11111111-1111-4111-8111-111111111111',true),
('33333333-3333-4333-8333-333333333333',false);
