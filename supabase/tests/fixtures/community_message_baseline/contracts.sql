-- Reconstructed exactly from captured policy expressions, ACL and triggers.

revoke all on "private"."bil_community_member_access" from public,authenticated,anon,service_role;

revoke all on "public"."bil_blocks" from public,authenticated,anon,service_role;

grant insert on "public"."bil_blocks" to "authenticated";

grant select on "public"."bil_blocks" to "authenticated";

grant update on "public"."bil_blocks" to "authenticated";

grant delete on "public"."bil_blocks" to "authenticated";

grant truncate on "public"."bil_blocks" to "service_role";

grant references on "public"."bil_blocks" to "service_role";

grant trigger on "public"."bil_blocks" to "service_role";

grant maintain on "public"."bil_blocks" to "service_role";

revoke all on "public"."bil_community_audit_events" from public,authenticated,anon,service_role;

grant truncate on "public"."bil_community_audit_events" to "service_role";

grant references on "public"."bil_community_audit_events" to "service_role";

grant trigger on "public"."bil_community_audit_events" to "service_role";

grant maintain on "public"."bil_community_audit_events" to "service_role";

revoke all on "public"."bil_content_policies" from public,authenticated,anon,service_role;

grant select on "public"."bil_content_policies" to "authenticated";

grant truncate on "public"."bil_content_policies" to "service_role";

grant references on "public"."bil_content_policies" to "service_role";

grant trigger on "public"."bil_content_policies" to "service_role";

grant maintain on "public"."bil_content_policies" to "service_role";

revoke all on "public"."bil_content_policy_acceptances" from public,authenticated,anon,service_role;

grant select on "public"."bil_content_policy_acceptances" to "authenticated";

grant truncate on "public"."bil_content_policy_acceptances" to "service_role";

grant references on "public"."bil_content_policy_acceptances" to "service_role";

grant trigger on "public"."bil_content_policy_acceptances" to "service_role";

grant maintain on "public"."bil_content_policy_acceptances" to "service_role";

grant insert("user_id") on "public"."bil_content_policy_acceptances" to "authenticated";

grant update("user_id") on "public"."bil_content_policy_acceptances" to "authenticated";

grant insert("policy_version") on "public"."bil_content_policy_acceptances" to "authenticated";

grant update("policy_version") on "public"."bil_content_policy_acceptances" to "authenticated";

revoke all on "public"."bil_friendships" from public,authenticated,anon,service_role;

grant select on "public"."bil_friendships" to "authenticated";

grant delete on "public"."bil_friendships" to "authenticated";

grant truncate on "public"."bil_friendships" to "service_role";

grant references on "public"."bil_friendships" to "service_role";

grant trigger on "public"."bil_friendships" to "service_role";

grant maintain on "public"."bil_friendships" to "service_role";

grant insert("requester_id") on "public"."bil_friendships" to "authenticated";

grant insert("addressee_id") on "public"."bil_friendships" to "authenticated";

grant update("status") on "public"."bil_friendships" to "authenticated";

grant update("responded_at") on "public"."bil_friendships" to "authenticated";

revoke all on "public"."bil_messages" from public,authenticated,anon,service_role;

grant select on "public"."bil_messages" to "authenticated";

grant truncate on "public"."bil_messages" to "service_role";

grant references on "public"."bil_messages" to "service_role";

grant trigger on "public"."bil_messages" to "service_role";

grant maintain on "public"."bil_messages" to "service_role";

grant insert("sender_id") on "public"."bil_messages" to "authenticated";

grant insert("recipient_id") on "public"."bil_messages" to "authenticated";

grant insert("body") on "public"."bil_messages" to "authenticated";

revoke all on "public"."bil_public_profiles" from public,authenticated,anon,service_role;

grant insert on "public"."bil_public_profiles" to "authenticated";

grant select on "public"."bil_public_profiles" to "authenticated";

grant update on "public"."bil_public_profiles" to "authenticated";

grant delete on "public"."bil_public_profiles" to "authenticated";

grant truncate on "public"."bil_public_profiles" to "service_role";

grant references on "public"."bil_public_profiles" to "service_role";

grant trigger on "public"."bil_public_profiles" to "service_role";

grant maintain on "public"."bil_public_profiles" to "service_role";

revoke all on "public"."bil_push_outbox" from public,authenticated,anon,service_role;

grant select on "public"."bil_push_outbox" to "service_role";

grant truncate on "public"."bil_push_outbox" to "service_role";

grant references on "public"."bil_push_outbox" to "service_role";

grant trigger on "public"."bil_push_outbox" to "service_role";

grant maintain on "public"."bil_push_outbox" to "service_role";

revoke all on "public"."bil_rate_limit_buckets" from public,authenticated,anon,service_role;

grant truncate on "public"."bil_rate_limit_buckets" to "service_role";

grant references on "public"."bil_rate_limit_buckets" to "service_role";

grant trigger on "public"."bil_rate_limit_buckets" to "service_role";

grant maintain on "public"."bil_rate_limit_buckets" to "service_role";

revoke all on function auth.uid() from public,anon,authenticated,service_role;

grant execute on function auth.uid() to public;

grant execute on function auth.uid() to "supabase_auth_admin";

grant execute on function auth.uid() to "dashboard_user";

revoke all on function auth.jwt() from public,anon,authenticated,service_role;

grant execute on function auth.jwt() to public;

grant execute on function auth.jwt() to "supabase_auth_admin";

grant execute on function auth.jwt() to "dashboard_user";

revoke all on function "public".bil_community_contact_exchange_violation(text) from public,anon,authenticated,service_role;

grant execute on function "public".bil_community_contact_exchange_violation(text) to "authenticated";

revoke all on function private.bil_is_blocked_with(uuid) from public,anon,authenticated,service_role;

grant execute on function private.bil_is_blocked_with(uuid) to "authenticated";

revoke all on function private.bil_assert_current_community_policy() from public,anon,authenticated,service_role;

revoke all on function private.bil_guard_unblocked_community_message() from public,anon,authenticated,service_role;

revoke all on function private.bil_lock_community_block_pair() from public,anon,authenticated,service_role;

revoke all on function private.bil_validate_community_policy_acceptance() from public,anon,authenticated,service_role;

revoke all on function "public".bil_audit_community_action() from public,anon,authenticated,service_role;

grant execute on function "public".bil_audit_community_action() to "service_role";

revoke all on function "public".bil_can_use_community() from public,anon,authenticated,service_role;

grant execute on function "public".bil_can_use_community() to "authenticated";

revoke all on function "public".bil_consume_rate_limit(text,integer,integer) from public,anon,authenticated,service_role;

grant execute on function "public".bil_consume_rate_limit(text,integer,integer) to "authenticated";

grant execute on function "public".bil_consume_rate_limit(text,integer,integer) to "service_role";

revoke all on function "public".bil_enforce_community_contact_exchange() from public,anon,authenticated,service_role;

revoke all on function "public".bil_enqueue_private_push() from public,anon,authenticated,service_role;

grant execute on function "public".bil_enqueue_private_push() to "service_role";

revoke all on function "public".bil_guard_community_member_access() from public,anon,authenticated,service_role;

revoke all on function "public".bil_recipient_allows_community_message(uuid) from public,anon,authenticated,service_role;

grant execute on function "public".bil_recipient_allows_community_message(uuid) to "authenticated";

revoke all on function "public".bil_require_community_policy() from public,anon,authenticated,service_role;

grant execute on function "public".bil_require_community_policy() to "service_role";

create policy "bil_blocks_delete_own" on "public"."bil_blocks" as PERMISSIVE for DELETE to "authenticated" using ((blocker_id = ( SELECT auth.uid() AS uid)));

create policy "bil_blocks_insert_own" on "public"."bil_blocks" as PERMISSIVE for INSERT to "authenticated" with check ((blocker_id = ( SELECT auth.uid() AS uid)));

create policy "bil_blocks_own" on "public"."bil_blocks" as PERMISSIVE for SELECT to "authenticated" using ((blocker_id = ( SELECT auth.uid() AS uid)));

create policy "bil_content_policies_active_read" on "public"."bil_content_policies" as PERMISSIVE for SELECT to "authenticated" using ((active = true));

create policy "bil_policy_acceptance_own" on "public"."bil_content_policy_acceptances" as PERMISSIVE for ALL to "authenticated" using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));

create policy "bil_friendships_delete_parties" on "public"."bil_friendships" as PERMISSIVE for DELETE to "authenticated" using (((( SELECT auth.uid() AS uid) = requester_id) OR (( SELECT auth.uid() AS uid) = addressee_id)));

create policy "bil_friendships_read_parties" on "public"."bil_friendships" as PERMISSIVE for SELECT to "authenticated" using (((( SELECT auth.uid() AS uid) = requester_id) OR (( SELECT auth.uid() AS uid) = addressee_id)));

create policy "bil_friendships_request" on "public"."bil_friendships" as PERMISSIVE for INSERT to "authenticated" with check (((requester_id = ( SELECT auth.uid() AS uid)) AND (status = 'pending'::text) AND (responded_at IS NULL)));

create policy "bil_friendships_respond" on "public"."bil_friendships" as PERMISSIVE for UPDATE to "authenticated" using (((addressee_id = ( SELECT auth.uid() AS uid)) AND (status = 'pending'::text))) with check (((addressee_id = ( SELECT auth.uid() AS uid)) AND (status = ANY (ARRAY['accepted'::text, 'declined'::text])) AND (responded_at IS NOT NULL)));

create policy "bil_messages_read_parties" on "public"."bil_messages" as PERMISSIVE for SELECT to "authenticated" using ((((sender_id = ( SELECT auth.uid() AS uid)) AND (deleted_by_sender_at IS NULL)) OR ((recipient_id = ( SELECT auth.uid() AS uid)) AND (deleted_by_recipient_at IS NULL))));

create policy "bil_messages_send_friends" on "public"."bil_messages" as PERMISSIVE for INSERT to "authenticated" with check (((sender_id = ( SELECT auth.uid() AS uid)) AND bil_recipient_allows_community_message(recipient_id) AND (NOT (EXISTS ( SELECT 1
   FROM bil_blocks b
  WHERE (((b.blocker_id = bil_messages.sender_id) AND (b.blocked_id = bil_messages.recipient_id)) OR ((b.blocker_id = bil_messages.recipient_id) AND (b.blocked_id = bil_messages.sender_id)))))) AND (EXISTS ( SELECT 1
   FROM bil_friendships f
  WHERE ((f.status = 'accepted'::text) AND (((f.requester_id = bil_messages.sender_id) AND (f.addressee_id = bil_messages.recipient_id)) OR ((f.addressee_id = bil_messages.sender_id) AND (f.requester_id = bil_messages.recipient_id))))))));

create policy "bil_profiles_privacy_read" on "public"."bil_public_profiles" as PERMISSIVE for SELECT to "authenticated" using (((user_id = ( SELECT auth.uid() AS uid)) OR ((NOT private.bil_is_blocked_with(user_id)) AND (((profile_visibility = 'public'::text) AND (discoverable = true)) OR ((profile_visibility = 'friends'::text) AND (EXISTS ( SELECT 1
   FROM bil_friendships f
  WHERE ((f.status = 'accepted'::text) AND (((f.requester_id = ( SELECT auth.uid() AS uid)) AND (f.addressee_id = bil_public_profiles.user_id)) OR ((f.addressee_id = ( SELECT auth.uid() AS uid)) AND (f.requester_id = bil_public_profiles.user_id)))))))))));

create policy "bil_profiles_update_own" on "public"."bil_public_profiles" as PERMISSIVE for UPDATE to "authenticated" using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));

create policy "bil_profiles_write_own" on "public"."bil_public_profiles" as PERMISSIVE for INSERT to "authenticated" with check ((user_id = ( SELECT auth.uid() AS uid)));

CREATE TRIGGER bil_00_blocks_relationship_lock BEFORE INSERT OR DELETE ON public.bil_blocks FOR EACH ROW EXECUTE FUNCTION private.bil_lock_community_block_pair();

CREATE TRIGGER bil_00_messages_block_guard BEFORE INSERT ON public.bil_messages FOR EACH ROW EXECUTE FUNCTION private.bil_guard_unblocked_community_message();

CREATE TRIGGER bil_00_messages_contact_exchange_guard BEFORE INSERT OR UPDATE OF body ON public.bil_messages FOR EACH ROW EXECUTE FUNCTION bil_enforce_community_contact_exchange();

CREATE TRIGGER bil_00_messages_member_access BEFORE INSERT ON public.bil_messages FOR EACH ROW EXECUTE FUNCTION bil_guard_community_member_access();

CREATE TRIGGER bil_message_push_outbox AFTER INSERT ON public.bil_messages FOR EACH ROW EXECUTE FUNCTION bil_enqueue_private_push();

CREATE TRIGGER bil_messages_abuse_guard BEFORE INSERT ON public.bil_messages FOR EACH ROW EXECUTE FUNCTION bil_require_community_policy();

CREATE TRIGGER bil_messages_audit AFTER INSERT OR DELETE OR UPDATE ON public.bil_messages FOR EACH ROW EXECUTE FUNCTION bil_audit_community_action();

CREATE TRIGGER bil_00_content_policy_acceptance_guard BEFORE INSERT OR UPDATE ON public.bil_content_policy_acceptances FOR EACH ROW EXECUTE FUNCTION private.bil_validate_community_policy_acceptance();
