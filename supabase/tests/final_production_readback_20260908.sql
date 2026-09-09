-- Read-only final production reconciliation for the 2026-09-08 recovery.
-- This file intentionally contains no DDL or DML.
select jsonb_build_object(
  'policy_rows', (select count(*) from public.bil_content_policies),
  'active_effective_policy_rows', (
    select count(*)
    from public.bil_content_policies
    where active and effective_at <= now()
  ),
  'policy_v1', (
    select jsonb_build_object(
      'version', version,
      'locale_code', locale_code,
      'document_url', document_url,
      'active', active,
      'effective_at', effective_at
    )
    from public.bil_content_policies
    where version = 'community-policy-v1'
  ),
  'acceptance_rows', (
    select count(*) from public.bil_content_policy_acceptances
  ),
  'profile_rows', (select count(*) from public.bil_public_profiles),
  'handle_rows', (select count(*) from public.bil_social_handles_v2),
  'profiles_without_handle', (
    select count(*)
    from public.bil_public_profiles profile
    left join public.bil_social_handles_v2 handle
      on handle.user_id = profile.user_id
    where handle.user_id is null
  ),
  'save_rows', (select count(*) from public.bil_social_post_saves_v2),
  'public_code_rows', (
    select count(*) from public.bil_social_public_codes_v2
  ),
  'fixture_user_rows', (
    select count(*)
    from auth.users
    where id::text like '10000000-%'
       or id::text like '11000000-%'
       or id::text like '12000000-%'
       or id::text like '13000000-%'
  ),
  'social_v2_rls_tables', (
    select count(*)
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname like 'bil_social_%_v2'
      and relation.relkind in ('r', 'p')
      and relation.relrowsecurity
  ),
  'social_v2_public_functions', (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname like 'bil_social_%_v2'
  ),
  'authenticated_policy_select', pg_catalog.has_table_privilege(
    'authenticated', 'public.bil_content_policies', 'SELECT'
  ),
  'authenticated_acceptance_select', pg_catalog.has_table_privilege(
    'authenticated', 'public.bil_content_policy_acceptances', 'SELECT'
  ),
  'vision_v1_acl', jsonb_build_object(
    'public', exists (
      select 1
      from pg_catalog.pg_proc procedure
      cross join lateral pg_catalog.aclexplode(
        coalesce(
          procedure.proacl,
          pg_catalog.acldefault('f', procedure.proowner)
        )
      ) privilege
      where procedure.oid =
        'public.bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)'::regprocedure
        and privilege.grantee = 0
        and privilege.privilege_type = 'EXECUTE'
    ),
    'anon', pg_catalog.has_function_privilege(
      'anon',
      'public.bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)',
      'EXECUTE'
    ),
    'authenticated', pg_catalog.has_function_privilege(
      'authenticated',
      'public.bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)',
      'EXECUTE'
    ),
    'service_role', pg_catalog.has_function_privilege(
      'service_role',
      'public.bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)',
      'EXECUTE'
    )
  ),
  'vision_v2_acl', jsonb_build_object(
    'public', exists (
      select 1
      from pg_catalog.pg_proc procedure
      cross join lateral pg_catalog.aclexplode(
        coalesce(
          procedure.proacl,
          pg_catalog.acldefault('f', procedure.proowner)
        )
      ) privilege
      where procedure.oid =
        'public.bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)'::regprocedure
        and privilege.grantee = 0
        and privilege.privilege_type = 'EXECUTE'
    ),
    'anon', pg_catalog.has_function_privilege(
      'anon',
      'public.bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)',
      'EXECUTE'
    ),
    'authenticated', pg_catalog.has_function_privilege(
      'authenticated',
      'public.bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)',
      'EXECUTE'
    ),
    'service_role', pg_catalog.has_function_privilege(
      'service_role',
      'public.bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)',
      'EXECUTE'
    )
  ),
  'unknown_rate_action_rows', (
    select count(*)
    from public.bil_rate_limit_buckets bucket
    where bucket.action not in (
      'account_deletion', 'account_export',
      'ai_boost_purchase_verification', 'app_attest_issue',
      'admin_ai_coach_global_reset', 'admin_ai_coach_individual_reset',
      'admin_community_member_list', 'admin_community_member_reinstate',
      'admin_community_member_suspend', 'admin_community_moderator_add',
      'admin_community_moderator_list', 'admin_community_moderator_remove',
      'admin_notification_all', 'admin_notification_individual',
      'community_comment_report_v2', 'community_comment_v2',
      'community_handle_claim_v2', 'community_handle_search_v2',
      'community_like_v2', 'community_post_save_v2',
      'community_public_code_resolve_v2',
      'community_public_code_rotate_v2', 'follow', 'food_search_hour',
      'food_search_minute', 'friend_request', 'meal_image_analysis',
      'message', 'play_integrity_issue', 'post',
      'shared_diary_locked_read',
      'store_purchase_verification'
    )
  ),
  'dangerous_current_client_acl_entries', (
    select count(*)
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    cross join lateral pg_catalog.aclexplode(
      coalesce(
        relation.relacl,
        pg_catalog.acldefault('r', relation.relowner)
      )
    ) privilege
    where namespace.nspname = 'public'
      and relation.relkind in ('r', 'p', 'v', 'm', 'f')
      and (
        privilege.grantee = 0
        or pg_catalog.pg_get_userbyid(privilege.grantee)
          in ('anon', 'authenticated')
      )
      and privilege.privilege_type
        in ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN')
  ),
  'dangerous_default_client_acl_entries', (
    select count(*)
    from pg_catalog.pg_default_acl default_acl
    cross join lateral pg_catalog.aclexplode(
      coalesce(default_acl.defaclacl, '{}'::pg_catalog.aclitem[])
    ) privilege
    where default_acl.defaclrole = 'postgres'::pg_catalog.regrole
      and default_acl.defaclnamespace
        in (0, 'public'::pg_catalog.regnamespace)
      and default_acl.defaclobjtype = 'r'
      and (
        privilege.grantee = 0
        or pg_catalog.pg_get_userbyid(privilege.grantee)
          in ('anon', 'authenticated')
      )
      and privilege.privilege_type
        in ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN')
  ),
  'service_role_preserved_dangerous_defaults', (
    select count(*)
    from pg_catalog.pg_default_acl default_acl
    cross join lateral pg_catalog.aclexplode(
      coalesce(default_acl.defaclacl, '{}'::pg_catalog.aclitem[])
    ) privilege
    where default_acl.defaclrole = 'postgres'::pg_catalog.regrole
      and default_acl.defaclnamespace = 'public'::pg_catalog.regnamespace
      and default_acl.defaclobjtype = 'r'
      and pg_catalog.pg_get_userbyid(privilege.grantee) = 'service_role'
      and privilege.privilege_type
        in ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN')
  )
) as final_readback;
