-- Synthetic identities/configuration ONLY in disposable loopback PostgreSQL.
create function public.qa_atomic_assert(p_ok boolean,p_message text)
returns void language plpgsql as $$ begin
  if p_ok is distinct from true then raise exception 'ASSERT: %',p_message; end if;
end $$;
create function public.qa_atomic_error(p_sql text,p_state text,p_message text default null)
returns void language plpgsql as $$ declare v_state text; v_message text; begin
  begin execute p_sql; exception when others then
    get stacked diagnostics v_state=returned_sqlstate,v_message=message_text;
  end;
  perform public.qa_atomic_assert(v_state=p_state and (p_message is null or v_message=p_message),
    format('Expected %s/%s, got %s/%s for %s',p_state,p_message,v_state,v_message,p_sql));
end $$;
create function public.qa_atomic_payload(p_media jsonb default '[]',p_overrides jsonb default '{}')
returns jsonb language sql as $$ select jsonb_build_object('body','Genuine atomic fixture',
  'media',p_media,'topic_slugs','[]'::jsonb,'circle_slug',null,'location_label',null,
  'mentioned_user_ids','[]'::jsonb,'title',null,'hashtags','[]'::jsonb,
  'collaborator_user_ids','[]'::jsonb,'poll',null,'persistent_draft_id',null)||p_overrides $$;
insert into auth.users(id) values
 ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222'),
 ('33333333-3333-4333-8333-333333333333'),('44444444-4444-4444-8444-444444444444'),
 ('55555555-5555-4555-8555-555555555555');
insert into public.bil_public_profiles(user_id,display_name,profile_visibility)
 select id,'Local QA identity','public' from auth.users;
update public.bil_social_handles_v2 set chosen=true;
insert into public.bil_community_moderators(user_id) values('33333333-3333-4333-8333-333333333333');
-- Synthetic LOCAL policy row satisfies the genuine server contract's fixed5
-- check; it is not evidence that Production Rewards is enabled/configured.
insert into public.bil_community_post_reward_policy(singleton) values(true);
insert into public.bil_content_policies(version,document_url,effective_at,active)
 values('qa-atomic-v1','https://example.invalid/community-policy',now()-interval '1 day',true);
do $$ declare v_id uuid; begin
 for v_id in select id from auth.users loop
  perform set_config('request.jwt.claim.sub',v_id::text,false);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_id,'role','authenticated')::text,false);
  insert into public.bil_content_policy_acceptances(user_id,policy_version) values(v_id,'qa-atomic-v1');
 end loop;
end $$;
insert into storage.buckets(id,name,file_size_limit,allowed_mime_types)
 values('community-post-images','community-post-images',5242880,array['image/jpeg','image/png','image/webp']);
insert into public.bil_community_topics(id,slug,title_copy_key,description_copy_key,icon_key)
 values('66666666-6666-4666-8666-666666666666','nutrition','nutrition_title','nutrition_description','nutrition_icon');
insert into public.bil_community_circles(id,slug,title_copy_key,description_copy_key,rules_copy_key)
 values('77777777-7777-4777-8777-777777777777','healthy-circle','healthy_title','healthy_description','healthy_rules');
insert into public.bil_community_circle_memberships(circle_id,owner_id)
 values('77777777-7777-4777-8777-777777777777','11111111-1111-4111-8111-111111111111');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',false);
select 'ATOMIC_SEED_READY';
