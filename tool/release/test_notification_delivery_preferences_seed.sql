-- LOCAL-ONLY PostgreSQL17 dependency schema matches read-only LIVE columns,
-- constraints, indexes and RPC ACLs. auth.users is an ID-only dependency subset;
-- auth.uid() is the exact LIVE subject reader, not a JWT/Auth-service test.
begin;
set local statement_timeout='20s';
do $roles$
begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
  if exists(select 1 from pg_roles where rolname in ('anon','authenticated','service_role')
    and (rolsuper or rolbypassrls)) then raise exception 'fixture requires non-bypass roles'; end if;
end
$roles$;
create schema auth;
create schema private;
create schema extensions;
create extension pgcrypto with schema extensions;
grant usage on schema public,auth to anon,authenticated,service_role;
create table auth.users(id uuid primary key);
revoke all on auth.users from public,anon,authenticated,service_role;
create table public.bil_push_device_tokens (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  token_ciphertext text not null,
  token_fingerprint text not null,
  platform text not null,
  timezone text default 'UTC'::text not null,
  enabled boolean default true not null,
  sensitive_preview_allowed boolean default false not null,
  last_seen_at timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null,
  message_enabled boolean default true not null,
  friend_request_enabled boolean default true not null,
  friend_accepted_enabled boolean default true not null,
  PRIMARY KEY (id),
  CHECK ((platform = ANY (ARRAY['fcm'::text, 'apns'::text]))),
  UNIQUE (token_fingerprint),
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
alter table public.bil_push_device_tokens enable row level security;
revoke all on public.bil_push_device_tokens from public,anon,authenticated,service_role;
CREATE INDEX bil_idx_push_tokens_user ON public.bil_push_device_tokens USING btree (user_id);

create table public.bil_push_outbox (
  id uuid default gen_random_uuid() not null,
  recipient_id uuid not null,
  category text not null,
  title text default 'BIL'::text not null,
  body text default 'You have a new update.'::text not null,
  deep_link text,
  created_at timestamp with time zone default now() not null,
  dispatched_at timestamp with time zone,
  failure_code text,
  copy_key text,
  source_key text,
  CHECK ((category = ANY (ARRAY['friend_request'::text, 'message'::text, 'community'::text, 'account'::text, 'ai_coach'::text]))),
  CHECK (((length(title) <= 80) AND (length(body) <= 180))),
  CHECK (((copy_key IS NULL) OR ((char_length(copy_key) >= 3) AND (char_length(copy_key) <= 80)))),
  CHECK (((deep_link IS NULL) OR (deep_link ~ '^bil://(community|settings)(/|$)'::text))),
  PRIMARY KEY (id),
  FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CHECK (((source_key IS NULL) OR ((char_length(source_key) >= 16) AND (char_length(source_key) <= 128))))
);
alter table public.bil_push_outbox enable row level security;
revoke all on public.bil_push_outbox from public,anon,authenticated,service_role;


create table public.bil_push_delivery_policy (
  singleton boolean default true not null,
  max_attempts integer default 5 not null,
  base_backoff_seconds integer default 30 not null,
  max_backoff_seconds integer default 3600 not null,
  updated_at timestamp with time zone default now() not null,
  CHECK (((base_backoff_seconds >= 15) AND (base_backoff_seconds <= 3600))),
  CHECK (((max_backoff_seconds >= base_backoff_seconds) AND (max_backoff_seconds <= 86400))),
  CHECK (((max_attempts >= 1) AND (max_attempts <= 20))),
  PRIMARY KEY (singleton),
  CHECK (singleton)
);
alter table public.bil_push_delivery_policy enable row level security;
revoke all on public.bil_push_delivery_policy from public,anon,authenticated,service_role;


create table public.bil_push_delivery_attempts (
  outbox_id uuid not null,
  device_token_id uuid not null,
  attempt_count integer default 0 not null,
  leased_until timestamp with time zone,
  last_attempt_at timestamp with time zone,
  next_attempt_at timestamp with time zone default now() not null,
  delivered_at timestamp with time zone,
  terminal_at timestamp with time zone,
  permanent_token_failure boolean default false not null,
  failure_code text,
  created_at timestamp with time zone default now() not null,
  CHECK ((attempt_count >= 0)),
  CHECK (((delivered_at IS NULL) OR (terminal_at IS NULL))),
  CHECK (((NOT permanent_token_failure) OR (terminal_at IS NOT NULL))),
  FOREIGN KEY (device_token_id) REFERENCES bil_push_device_tokens(id) ON DELETE CASCADE,
  CHECK (((failure_code IS NULL) OR ((char_length(failure_code) >= 1) AND (char_length(failure_code) <= 120)))),
  FOREIGN KEY (outbox_id) REFERENCES bil_push_outbox(id) ON DELETE CASCADE,
  PRIMARY KEY (outbox_id, device_token_id)
);
alter table public.bil_push_delivery_attempts enable row level security;
revoke all on public.bil_push_delivery_attempts from public,anon,authenticated,service_role;
CREATE INDEX bil_push_delivery_attempts_retry_idx ON public.bil_push_delivery_attempts USING btree (outbox_id, next_attempt_at, leased_until) WHERE ((delivered_at IS NULL) AND (terminal_at IS NULL));
CREATE INDEX bil_idx_push_attempt_device ON public.bil_push_delivery_attempts USING btree (device_token_id);

-- EXACT_LIVE_FUNCTION_BASELINE
create function public.qa_push_assert(p_ok boolean,p_message text) returns void
language plpgsql as $assert$
begin
  if p_ok is distinct from true then raise exception 'QA_ASSERTION: %',p_message; end if;
end
$assert$;
grant execute on function public.qa_push_assert(boolean,text) to anon,authenticated,service_role;
insert into auth.users(id) values
('11111111-1111-4111-8111-111111111111'),
('22222222-2222-4222-8222-222222222222'),
('33333333-3333-4333-8333-333333333333'),
('44444444-4444-4444-8444-444444444444');
insert into public.bil_push_delivery_policy(singleton) values(true);
commit;

