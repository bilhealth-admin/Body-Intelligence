
SELECT set_config('app.test_role','service_role',false);
DO $tests$
DECLARE
  actor uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  arr jsonb;
  denied boolean:=false;
BEGIN
  IF has_function_privilege('authenticated','public.bil_admin_web_reporter_contacts_v1(uuid,text,uuid[])','EXECUTE')
     OR has_function_privilege('anon','public.bil_admin_web_reporter_contacts_v1(uuid,text,uuid[])','EXECUTE')
     OR NOT has_function_privilege('service_role','public.bil_admin_web_reporter_contacts_v1(uuid,text,uuid[])','EXECUTE')
  THEN RAISE EXCEPTION 'browser grants unexpectedly allowed'; END IF;

  SELECT public.bil_admin_web_reporter_contacts_v1(actor,'safety',ARRAY[
    'aaa00000-0000-4000-8000-000000000001'::uuid,
    'aaa00000-0000-4000-8000-000000000002'::uuid,
    'aaa00000-0000-4000-8000-000000000003'::uuid
  ]) INTO arr;
  IF jsonb_array_length(arr) <> 1
     OR arr->0->>'reporter_email'<>'safety.reporter@example.invalid'
     OR arr->0->>'reporter_user_id'<>'11111111-1111-4111-8111-111111111111'
  THEN RAISE EXCEPTION 'safety filter/contact failed: %',arr; END IF;

  SELECT public.bil_admin_web_reporter_contacts_v1(actor,'community',ARRAY[
    'bbb00000-0000-4000-8000-000000000001'::uuid,
    'bbb00000-0000-4000-8000-000000000002'::uuid
  ]) INTO arr;
  IF jsonb_array_length(arr)<>1 OR arr->0->>'reporter_email'<>'community.reporter@example.invalid'
  THEN RAISE EXCEPTION 'community status filter failed: %',arr; END IF;

  SELECT public.bil_admin_web_reporter_contacts_v1(actor,'posts',ARRAY[
    'ccc00000-0000-4000-8000-000000000001'::uuid,
    'ccc00000-0000-4000-8000-000000000002'::uuid
  ]) INTO arr;
  IF jsonb_array_length(arr)<>1 OR arr->0->>'reporter_email'<>'post.author@example.invalid'
  THEN RAISE EXCEPTION 'post filter failed: %',arr; END IF;

  SELECT public.bil_admin_web_reporter_contacts_v1(actor,'safety',ARRAY[]::uuid[]) INTO arr;
  IF arr <> '[]'::jsonb THEN RAISE EXCEPTION 'empty ID list leaked rows'; END IF;

  BEGIN
    PERFORM public.bil_admin_web_reporter_contacts_v1(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,
      'safety',ARRAY['aaa00000-0000-4000-8000-000000000001'::uuid]);
  EXCEPTION WHEN insufficient_privilege THEN denied:=true; END;
  IF NOT denied THEN RAISE EXCEPTION 'inactive admin gained reporter email'; END IF;
  denied:=false;

  PERFORM set_config('app.test_role','authenticated',true);
  BEGIN
    PERFORM public.bil_admin_web_reporter_contacts_v1(
      actor,'safety',ARRAY['aaa00000-0000-4000-8000-000000000001'::uuid]);
  EXCEPTION WHEN insufficient_privilege THEN denied:=true; END;
  IF NOT denied THEN RAISE EXCEPTION 'spoofed authenticated JWT permitted'; END IF;
  PERFORM set_config('app.test_role','service_role',true);
  RAISE NOTICE 'REPORTER_CONTACTS: 7 synthetic PG17 contract cases PASS';
END $tests$;
