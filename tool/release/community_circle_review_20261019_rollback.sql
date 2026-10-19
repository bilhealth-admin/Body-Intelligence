-- Production SQL integration check. NEW synthetic identities only, no Auth HTTP,
-- no password, no physical file/Storage metadata writes, no provider dispatch.
-- Run precheck/residue separately. All data changes below are ROLLED BACK.
-- SQL claims do not certify device UI, genuine Auth or uploaded image bytes.
begin;
set local statement_timeout='30s';
set local lock_timeout='3s';
do $audit$
declare
  a constant uuid:='6ca3caa1-7769-4738-9317-e42fa2a87d0b';
  b constant uuid:='91fb775d-2300-40e8-935d-7a90e4a5da98';
  u uuid;policy text;code_b text;created jsonb;snapshot jsonb;receipt jsonb;
  v_slug text;v_other_slug text;circle uuid;media uuid;invite uuid;report uuid;denied boolean;
  checks jsonb:='{}';error_state text;error_message text;
begin
  if exists(select 1 from auth.users where id in(a,b)) then raise exception 'fixture_identity_already_exists';end if;
  select version into strict policy from public.bil_content_policies where active;
  insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
  values(a,'authenticated','authenticated','circle-review-20261019-6ca3caa1-a@example.invalid',now(),now(),now(),'{"provider":"email","providers":["email"]}','{"audit_marker":"circle-review-20261019-6ca3caa1"}',false),
        (b,'authenticated','authenticated','circle-review-20261019-6ca3caa1-b@example.invalid',now(),now(),now(),'{"provider":"email","providers":["email"]}','{"audit_marker":"circle-review-20261019-6ca3caa1"}',false);
  foreach u in array array[a,b] loop
    perform set_config('request.jwt.claim.sub',u::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
    execute 'set local role authenticated';
    insert into public.bil_content_policy_acceptances(user_id,policy_version) values(u,policy);
    insert into public.bil_public_profiles(user_id,display_name,profile_visibility,discoverable)
      values(u,case when u=a then 'Circle audit author' else 'Circle audit reviewer' end,'public',true);
    receipt:=public.bil_social_public_code_v2();
    if u=b then code_b:=receipt->>'code';end if;
    execute 'reset role';
  end loop;
  checks:=checks||jsonb_build_object('ordinary_owner_policy_profile_code_setup',true);
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  created:=public.bil_circle_create_v1('877da6d8-e259-4ab4-8948-9a043c6acf65','Circle review rollback test','Synthetic circle description','Respect the community','public','open');
  v_slug:=created->>'circle_slug';
  if created->'circle'->>'review_status' is distinct from 'pending' then raise exception 'creation_not_pending';end if;
  if (public.bil_circle_capabilities_v1(v_slug)->>'can_invite')::boolean then raise exception 'pending_circle_invites_enabled';end if;
  if (public.bil_circle_membership_v1(v_slug)->>'can_post')::boolean then raise exception 'pending_circle_posts_enabled';end if;
  checks:=checks||jsonb_build_object('new_circle_pending_creator_only',true);
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated')::text,true);
  if public.bil_circle_read_v1(v_slug)->'circle' is distinct from 'null'::jsonb then raise exception 'pending_circle_leaked';end if;
  if exists(select 1 from public.bil_list_community_circles_v1() c where c.slug=v_slug) then raise exception 'legacy_list_leaked_pending';end if;
  denied:=false;
  begin perform public.bil_circle_review_queue_v1();exception when insufficient_privilege then denied:=true;end;
  if not denied then raise exception 'ordinary_member_gained_review';end if;
  checks:=checks||jsonb_build_object('legacy_and_new_pending_visibility_and_reviewer_denials',true);
  execute 'reset role';
  select id into strict circle from public.bil_community_circles c where c.slug=v_slug;
  insert into public.bil_community_moderators(user_id) values(b);
  execute 'set local role authenticated';
  snapshot:=public.bil_circle_review_content_v1('circle',circle);
  denied:=false;
  begin perform public.bil_decide_circle_review_v1('circle',circle,repeat('0',64),'approve','f5c5ca3a-3823-46f8-b59f-3b2b8c3e36bc','Synthetic stale review');exception when serialization_failure then denied:=true;end;
  if not denied then raise exception 'stale_review_accepted';end if;
  receipt:=public.bil_decide_circle_review_v1('circle',circle,snapshot->>'revision','approve','f5c5ca3a-3823-46f8-b59f-3b2b8c3e36bc','Synthetic reviewed approval');
  if receipt->>'decision'<>'approve' then raise exception 'approval_receipt_invalid';end if;
  receipt:=public.bil_decide_circle_review_v1('circle',circle,snapshot->>'revision','approve','f5c5ca3a-3823-46f8-b59f-3b2b8c3e36bc','Synthetic reviewed approval');
  if receipt->>'duplicate'<>'true' then raise exception 'review_retry_not_idempotent';end if;
  if public.bil_circle_read_v1(v_slug)->'circle'->>'review_status' is distinct from 'approved' then raise exception 'approval_not_visible';end if;
  checks:=checks||jsonb_build_object('independent_review_stale_guard_idempotent_approval',true);
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
  receipt:=public.bil_circle_media_prepare_v1('d5a2b0ee-7046-42a7-b660-75b3541f5d5f',v_slug,'avatar','image/jpeg',1024,640,480);
  media:=(receipt->>'media_id')::uuid;
  denied:=false;
  begin perform public.bil_circle_media_finish_v1('7717d0e4-4ce4-43ca-b2a8-f272d44ac510',media);exception when object_not_in_prerequisite_state then denied:=true;end;
  if not denied then raise exception 'unuploaded_image_published';end if;
  if public.bil_circle_read_v1(v_slug)->'circle'->'avatar' is distinct from 'null'::jsonb then raise exception 'unuploaded_image_visible';end if;
  checks:=checks||jsonb_build_object('unuploaded_image_cannot_finish_or_appear',true);
  receipt:=public.bil_circle_invite_send_v1('dd903358-99e1-4de7-be8d-ffdf19c77b7b',v_slug,code_b);
  invite:=(receipt->>'invite_id')::uuid;
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated')::text,true);
  receipt:=public.bil_circle_invite_action_v1('fd87da45-f805-46f8-b151-1cfbe1adefab',invite,'accept');
  if receipt->'invite'->>'status' is distinct from 'accepted' then raise exception 'invite_accept_failed';end if;
  checks:=checks||jsonb_build_object('approved_circle_code_invite_and_accept',true);
  report:=public.bil_report_circle_v1(v_slug,'Synthetic report for rollback test');
  if public.bil_report_circle_v1(v_slug,'Repeated synthetic report')<>report then raise exception 'report_not_deduplicated';end if;
  snapshot:=public.bil_circle_review_content_v1('report',report);
  receipt:=public.bil_decide_circle_review_v1('report',report,snapshot->>'revision','remove','d4b508d4-0457-459a-89ce-2d85d3f27403','Synthetic removal in rollback transaction');
  if public.bil_circle_read_v1(v_slug)->'circle' is distinct from 'null'::jsonb then raise exception 'removed_circle_still_visible';end if;
  checks:=checks||jsonb_build_object('circle_report_deduplication_review_and_removal',true);
  created:=public.bil_circle_create_v1(gen_random_uuid(),'Second owner rollback circle','Independent owner data','Respect community members','public','open');
  v_other_slug:=created->>'circle_slug';
  execute 'reset role';
  delete from auth.users where id=a;
  if exists(select 1 from public.bil_circle_metadata_v1 where created_by=a)
     or exists(select 1 from public.bil_community_circles where id=circle)
     or exists(select 1 from public.bil_circle_media_v1 where owner_id=a)
     or not exists(select 1 from public.bil_community_circles c where c.slug=v_other_slug)
     or not exists(select 1 from auth.users where id=b) then
    raise exception 'owner_deletion_circle_cleanup_or_isolation_failed';
  end if;
  checks:=checks||jsonb_build_object('owned_circle_account_deletion_and_other_owner_isolation',true);
  perform set_config('bil.circle_review_test_result',jsonb_build_object('status','PASS','assertions',checks,'circle_slug',v_slug,'rolled_back_by_outer_transaction',true)::text,true);
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_message=message_text;
  perform set_config('bil.circle_review_test_result',jsonb_build_object('status','FAIL','sqlstate',error_state,'message',error_message,'assertions_completed_before_failure',checks)::text,true);
end $audit$;
select current_setting('bil.circle_review_test_result',true)::jsonb proof;
rollback;
