-- Run only after 20260908141133_harden_public_default_table_privileges.
-- The whole probe is transactional: it creates no durable object or data.
begin;

do $default_acl_hardening_probe$
declare
  v_probe regclass;
  v_privilege text;
  v_role name;
begin
  if current_user <> 'postgres' then
    raise exception 'default_acl_hardening_test_requires_postgres'
      using errcode = '55000',
            detail = 'The probe must create the relation as the owner whose defaults were hardened.';
  end if;

  if pg_catalog.to_regclass(
       'public.bil_default_acl_hardening_probe_20260908141133'
     ) is not null then
    raise exception 'default_acl_hardening_probe_name_conflict'
      using errcode = '55000';
  end if;

  create table public.bil_default_acl_hardening_probe_20260908141133 (
    id bigint primary key
  );

  v_probe := 'public.bil_default_acl_hardening_probe_20260908141133'::pg_catalog.regclass;

  foreach v_role in array array['anon'::name, 'authenticated'::name]
  loop
    foreach v_privilege in array array[
      'TRUNCATE'::text,
      'TRIGGER'::text,
      'REFERENCES'::text,
      'MAINTAIN'::text
    ]
    loop
      if pg_catalog.has_table_privilege(v_role, v_probe, v_privilege) then
        raise exception 'default_acl_hardening_probe_failed'
          using errcode = '55000',
                detail = format(
                  'Unexpected %s default privilege for %s on synthetic relation.',
                  v_privilege,
                  v_role
                );
      end if;
    end loop;
  end loop;
end
$default_acl_hardening_probe$;

rollback;
