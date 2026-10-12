-- Actual deployed store-subscription columns; synthetic rows only.
-- Product registry is not exercised by this fixture; its FK is verified by catalog, not emulated.
create table public.bil_subscriptions (
  "owner_id" uuid not null,
  "provider" text not null,
  "product_id" text not null,
  "plan_id" text not null,
  "lifecycle" text not null,
  "original_transaction_id" text not null,
  "latest_transaction_id" text not null,
  "environment" text not null,
  "started_at" timestamp with time zone,
  "expires_at" timestamp with time zone,
  "grace_period_ends_at" timestamp with time zone,
  "auto_renews" boolean,
  "verified_at" timestamp with time zone not null,
  "revision" bigint default 1 not null,
  "store_country_code" text,
  "store_signed_at" timestamp with time zone
);
alter table public.bil_subscriptions add constraint "bil_subscriptions_environment_check" CHECK ((environment = ANY (ARRAY['sandbox'::text, 'production'::text])));
alter table public.bil_subscriptions add constraint "bil_subscriptions_lifecycle_check" CHECK ((lifecycle = ANY (ARRAY['pending'::text, 'trial'::text, 'active'::text, 'grace_period'::text, 'billing_retry'::text, 'account_hold'::text, 'paused'::text, 'suspended'::text, 'deferred'::text, 'cancelled'::text, 'expired'::text, 'refunded'::text, 'revoked'::text])));
alter table public.bil_subscriptions add constraint "bil_subscriptions_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_subscriptions add constraint "bil_subscriptions_pkey" PRIMARY KEY (owner_id);
alter table public.bil_subscriptions add constraint "bil_subscriptions_plan_id_check" CHECK ((plan_id = ANY (ARRAY['premium'::text, 'premium_ai_coach'::text, 'legacy_plus'::text])));
alter table public.bil_subscriptions add constraint "bil_subscriptions_provider_check" CHECK ((provider = ANY (ARRAY['google'::text, 'apple'::text, 'closed_test'::text])));
alter table public.bil_subscriptions add constraint "bil_subscriptions_provider_original_transaction_id_key" UNIQUE (provider, original_transaction_id);
alter table public.bil_subscriptions add constraint "bil_subscriptions_store_country_code_check" CHECK (((store_country_code IS NULL) OR (store_country_code ~ '^[A-Z]{2,3}$'::text)));
alter table public.bil_subscriptions add constraint "bil_subscriptions_store_signed_at_check" CHECK (((store_signed_at IS NULL) OR (isfinite(store_signed_at) AND (store_signed_at > '1970-01-01 00:00:00+00'::timestamp with time zone))));
