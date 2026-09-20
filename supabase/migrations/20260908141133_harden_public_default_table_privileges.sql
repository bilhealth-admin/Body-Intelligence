-- Prevent future postgres-owned public relations from automatically receiving
-- dangerous structural privileges through the legacy per-schema default ACL.
-- This changes defaults only; existing relation ACLs, RLS, policies, functions,
-- schemas, roles, entitlements, and service_role defaults are deliberately
-- untouched.
begin;

do $default_acl_hardening_preflight$
declare
  v_public_dangerous_count integer;
  v_global_dangerous_count integer;
begin
  if pg_catalog.to_regrole('postgres') is null
     or pg_catalog.to_regnamespace('public') is null
     or pg_catalog.to_regrole('anon') is null
     or pg_catalog.to_regrole('authenticated') is null
     or pg_catalog.to_regrole('service_role') is null then
    raise exception 'default_acl_hardening_precondition_failed'
      using errcode = '55000',
            detail = 'Required owner, schema, or API roles are missing.';
  end if;

  -- Per-schema ACLs add to global ACLs. A global dangerous grant would survive
  -- the narrow public-schema revoke below and therefore must be absent.
  select count(*) into v_global_dangerous_count
  from pg_catalog.pg_default_acl default_acl
  cross join lateral pg_catalog.aclexplode(
    coalesce(default_acl.defaclacl, '{}'::pg_catalog.aclitem[])
  ) privilege
  where default_acl.defaclrole = 'postgres'::pg_catalog.regrole
    and default_acl.defaclnamespace = 0
    and default_acl.defaclobjtype = 'r'
    and (
      privilege.grantee = 0
      or pg_catalog.pg_get_userbyid(privilege.grantee)
        in ('anon', 'authenticated')
    )
    and privilege.privilege_type
      in ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN');

  if v_global_dangerous_count <> 0 then
    raise exception 'default_acl_hardening_precondition_failed'
      using errcode = '55000',
            detail = 'A global dangerous table default exists; this migration is intentionally schema-narrow.';
  end if;

  select count(*) into v_public_dangerous_count
  from pg_catalog.pg_default_acl default_acl
  cross join lateral pg_catalog.aclexplode(
    coalesce(default_acl.defaclacl, '{}'::pg_catalog.aclitem[])
  ) privilege
  where default_acl.defaclrole = 'postgres'::pg_catalog.regrole
    and default_acl.defaclnamespace = 'public'::pg_catalog.regnamespace
    and default_acl.defaclobjtype = 'r'
    and (
      privilege.grantee = 0
      or pg_catalog.pg_get_userbyid(privilege.grantee)
        in ('anon', 'authenticated')
    )
    and privilege.privilege_type
      in ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN');

  if v_public_dangerous_count <> 8 then
    raise exception 'default_acl_hardening_precondition_failed'
      using errcode = '55000',
            detail = 'Expected exactly eight public postgres defaults for anon/authenticated before the narrow revoke.';
  end if;
end
$default_acl_hardening_preflight$;

alter default privileges for role postgres in schema public
  revoke truncate, trigger, references, maintain on tables
  from anon, authenticated;

do $default_acl_hardening_postconditions$
declare
  v_client_dangerous_count integer;
  v_service_role_dangerous_count integer;
begin
  select count(*) into v_client_dangerous_count
  from pg_catalog.pg_default_acl default_acl
  cross join lateral pg_catalog.aclexplode(
    coalesce(default_acl.defaclacl, '{}'::pg_catalog.aclitem[])
  ) privilege
  where default_acl.defaclrole = 'postgres'::pg_catalog.regrole
    and default_acl.defaclnamespace in (
      0,
      'public'::pg_catalog.regnamespace
    )
    and default_acl.defaclobjtype = 'r'
    and (
      privilege.grantee = 0
      or pg_catalog.pg_get_userbyid(privilege.grantee)
        in ('anon', 'authenticated')
    )
    and privilege.privilege_type
      in ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN');

  if v_client_dangerous_count <> 0 then
    raise exception 'default_acl_hardening_postcondition_failed'
      using errcode = '55000',
            detail = 'Dangerous future relation defaults remain reachable by anon, authenticated, or PUBLIC.';
  end if;

  -- This migration must not rewrite the existing trusted service_role default.
  select count(*) into v_service_role_dangerous_count
  from pg_catalog.pg_default_acl default_acl
  cross join lateral pg_catalog.aclexplode(
    coalesce(default_acl.defaclacl, '{}'::pg_catalog.aclitem[])
  ) privilege
  where default_acl.defaclrole = 'postgres'::pg_catalog.regrole
    and default_acl.defaclnamespace = 'public'::pg_catalog.regnamespace
    and default_acl.defaclobjtype = 'r'
    and pg_catalog.pg_get_userbyid(privilege.grantee) = 'service_role'
    and privilege.privilege_type
      in ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN');

  if v_service_role_dangerous_count <> 4 then
    raise exception 'default_acl_hardening_postcondition_failed'
      using errcode = '55000',
            detail = 'The existing service_role relation defaults changed unexpectedly.';
  end if;
end
$default_acl_hardening_postconditions$;

commit;
