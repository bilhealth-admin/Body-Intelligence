-- Read-only catalog slice, 2026-10-11. No real user rows.
create schema bil_admin_private;
create table bil_admin_private."subscription_grants" (
  "id" uuid default gen_random_uuid() not null,
  "owner_id" uuid not null,
  "plan_id" text not null,
  "created_at" timestamp with time zone default now() not null,
  "expires_at" timestamp with time zone,
  "granted_by" uuid,
  "reason" text default ''::text not null,
  "revoked_at" timestamp with time zone,
  "revoked_by" uuid
);
create table bil_admin_private."subscription_commands" (
  "id" uuid default gen_random_uuid() not null,
  "actor_id" uuid,
  "idempotency_key" text not null,
  "payload" jsonb not null,
  "result" jsonb not null,
  "created_at" timestamp with time zone default now() not null
);
alter table bil_admin_private."subscription_commands" add constraint "subscription_commands_actor_id_idempotency_key_key" UNIQUE (actor_id, idempotency_key);
alter table bil_admin_private."subscription_commands" add constraint "subscription_commands_idempotency_key_check" CHECK ((idempotency_key ~ '^[A-Za-z0-9:_-]{16,128}$'::text));
alter table bil_admin_private."subscription_commands" add constraint "subscription_commands_pkey" PRIMARY KEY (id);
alter table bil_admin_private."subscription_grants" add constraint "subscription_grants_check" CHECK (((expires_at IS NULL) OR (expires_at > created_at)));
alter table bil_admin_private."subscription_grants" add constraint "subscription_grants_pkey" PRIMARY KEY (id);
alter table bil_admin_private."subscription_grants" add constraint "subscription_grants_plan_id_check" CHECK ((plan_id = ANY (ARRAY['premium'::text, 'premium_ai_coach'::text])));
alter table bil_admin_private."subscription_grants" add constraint "subscription_grants_reason_check" CHECK ((char_length(reason) <= 160));
alter table bil_admin_private."subscription_commands" add constraint "subscription_commands_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table bil_admin_private."subscription_grants" add constraint "subscription_grants_granted_by_fkey" FOREIGN KEY (granted_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table bil_admin_private."subscription_grants" add constraint "subscription_grants_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table bil_admin_private."subscription_grants" add constraint "subscription_grants_revoked_by_fkey" FOREIGN KEY (revoked_by) REFERENCES auth.users(id) ON DELETE SET NULL;
CREATE UNIQUE INDEX subscription_grants_one_current_owner ON bil_admin_private.subscription_grants USING btree (owner_id) WHERE (revoked_at IS NULL);
CREATE INDEX subscription_grants_owner_history ON bil_admin_private.subscription_grants USING btree (owner_id, created_at DESC);
CREATE INDEX subscription_grants_created ON bil_admin_private.subscription_grants USING btree (created_at DESC, id DESC);
CREATE INDEX subscription_grants_granted_by ON bil_admin_private.subscription_grants USING btree (granted_by);
CREATE INDEX subscription_grants_revoked_by ON bil_admin_private.subscription_grants USING btree (revoked_by);
alter table bil_admin_private.subscription_grants enable row level security;
alter table bil_admin_private.subscription_commands enable row level security;
revoke all on schema bil_admin_private from public,anon,authenticated;
grant usage on schema bil_admin_private to service_role;
revoke all on all tables in schema bil_admin_private from public,anon,authenticated,service_role;
