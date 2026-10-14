-- Catalog-only fixture; no user rows or secrets.

-- auth.users is an identity/FK test scaffold only; auth.uid/jwt definitions are captured verbatim.

create schema auth; create schema private;

create table auth.users(id uuid primary key,email text);

grant usage on schema auth,public to authenticated,service_role;

create table "private"."bil_community_member_access" (
  "user_id" uuid not null,
  "suspended" boolean default true not null,
  "reason" text not null,
  "suspended_by" uuid,
  "suspended_at" timestamp with time zone default clock_timestamp() not null,
  "reinstated_by" uuid,
  "reinstated_at" timestamp with time zone,
  "updated_at" timestamp with time zone default clock_timestamp() not null
);

create table "public"."bil_blocks" (
  "blocker_id" uuid not null,
  "blocked_id" uuid not null,
  "created_at" timestamp with time zone default now() not null
);

create table "public"."bil_community_audit_events" (
  "id" bigint generated always as identity not null,
  "actor_id" uuid,
  "event_kind" text not null,
  "target_kind" text,
  "target_id" text,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null
);

create table "public"."bil_content_policies" (
  "version" text not null,
  "locale_code" text default 'en'::text not null,
  "document_url" text not null,
  "effective_at" timestamp with time zone not null,
  "active" boolean default false not null
);

create table "public"."bil_content_policy_acceptances" (
  "user_id" uuid not null,
  "policy_version" text not null,
  "accepted_at" timestamp with time zone default now() not null
);

create table "public"."bil_friendships" (
  "id" uuid default gen_random_uuid() not null,
  "requester_id" uuid not null,
  "addressee_id" uuid not null,
  "status" text default 'pending'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "responded_at" timestamp with time zone
);

create table "public"."bil_messages" (
  "id" uuid default gen_random_uuid() not null,
  "sender_id" uuid not null,
  "recipient_id" uuid not null,
  "body" text not null,
  "created_at" timestamp with time zone default now() not null,
  "read_at" timestamp with time zone,
  "deleted_by_sender_at" timestamp with time zone,
  "deleted_by_recipient_at" timestamp with time zone
);

create table "public"."bil_public_profiles" (
  "user_id" uuid not null,
  "display_name" text not null,
  "avatar_url" text,
  "bio" text,
  "locale_code" text default 'en'::text not null,
  "discoverable" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "profile_visibility" text default 'friends'::text not null,
  "allow_friend_requests" boolean default true not null,
  "allow_follows" boolean default false not null,
  "allow_messages_from" text default 'friends'::text not null,
  "country_code" text,
  "show_followers" boolean default true not null,
  "show_following" boolean default true not null,
  "show_friends" boolean default true not null,
  "show_posts" boolean default true not null,
  "show_membership_tier" boolean default false not null,
  "cover_object_path" text
);

create table "public"."bil_push_outbox" (
  "id" uuid default gen_random_uuid() not null,
  "recipient_id" uuid not null,
  "category" text not null,
  "title" text default 'BIL'::text not null,
  "body" text default 'You have a new update.'::text not null,
  "deep_link" text,
  "created_at" timestamp with time zone default now() not null,
  "dispatched_at" timestamp with time zone,
  "failure_code" text,
  "copy_key" text,
  "source_key" text
);

create table "public"."bil_rate_limit_buckets" (
  "user_id" uuid not null,
  "action" text not null,
  "window_started_at" timestamp with time zone not null,
  "hit_count" integer default 1 not null
);

alter table "private"."bil_community_member_access" add constraint "bil_community_member_access_check" CHECK (((suspended AND (reinstated_at IS NULL) AND (reinstated_by IS NULL)) OR ((NOT suspended) AND (reinstated_at IS NOT NULL))));

alter table "private"."bil_community_member_access" add constraint "bil_community_member_access_pkey" PRIMARY KEY (user_id);

alter table "private"."bil_community_member_access" add constraint "bil_community_member_access_reason_check" CHECK ((((char_length(reason) >= 2) AND (char_length(reason) <= 160)) AND (reason !~ '[[:cntrl:]]'::text)));

alter table "private"."bil_community_member_access" add constraint "bil_community_member_access_reinstated_by_fkey" FOREIGN KEY (reinstated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table "private"."bil_community_member_access" add constraint "bil_community_member_access_suspended_by_fkey" FOREIGN KEY (suspended_by) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table "private"."bil_community_member_access" add constraint "bil_community_member_access_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX bil_idx_comm_access_reinstated_by ON private.bil_community_member_access USING btree (reinstated_by);

CREATE INDEX bil_idx_comm_access_suspended_by ON private.bil_community_member_access USING btree (suspended_by);

alter table "private"."bil_community_member_access" enable row level security;

alter table "public"."bil_blocks" add constraint "bil_blocks_check" CHECK ((blocker_id <> blocked_id));

alter table "public"."bil_blocks" add constraint "bil_blocks_pkey" PRIMARY KEY (blocker_id, blocked_id);

alter table "public"."bil_blocks" add constraint "bil_blocks_blocked_id_fkey" FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table "public"."bil_blocks" add constraint "bil_blocks_blocker_id_fkey" FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX bil_blocks_blocked_id_idx ON public.bil_blocks USING btree (blocked_id, blocker_id);

alter table "public"."bil_blocks" enable row level security;

alter table "public"."bil_community_audit_events" add constraint "bil_community_audit_events_metadata_check" CHECK ((NOT (metadata ?| ARRAY['body'::text, 'message'::text, 'health'::text, 'token'::text])));

alter table "public"."bil_community_audit_events" add constraint "bil_community_audit_events_pkey" PRIMARY KEY (id);

alter table "public"."bil_community_audit_events" add constraint "bil_community_audit_events_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX bil_idx_comm_audit_actor ON public.bil_community_audit_events USING btree (actor_id);

alter table "public"."bil_community_audit_events" enable row level security;

alter table "public"."bil_content_policies" add constraint "bil_content_policies_pkey" PRIMARY KEY (version);

CREATE UNIQUE INDEX bil_content_policies_single_active_uidx ON public.bil_content_policies USING btree (active) WHERE active;

alter table "public"."bil_content_policies" enable row level security;

alter table "public"."bil_content_policy_acceptances" add constraint "bil_content_policy_acceptances_pkey" PRIMARY KEY (user_id, policy_version);

alter table "public"."bil_content_policy_acceptances" add constraint "bil_content_policy_acceptances_policy_version_fkey" FOREIGN KEY (policy_version) REFERENCES bil_content_policies(version);

alter table "public"."bil_content_policy_acceptances" add constraint "bil_content_policy_acceptances_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX bil_idx_policy_accept_version ON public.bil_content_policy_acceptances USING btree (policy_version);

alter table "public"."bil_content_policy_acceptances" enable row level security;

alter table "public"."bil_friendships" add constraint "bil_friendships_check" CHECK ((requester_id <> addressee_id));

alter table "public"."bil_friendships" add constraint "bil_friendships_pkey" PRIMARY KEY (id);

alter table "public"."bil_friendships" add constraint "bil_friendships_requester_id_addressee_id_key" UNIQUE (requester_id, addressee_id);

alter table "public"."bil_friendships" add constraint "bil_friendships_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text])));

alter table "public"."bil_friendships" add constraint "bil_friendships_addressee_id_fkey" FOREIGN KEY (addressee_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table "public"."bil_friendships" add constraint "bil_friendships_requester_id_fkey" FOREIGN KEY (requester_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX bil_friendships_unordered_pair_idx ON public.bil_friendships USING btree (LEAST((requester_id)::text, (addressee_id)::text), GREATEST((requester_id)::text, (addressee_id)::text));

CREATE INDEX bil_friendships_addressee_fk_lookup_idx ON public.bil_friendships USING btree (addressee_id);

CREATE INDEX bil_friendships_requester_accepted_history_idx ON public.bil_friendships USING btree (requester_id, created_at DESC, addressee_id DESC) WHERE (status = 'accepted'::text);

CREATE INDEX bil_friendships_addressee_accepted_history_idx ON public.bil_friendships USING btree (addressee_id, created_at DESC, requester_id DESC) WHERE (status = 'accepted'::text);

CREATE INDEX bil_friendships_incoming_pending_v1_idx ON public.bil_friendships USING btree (addressee_id, requester_id) WHERE (status = 'pending'::text);

alter table "public"."bil_friendships" enable row level security;

alter table "public"."bil_messages" add constraint "bil_messages_body_check" CHECK (((length(body) >= 1) AND (length(body) <= 2000)));

alter table "public"."bil_messages" add constraint "bil_messages_check" CHECK ((sender_id <> recipient_id));

alter table "public"."bil_messages" add constraint "bil_messages_pkey" PRIMARY KEY (id);

alter table "public"."bil_messages" add constraint "bil_messages_recipient_id_fkey" FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table "public"."bil_messages" add constraint "bil_messages_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX bil_messages_parties_idx ON public.bil_messages USING btree (sender_id, recipient_id, created_at DESC);

CREATE INDEX bil_messages_recipient_fk_lookup_idx ON public.bil_messages USING btree (recipient_id);

CREATE INDEX bil_messages_recipient_unread_v1_idx ON public.bil_messages USING btree (recipient_id, sender_id) WHERE ((read_at IS NULL) AND (deleted_by_recipient_at IS NULL));

alter table "public"."bil_messages" enable row level security;

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_allow_messages_from_check" CHECK ((allow_messages_from = ANY (ARRAY['friends'::text, 'nobody'::text])));

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_bio_check" CHECK ((length(bio) <= 280));

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_country_code_check" CHECK (((country_code IS NULL) OR (country_code ~ '^[A-Z]{2}$'::text)));

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_cover_object_path_check" CHECK (((cover_object_path IS NULL) OR ((cover_object_path ~~ ((user_id)::text || '/community-cover/%'::text)) AND (cover_object_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/community-cover/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'::text))));

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_display_name_check" CHECK (((length(display_name) >= 2) AND (length(display_name) <= 60)));

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_locale_code_check" CHECK ((locale_code = ANY (ARRAY['ar'::text, 'en'::text, 'fr'::text, 'es'::text, 'tr'::text, 'de'::text, 'it'::text, 'pt-BR'::text, 'pt-PT'::text, 'ur'::text, 'fa'::text, 'hi'::text, 'id'::text, 'ms'::text, 'ja'::text, 'ko'::text, 'zh-Hans'::text, 'zh-Hant'::text, 'ru'::text, 'bn'::text, 'vi'::text, 'th'::text, 'pl'::text, 'nl'::text, 'uk'::text])));

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_pkey" PRIMARY KEY (user_id);

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_profile_visibility_check" CHECK ((profile_visibility = ANY (ARRAY['public'::text, 'friends'::text, 'private'::text])));

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_visibility_check" CHECK ((profile_visibility = ANY (ARRAY['public'::text, 'friends'::text, 'private'::text])));

alter table "public"."bil_public_profiles" add constraint "bil_public_profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX bil_public_profiles_discoverable_name_idx ON public.bil_public_profiles USING btree (display_name, user_id) WHERE ((discoverable = true) AND (allow_friend_requests = true));

alter table "public"."bil_public_profiles" enable row level security;

alter table "public"."bil_push_outbox" add constraint "bil_push_outbox_category_check" CHECK ((category = ANY (ARRAY['friend_request'::text, 'message'::text, 'community'::text, 'account'::text, 'ai_coach'::text])));

alter table "public"."bil_push_outbox" add constraint "bil_push_outbox_check" CHECK (((length(title) <= 80) AND (length(body) <= 180)));

alter table "public"."bil_push_outbox" add constraint "bil_push_outbox_copy_key_check" CHECK (((copy_key IS NULL) OR ((char_length(copy_key) >= 3) AND (char_length(copy_key) <= 80))));

alter table "public"."bil_push_outbox" add constraint "bil_push_outbox_deep_link_check" CHECK (((deep_link IS NULL) OR (deep_link ~ '^bil://(community|settings)(/|$)'::text)));

alter table "public"."bil_push_outbox" add constraint "bil_push_outbox_pkey" PRIMARY KEY (id);

alter table "public"."bil_push_outbox" add constraint "bil_push_outbox_source_key_check" CHECK (((source_key IS NULL) OR ((char_length(source_key) >= 16) AND (char_length(source_key) <= 128))));

alter table "public"."bil_push_outbox" add constraint "bil_push_outbox_recipient_id_fkey" FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX bil_push_outbox_recipient_source_uidx ON public.bil_push_outbox USING btree (recipient_id, source_key) WHERE (source_key IS NOT NULL);

CREATE INDEX bil_push_outbox_recipient_fk_lookup_idx ON public.bil_push_outbox USING btree (recipient_id);

alter table "public"."bil_push_outbox" enable row level security;

alter table "public"."bil_rate_limit_buckets" add constraint "bil_rate_limit_buckets_pkey" PRIMARY KEY (user_id, action, window_started_at);

alter table "public"."bil_rate_limit_buckets" add constraint "bil_rate_limit_buckets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table "public"."bil_rate_limit_buckets" enable row level security;
