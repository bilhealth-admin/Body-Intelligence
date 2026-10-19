-- One uniquely marked synthetic identity. No password/email/provider dispatch.
-- Every write is rolled back; no existing profile or policy row is modified.
begin;
set local statement_timeout='30s';
set local lock_timeout='3s';
do $audit$
declare
  u constant uuid:='e7cc0f08-a13f-4e86-b0c7-a12a3ad830dc';
  policy text; checks jsonb:='{}';
begin
  if exists(select 1 from auth.users where id=u) then raise exception 'fixture_identity_already_exists';end if;
  select version into strict policy from public.bil_content_policies where active;
  insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
    values(u,'authenticated','authenticated','profile-policy-20261019-e7cc0f08@example.invalid',now(),now(),now(),'{"provider":"email","providers":["email"]}','{"audit_marker":"profile-policy-20261019-e7cc0f08"}',false);
  perform set_config('request.jwt.claim.sub',u::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  begin
    insert into public.bil_public_profiles(user_id,display_name,profile_visibility,discoverable) values(u,'Synthetic profile policy','public',true);
    raise exception 'unconsented_profile_was_created';
  exception when insufficient_privilege then
    if sqlerrm <> 'community_policy_acceptance_required' then raise;end if;
  end;
  checks:=checks||jsonb_build_object('unaccepted_profile_insert_denied',true);
  insert into public.bil_content_policy_acceptances(user_id,policy_version) values(u,policy);
  insert into public.bil_public_profiles(user_id,display_name,profile_visibility,discoverable) values(u,'Synthetic profile policy','public',true);
  update public.bil_public_profiles set display_name='Accepted synthetic alias' where user_id=u;
  if not exists(select 1 from public.bil_public_profiles where user_id=u and display_name='Accepted synthetic alias') then raise exception 'accepted_profile_missing';end if;
  checks:=checks||jsonb_build_object('explicit_acceptance_enables_profile_create_and_edit',true);
  execute 'reset role';
  delete from public.bil_content_policy_acceptances where user_id=u;
  execute 'set local role authenticated';
  update public.bil_public_profiles set profile_visibility='private',discoverable=false,allow_messages_from='nobody' where user_id=u;
  if not exists(select 1 from public.bil_public_profiles where user_id=u and profile_visibility='private' and not discoverable) then raise exception 'privacy_reduction_blocked';end if;
  checks:=checks||jsonb_build_object('privacy_reduction_remains_available_without_acceptance',true);
  begin
    update public.bil_public_profiles set display_name='Unaccepted changed alias' where user_id=u;
    raise exception 'unconsented_profile_edit_was_allowed';
  exception when insufficient_privilege then
    if sqlerrm <> 'community_policy_acceptance_required' then raise;end if;
  end;
  checks:=checks||jsonb_build_object('unaccepted_profile_content_update_denied',true);
  execute 'reset role';
  perform set_config('bil.profile_guard_proof',jsonb_build_object('status','PASS','assertions',checks,'rolled_back_by_outer_transaction',true)::text,true);
exception when others then
  perform set_config('bil.profile_guard_proof',jsonb_build_object('status','FAIL','sqlstate',sqlstate,'message',sqlerrm)::text,true);
end
$audit$;
select current_setting('bil.profile_guard_proof')::jsonb as proof;
rollback;
