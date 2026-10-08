-- Synthetic test identities only. Never load against a pre-existing database.
insert into auth.users(id) select (repeat(i::text,8)||'-'||repeat(i::text,4)||'-4'||repeat(i::text,3)||'-8'||repeat(i::text,3)||'-'||repeat(i::text,12))::uuid from generate_series(1,7) i;
insert into public.bil_public_profiles(user_id,display_name,profile_visibility)
  select id,case left(id::text,1) when '1' then 'Circle manager' when '2' then 'Circle member' when '3' then 'Third person' when '4' then 'Invite recipient' else 'Local test profile' end,'public'
  from auth.users where left(id::text,1)<>'6';
-- Generated handles stay chosen=false. No bio. Saved name+code is sufficient.
insert into public.bil_social_public_codes_v2(user_id,code)
  select id,repeat(left(id::text,1),32) from auth.users where left(id::text,1) in ('1','2','3','4','7');
insert into public.bil_content_policies(version,document_url,effective_at,active)
  values('bil06-local-v1','https://example.invalid/bil06-policy',clock_timestamp()-interval '1 day',true);
do $$ declare v_uid uuid; begin
  for v_uid in select id from auth.users loop
    perform set_config('request.jwt.claim.sub',v_uid::text,false);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_uid,'role','authenticated')::text,false);
    insert into public.bil_content_policy_acceptances(user_id,policy_version) values(v_uid,'bil06-local-v1');
  end loop;
end $$;
insert into private.bil_community_member_access(user_id,reason,suspended)
  values('77777777-7777-4777-8777-777777777777','local suspended fixture',true);
insert into public.bil_community_circles(id,slug,title_copy_key,description_copy_key,rules_copy_key,access,join_policy)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','alpha-circle','community_circle_alpha','community_circle_alpha_body','community_circle_standard_rules','public','open'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','beta-circle','community_circle_beta','community_circle_beta_body','community_circle_standard_rules','public','request'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','hidden-base','community_circle_hidden','community_circle_hidden_body','community_circle_standard_rules','private','invite');
select set_config('request.jwt.claim.sub','',false);
select set_config('request.jwt.claims','{}',false);
