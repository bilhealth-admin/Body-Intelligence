-- Schema-only catalog read from authorized Production on 2026-10-11.
-- Synthetic accounts/claims are provided by the local runner; no user rows.
-- Focused review/reward dependency slice; this is not a full Supabase dump.
create table private.bil_ai_coach_admins (
  "user_id" uuid not null,
  "active" boolean default true not null,
  "granted_at" timestamp with time zone default now() not null,
  "granted_by" uuid,
  "reason" text default 'owner_approved'::text not null
);
create table private.bil_community_member_access (
  "user_id" uuid not null,
  "suspended" boolean default true not null,
  "reason" text not null,
  "suspended_by" uuid,
  "suspended_at" timestamp with time zone default clock_timestamp() not null,
  "reinstated_by" uuid,
  "reinstated_at" timestamp with time zone,
  "updated_at" timestamp with time zone default clock_timestamp() not null
);
create table private.bil_community_post_events_v1 (
  "id" uuid default gen_random_uuid() not null,
  "owner_id" uuid not null,
  "event_kind" text not null,
  "entity_kind" text not null,
  "entity_id" uuid not null,
  "event_key" text not null,
  "ai_tokens" integer default 0 not null,
  "reward_reason" text default 'not_applicable'::text not null,
  "created_at" timestamp with time zone default clock_timestamp() not null,
  "seen_at" timestamp with time zone
);
create table public.bil_ai_credit_balances (
  "owner_id" uuid not null,
  "granted" bigint default 0 not null,
  "used" bigint default 0 not null,
  "reserved" bigint default 0 not null,
  "updated_at" timestamp with time zone default now() not null,
  "refund_debt" bigint default 0 not null
);
create table public.bil_blocks (
  "blocker_id" uuid not null,
  "blocked_id" uuid not null,
  "created_at" timestamp with time zone default now() not null
);
create table public.bil_community_audit_events (
  "id" bigint not null,
  "actor_id" uuid,
  "event_kind" text not null,
  "target_kind" text,
  "target_id" text,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null
);
create table public.bil_community_moderators (
  "user_id" uuid not null,
  "created_at" timestamp with time zone default now() not null
);
create table public.bil_community_notifications (
  "id" uuid default gen_random_uuid() not null,
  "recipient_id" uuid not null,
  "actor_id" uuid,
  "kind" text not null,
  "friendship_id" uuid,
  "source_key" text not null,
  "created_at" timestamp with time zone default now() not null,
  "seen_at" timestamp with time zone,
  "entity_kind" text not null,
  "entity_id" text not null,
  "copy_key" text not null,
  "deep_link_path" text not null,
  "metadata" jsonb default '{}'::jsonb not null
);
create table public.bil_community_poll_options (
  "id" uuid default gen_random_uuid() not null,
  "post_id" uuid not null,
  "position" integer not null,
  "option_text" text not null
);
create table public.bil_community_polls (
  "post_id" uuid not null,
  "question" text not null,
  "allow_multiple" boolean default false not null,
  "closes_at" timestamp with time zone,
  "created_at" timestamp with time zone default clock_timestamp() not null
);
create table public.bil_community_post_approval_grants (
  "post_id" uuid not null,
  "owner_id" uuid not null,
  "approved_by" uuid,
  "reward_day" date default (timezone('UTC'::text, now()))::date not null,
  "tokens" integer default 5 not null,
  "reward_reason" text default 'granted'::text not null,
  "granted_at" timestamp with time zone default now() not null
);
create table public.bil_community_post_media_v1 (
  "post_id" uuid not null,
  "position" smallint not null,
  "object_path" text not null,
  "mime_type" text not null,
  "bytes" integer not null,
  "width" integer not null,
  "height" integer not null,
  "created_at" timestamp with time zone default clock_timestamp() not null
);
create table public.bil_community_post_reward_policy (
  "singleton" boolean default true not null,
  "tokens_per_approval" integer default 5 not null,
  "max_rewarded_posts_per_owner_per_utc_day" integer default 5 not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public.bil_community_post_reward_usage (
  "owner_id" uuid not null,
  "reward_day" date not null,
  "rewarded_posts" integer default 0 not null,
  "granted_tokens" integer default 0 not null,
  "updated_at" timestamp with time zone default now() not null
);
create table public.bil_community_posts (
  "id" uuid default gen_random_uuid() not null,
  "author_id" uuid not null,
  "body" text not null,
  "media_url" text,
  "visibility" text default 'friends'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "edited_at" timestamp with time zone,
  "deleted_at" timestamp with time zone,
  "media_object_path" text,
  "media_mime_type" text,
  "media_bytes" integer,
  "media_width" integer,
  "media_height" integer,
  "moderation_status" text default 'pending'::text not null,
  "reviewed_at" timestamp with time zone,
  "moderation_visibility" text default 'visible'::text not null,
  "location_label" text,
  "title" text
);
create table public.bil_public_profiles (
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
create table public.bil_push_outbox (
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
create table public.bil_friendships (
  "id" uuid default gen_random_uuid() not null,
  "requester_id" uuid not null,
  "addressee_id" uuid not null,
  "status" text default 'pending'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "responded_at" timestamp with time zone
);
alter table public.bil_friendships add primary key(id);
alter table public.bil_community_audit_events alter column id add generated always as identity;
alter table private.bil_ai_coach_admins add constraint "bil_ai_coach_admins_pkey" PRIMARY KEY (user_id);
alter table private.bil_ai_coach_admins add constraint "bil_ai_coach_admins_reason_check" CHECK (((char_length(reason) >= 3) AND (char_length(reason) <= 160)));
alter table private.bil_community_member_access add constraint "bil_community_member_access_check" CHECK (((suspended AND (reinstated_at IS NULL) AND (reinstated_by IS NULL)) OR ((NOT suspended) AND (reinstated_at IS NOT NULL))));
alter table private.bil_community_member_access add constraint "bil_community_member_access_pkey" PRIMARY KEY (user_id);
alter table private.bil_community_member_access add constraint "bil_community_member_access_reason_check" CHECK ((((char_length(reason) >= 2) AND (char_length(reason) <= 160)) AND (reason !~ '[[:cntrl:]]'::text)));
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_ai_tokens_check" CHECK ((ai_tokens >= 0));
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_check" CHECK (((event_kind = 'post_approved'::text) OR (ai_tokens = 0)));
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_check1" CHECK (((ai_tokens = 0) OR (reward_reason = 'granted'::text)));
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_entity_kind_check" CHECK ((entity_kind = ANY (ARRAY['post'::text, 'report'::text])));
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_event_key_check" CHECK (((char_length(event_key) >= 16) AND (char_length(event_key) <= 128)));
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_event_key_key" UNIQUE (event_key);
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_event_kind_check" CHECK ((event_kind = ANY (ARRAY['review_requested'::text, 'post_submitted'::text, 'post_approved'::text, 'post_rejected'::text])));
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_pkey" PRIMARY KEY (id);
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_reward_reason_check" CHECK ((reward_reason = ANY (ARRAY['not_applicable'::text, 'granted'::text, 'daily_cap_reached'::text])));
alter table public.bil_ai_credit_balances add constraint "bil_ai_credit_balance_not_overdrawn" CHECK (((used + reserved) <= granted));
alter table public.bil_ai_credit_balances add constraint "bil_ai_credit_balances_granted_check" CHECK ((granted >= 0));
alter table public.bil_ai_credit_balances add constraint "bil_ai_credit_balances_pkey" PRIMARY KEY (owner_id);
alter table public.bil_ai_credit_balances add constraint "bil_ai_credit_balances_refund_debt_check" CHECK ((refund_debt >= 0));
alter table public.bil_ai_credit_balances add constraint "bil_ai_credit_balances_reserved_check" CHECK ((reserved >= 0));
alter table public.bil_ai_credit_balances add constraint "bil_ai_credit_balances_used_check" CHECK ((used >= 0));
alter table public.bil_blocks add constraint "bil_blocks_check" CHECK ((blocker_id <> blocked_id));
alter table public.bil_blocks add constraint "bil_blocks_pkey" PRIMARY KEY (blocker_id, blocked_id);
alter table public.bil_community_audit_events add constraint "bil_community_audit_events_metadata_check" CHECK ((NOT (metadata ?| ARRAY['body'::text, 'message'::text, 'health'::text, 'token'::text])));
alter table public.bil_community_audit_events add constraint "bil_community_audit_events_pkey" PRIMARY KEY (id);
alter table public.bil_community_moderators add constraint "bil_community_moderators_pkey" PRIMARY KEY (user_id);
alter table public.bil_community_notifications add constraint "bil_community_notifications_copy_key_check" CHECK ((copy_key ~ '^[a-z][a-z0-9_]{2,63}$'::text));
alter table public.bil_community_notifications add constraint "bil_community_notifications_deep_link_path_check" CHECK ((((char_length(deep_link_path) >= 2) AND (char_length(deep_link_path) <= 240)) AND (deep_link_path ~ '^/community(/[A-Za-z0-9._~-]+)*$'::text)));
alter table public.bil_community_notifications add constraint "bil_community_notifications_entity_id_check" CHECK (((char_length(entity_id) >= 1) AND (char_length(entity_id) <= 160)));
alter table public.bil_community_notifications add constraint "bil_community_notifications_entity_kind_check" CHECK ((entity_kind = ANY (ARRAY['friendship'::text, 'post'::text, 'comment'::text, 'profile'::text, 'reward'::text, 'quest'::text, 'badge'::text, 'challenge'::text])));
alter table public.bil_community_notifications add constraint "bil_community_notifications_kind_check" CHECK ((kind = ANY (ARRAY['friend_request'::text, 'friend_accepted'::text, 'post_like'::text, 'post_save'::text, 'comment'::text, 'reply'::text, 'follow'::text, 'mention'::text, 'reward_earned'::text, 'quest_completed'::text, 'badge_earned'::text, 'challenge_update'::text, 'collaboration_invite'::text, 'collaboration_accepted'::text])));
alter table public.bil_community_notifications add constraint "bil_community_notifications_metadata_check" CHECK (((jsonb_typeof(metadata) = 'object'::text) AND (octet_length((metadata)::text) <= 4096)));
alter table public.bil_community_notifications add constraint "bil_community_notifications_pkey" PRIMARY KEY (id);
alter table public.bil_community_notifications add constraint "bil_community_notifications_source_key_check" CHECK (((char_length(source_key) >= 16) AND (char_length(source_key) <= 128)));
alter table public.bil_community_notifications add constraint "bil_community_notifications_source_key_key" UNIQUE (source_key);
alter table public.bil_community_poll_options add constraint "bil_community_poll_options_option_text_check" CHECK ((((char_length(option_text) >= 1) AND (char_length(option_text) <= 100)) AND (option_text = btrim(option_text))));
alter table public.bil_community_poll_options add constraint "bil_community_poll_options_pkey" PRIMARY KEY (id);
alter table public.bil_community_poll_options add constraint "bil_community_poll_options_position_check" CHECK ((("position" >= 0) AND ("position" <= 5)));
alter table public.bil_community_poll_options add constraint "bil_community_poll_options_post_id_id_key" UNIQUE (post_id, id);
alter table public.bil_community_poll_options add constraint "bil_community_poll_options_post_id_position_key" UNIQUE (post_id, "position");
alter table public.bil_community_polls add constraint "bil_community_polls_check" CHECK (((closes_at IS NULL) OR (closes_at > created_at)));
alter table public.bil_community_polls add constraint "bil_community_polls_pkey" PRIMARY KEY (post_id);
alter table public.bil_community_polls add constraint "bil_community_polls_question_check" CHECK ((((char_length(question) >= 1) AND (char_length(question) <= 200)) AND (question = btrim(question))));
alter table public.bil_community_post_approval_grants add constraint "bil_community_post_approval_grants_pkey" PRIMARY KEY (post_id);
alter table public.bil_community_post_approval_grants add constraint "bil_community_post_approval_grants_reward_reason_check" CHECK ((reward_reason = ANY (ARRAY['granted'::text, 'daily_cap_reached'::text])));
alter table public.bil_community_post_approval_grants add constraint "bil_community_post_approval_grants_tokens_check" CHECK ((tokens = ANY (ARRAY[0, 5])));
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_bytes_check" CHECK (((bytes >= 1) AND (bytes <= 5242880)));
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_check" CHECK ((((width)::bigint * (height)::bigint) <= 40000000));
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_height_check" CHECK (((height >= 1) AND (height <= 8192)));
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_mime_type_check" CHECK ((mime_type = ANY (ARRAY['image/jpeg'::text, 'image/png'::text, 'image/webp'::text])));
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_object_path_key" UNIQUE (object_path);
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_pkey" PRIMARY KEY (post_id, "position");
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_position_check" CHECK ((("position" >= 0) AND ("position" <= 3)));
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_width_check" CHECK (((width >= 1) AND (width <= 8192)));
alter table public.bil_community_post_reward_policy add constraint "bil_community_post_reward_po_max_rewarded_posts_per_owner_check" CHECK (((max_rewarded_posts_per_owner_per_utc_day >= 1) AND (max_rewarded_posts_per_owner_per_utc_day <= 100)));
alter table public.bil_community_post_reward_policy add constraint "bil_community_post_reward_policy_pkey" PRIMARY KEY (singleton);
alter table public.bil_community_post_reward_policy add constraint "bil_community_post_reward_policy_singleton_check" CHECK (singleton);
alter table public.bil_community_post_reward_policy add constraint "bil_community_post_reward_policy_tokens_per_approval_check" CHECK ((tokens_per_approval = 5));
alter table public.bil_community_post_reward_usage add constraint "bil_community_post_reward_usage_check" CHECK ((granted_tokens = (rewarded_posts * 5)));
alter table public.bil_community_post_reward_usage add constraint "bil_community_post_reward_usage_granted_tokens_check" CHECK ((granted_tokens >= 0));
alter table public.bil_community_post_reward_usage add constraint "bil_community_post_reward_usage_pkey" PRIMARY KEY (owner_id, reward_day);
alter table public.bil_community_post_reward_usage add constraint "bil_community_post_reward_usage_rewarded_posts_check" CHECK ((rewarded_posts >= 0));
alter table public.bil_community_posts add constraint "bil_community_posts_body_check" CHECK (((length(body) >= 1) AND (length(body) <= 1200)));
alter table public.bil_community_posts add constraint "bil_community_posts_location_label_check" CHECK (((location_label IS NULL) OR (((char_length(location_label) >= 2) AND (char_length(location_label) <= 80)) AND (location_label = btrim(location_label)) AND (location_label !~ '[[:cntrl:]]'::text))));
alter table public.bil_community_posts add constraint "bil_community_posts_media_all_or_none" CHECK ((((media_object_path IS NULL) AND (media_mime_type IS NULL) AND (media_bytes IS NULL) AND (media_width IS NULL) AND (media_height IS NULL)) OR ((media_object_path IS NOT NULL) AND (media_mime_type IS NOT NULL) AND (media_bytes IS NOT NULL) AND (media_width IS NOT NULL) AND (media_height IS NOT NULL))));
alter table public.bil_community_posts add constraint "bil_community_posts_media_dimensions" CHECK (((media_width IS NULL) OR (((media_width >= 1) AND (media_width <= 8192)) AND ((media_height >= 1) AND (media_height <= 8192)) AND (((media_width)::bigint * (media_height)::bigint) <= 40000000))));
alter table public.bil_community_posts add constraint "bil_community_posts_media_mime" CHECK (((media_mime_type IS NULL) OR (media_mime_type = ANY (ARRAY['image/jpeg'::text, 'image/png'::text, 'image/webp'::text]))));
alter table public.bil_community_posts add constraint "bil_community_posts_media_owned_path" CHECK (((media_object_path IS NULL) OR ((split_part(media_object_path, '/'::text, 1) = (author_id)::text) AND (split_part(media_object_path, '/'::text, 2) = (id)::text) AND (media_object_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'::text))));
alter table public.bil_community_posts add constraint "bil_community_posts_media_size" CHECK (((media_bytes IS NULL) OR ((media_bytes >= 1) AND (media_bytes <= 5242880))));
alter table public.bil_community_posts add constraint "bil_community_posts_moderation_status_check" CHECK ((moderation_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])));
alter table public.bil_community_posts add constraint "bil_community_posts_moderation_visibility_check" CHECK ((moderation_visibility = ANY (ARRAY['visible'::text, 'hidden_by_moderator'::text, 'removed_by_moderator'::text])));
alter table public.bil_community_posts add constraint "bil_community_posts_pkey" PRIMARY KEY (id);
alter table public.bil_community_posts add constraint "bil_community_posts_review_state_check" CHECK ((((moderation_status = 'pending'::text) AND (reviewed_at IS NULL)) OR ((moderation_status = 'rejected'::text) AND (reviewed_at IS NOT NULL)) OR (moderation_status = 'approved'::text)));
alter table public.bil_community_posts add constraint "bil_community_posts_title_check" CHECK (((title IS NULL) OR (((char_length(title) >= 1) AND (char_length(title) <= 120)) AND (title !~ '[[:cntrl:]]'::text) AND (title = btrim(title)))));
alter table public.bil_community_posts add constraint "bil_community_posts_visibility_check" CHECK ((visibility = ANY (ARRAY['friends'::text, 'community'::text])));
alter table public.bil_public_profiles add constraint "bil_public_profiles_allow_messages_from_check" CHECK ((allow_messages_from = ANY (ARRAY['friends'::text, 'nobody'::text])));
alter table public.bil_public_profiles add constraint "bil_public_profiles_bio_check" CHECK ((length(bio) <= 280));
alter table public.bil_public_profiles add constraint "bil_public_profiles_country_code_check" CHECK (((country_code IS NULL) OR (country_code ~ '^[A-Z]{2}$'::text)));
alter table public.bil_public_profiles add constraint "bil_public_profiles_cover_object_path_check" CHECK (((cover_object_path IS NULL) OR ((cover_object_path ~~ ((user_id)::text || '/community-cover/%'::text)) AND (cover_object_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/community-cover/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'::text))));
alter table public.bil_public_profiles add constraint "bil_public_profiles_display_name_check" CHECK (((length(display_name) >= 2) AND (length(display_name) <= 60)));
alter table public.bil_public_profiles add constraint "bil_public_profiles_locale_code_check" CHECK ((locale_code = ANY (ARRAY['ar'::text, 'en'::text, 'fr'::text, 'es'::text, 'tr'::text, 'de'::text, 'it'::text, 'pt-BR'::text, 'pt-PT'::text, 'ur'::text, 'fa'::text, 'hi'::text, 'id'::text, 'ms'::text, 'ja'::text, 'ko'::text, 'zh-Hans'::text, 'zh-Hant'::text, 'ru'::text, 'bn'::text, 'vi'::text, 'th'::text, 'pl'::text, 'nl'::text, 'uk'::text])));
alter table public.bil_public_profiles add constraint "bil_public_profiles_pkey" PRIMARY KEY (user_id);
alter table public.bil_public_profiles add constraint "bil_public_profiles_profile_visibility_check" CHECK ((profile_visibility = ANY (ARRAY['public'::text, 'friends'::text, 'private'::text])));
alter table public.bil_public_profiles add constraint "bil_public_profiles_visibility_check" CHECK ((profile_visibility = ANY (ARRAY['public'::text, 'friends'::text, 'private'::text])));
alter table public.bil_push_outbox add constraint "bil_push_outbox_category_check" CHECK ((category = ANY (ARRAY['friend_request'::text, 'message'::text, 'community'::text, 'account'::text, 'ai_coach'::text])));
alter table public.bil_push_outbox add constraint "bil_push_outbox_check" CHECK (((length(title) <= 80) AND (length(body) <= 180)));
alter table public.bil_push_outbox add constraint "bil_push_outbox_copy_key_check" CHECK (((copy_key IS NULL) OR ((char_length(copy_key) >= 3) AND (char_length(copy_key) <= 80))));
alter table public.bil_push_outbox add constraint "bil_push_outbox_deep_link_check" CHECK (((deep_link IS NULL) OR (deep_link ~ '^bil://(community|settings)(/|$)'::text)));
alter table public.bil_push_outbox add constraint "bil_push_outbox_pkey" PRIMARY KEY (id);
alter table public.bil_push_outbox add constraint "bil_push_outbox_source_key_check" CHECK (((source_key IS NULL) OR ((char_length(source_key) >= 16) AND (char_length(source_key) <= 128))));
alter table private.bil_ai_coach_admins add constraint "bil_ai_coach_admins_granted_by_fkey" FOREIGN KEY (granted_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table private.bil_ai_coach_admins add constraint "bil_ai_coach_admins_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table private.bil_community_member_access add constraint "bil_community_member_access_reinstated_by_fkey" FOREIGN KEY (reinstated_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table private.bil_community_member_access add constraint "bil_community_member_access_suspended_by_fkey" FOREIGN KEY (suspended_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table private.bil_community_member_access add constraint "bil_community_member_access_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table private.bil_community_post_events_v1 add constraint "bil_community_post_events_v1_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_ai_credit_balances add constraint "bil_ai_credit_balances_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_blocks add constraint "bil_blocks_blocked_id_fkey" FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_blocks add constraint "bil_blocks_blocker_id_fkey" FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_community_audit_events add constraint "bil_community_audit_events_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.bil_community_moderators add constraint "bil_community_moderators_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_community_notifications add constraint "bil_community_notifications_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.bil_community_notifications add constraint "bil_community_notifications_friendship_id_fkey" FOREIGN KEY (friendship_id) REFERENCES bil_friendships(id) ON DELETE SET NULL;
alter table public.bil_community_notifications add constraint "bil_community_notifications_recipient_id_fkey" FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_community_poll_options add constraint "bil_community_poll_options_post_id_fkey" FOREIGN KEY (post_id) REFERENCES bil_community_polls(post_id) ON DELETE CASCADE;
alter table public.bil_community_polls add constraint "bil_community_polls_post_id_fkey" FOREIGN KEY (post_id) REFERENCES bil_community_posts(id) ON DELETE CASCADE;
alter table public.bil_community_post_approval_grants add constraint "bil_community_post_approval_grants_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.bil_community_post_approval_grants add constraint "bil_community_post_approval_grants_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_community_post_media_v1 add constraint "bil_community_post_media_v1_post_id_fkey" FOREIGN KEY (post_id) REFERENCES bil_community_posts(id) ON DELETE CASCADE;
alter table public.bil_community_post_reward_usage add constraint "bil_community_post_reward_usage_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_community_posts add constraint "bil_community_posts_author_id_fkey" FOREIGN KEY (author_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_public_profiles add constraint "bil_public_profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_push_outbox add constraint "bil_push_outbox_recipient_id_fkey" FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table private.bil_ai_coach_admins enable row level security;
revoke all on table private.bil_ai_coach_admins from public,anon,authenticated,service_role;
alter table private.bil_community_member_access enable row level security;
revoke all on table private.bil_community_member_access from public,anon,authenticated,service_role;
alter table private.bil_community_post_events_v1 enable row level security;
revoke all on table private.bil_community_post_events_v1 from public,anon,authenticated,service_role;
alter table public.bil_ai_credit_balances enable row level security;
revoke all on table public.bil_ai_credit_balances from public,anon,authenticated,service_role;
alter table public.bil_blocks enable row level security;
revoke all on table public.bil_blocks from public,anon,authenticated,service_role;
alter table public.bil_community_audit_events enable row level security;
revoke all on table public.bil_community_audit_events from public,anon,authenticated,service_role;
alter table public.bil_community_moderators enable row level security;
revoke all on table public.bil_community_moderators from public,anon,authenticated,service_role;
alter table public.bil_community_notifications enable row level security;
revoke all on table public.bil_community_notifications from public,anon,authenticated,service_role;
alter table public.bil_community_poll_options enable row level security;
revoke all on table public.bil_community_poll_options from public,anon,authenticated,service_role;
alter table public.bil_community_polls enable row level security;
revoke all on table public.bil_community_polls from public,anon,authenticated,service_role;
alter table public.bil_community_post_approval_grants enable row level security;
revoke all on table public.bil_community_post_approval_grants from public,anon,authenticated,service_role;
alter table public.bil_community_post_media_v1 enable row level security;
revoke all on table public.bil_community_post_media_v1 from public,anon,authenticated,service_role;
alter table public.bil_community_post_reward_policy enable row level security;
revoke all on table public.bil_community_post_reward_policy from public,anon,authenticated,service_role;
alter table public.bil_community_post_reward_usage enable row level security;
revoke all on table public.bil_community_post_reward_usage from public,anon,authenticated,service_role;
alter table public.bil_community_posts enable row level security;
revoke all on table public.bil_community_posts from public,anon,authenticated,service_role;
alter table public.bil_public_profiles enable row level security;
revoke all on table public.bil_public_profiles from public,anon,authenticated,service_role;
alter table public.bil_push_outbox enable row level security;
revoke all on table public.bil_push_outbox from public,anon,authenticated,service_role;
alter table public.bil_friendships enable row level security;
revoke all on table public.bil_friendships from public,anon,authenticated,service_role;
CREATE UNIQUE INDEX bil_push_outbox_recipient_source_uidx ON public.bil_push_outbox USING btree (recipient_id, source_key) WHERE (source_key IS NOT NULL);
