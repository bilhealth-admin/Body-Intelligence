select jsonb_build_object(
  'migration_applied', exists(
    select 1
    from supabase_migrations.schema_migrations
    where version = '20260820115847'
  ),
  'closed_grants_rls', (
    select relrowsecurity
    from pg_class
    where oid = 'public.bil_ai_closed_test_grants'::regclass
  ),
  'feedback_rls', (
    select relrowsecurity
    from pg_class
    where oid = 'public.bil_ai_coach_feedback'::regclass
  ),
  'closed_grants_auth_select', has_table_privilege(
    'authenticated', 'public.bil_ai_closed_test_grants', 'select'
  ),
  'closed_grants_anon_select', has_table_privilege(
    'anon', 'public.bil_ai_closed_test_grants', 'select'
  ),
  'feedback_auth_select', has_table_privilege(
    'authenticated', 'public.bil_ai_coach_feedback', 'select'
  ),
  'feedback_anon_select', has_table_privilege(
    'anon', 'public.bil_ai_coach_feedback', 'select'
  ),
  'set_access_service_execute', has_function_privilege(
    'service_role',
    'public.bil_set_ai_closed_test_access(uuid,text,boolean,timestamptz,text)',
    'execute'
  ),
  'set_access_auth_execute', has_function_privilege(
    'authenticated',
    'public.bil_set_ai_closed_test_access(uuid,text,boolean,timestamptz,text)',
    'execute'
  ),
  'feedback_auth_execute', has_function_privilege(
    'authenticated',
    'public.bil_record_ai_coach_feedback(text,boolean,text,text,text)',
    'execute'
  ),
  'feedback_anon_execute', has_function_privilege(
    'anon',
    'public.bil_record_ai_coach_feedback(text,boolean,text,text,text)',
    'execute'
  ),
  'consent_service_execute', has_function_privilege(
    'service_role', 'public.bil_has_remote_ai_consent(uuid)', 'execute'
  ),
  'consent_auth_execute', has_function_privilege(
    'authenticated', 'public.bil_has_remote_ai_consent(uuid)', 'execute'
  ),
  'policies', (
    select jsonb_agg(
      jsonb_build_object(
        'table', tablename,
        'policy', policyname,
        'roles', roles,
        'command', cmd
      )
      order by tablename, policyname
    )
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'bil_ai_closed_test_grants',
        'bil_ai_coach_feedback'
      )
  )
);
