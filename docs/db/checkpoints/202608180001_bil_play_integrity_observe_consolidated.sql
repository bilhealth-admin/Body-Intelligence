-- BIL Play Integrity observe-mode persistence.
-- Idempotent because the production database was updated before this source
-- checkpoint was committed. Safe to run again from Codex/Supabase CLI.

create table if not exists public.bil_play_integrity_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_id text not null,
  action text not null,
  request_hash text not null,
  mode text not null default 'observe',
  request_package_name text,
  request_timestamp timestamptz,
  app_licensing_verdict text,
  app_recognition_verdict text,
  device_recognition_verdict text[] not null default '{}'::text[],
  decision text not null,
  reason text not null,
  created_at timestamptz not null default now(),
  payload_digest text
);

alter table public.bil_play_integrity_events
  add column if not exists payload_digest text;

alter table public.bil_play_integrity_events
  alter column payload_digest set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bil_play_integrity_events'::regclass
      and conname = 'bil_play_integrity_events_owner_id_request_id_key'
  ) then
    alter table public.bil_play_integrity_events
      add constraint bil_play_integrity_events_owner_id_request_id_key
      unique (owner_id, request_id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bil_play_integrity_events'::regclass
      and conname = 'bil_play_integrity_request_id_len'
  ) then
    alter table public.bil_play_integrity_events
      add constraint bil_play_integrity_request_id_len
      check (char_length(request_id) between 8 and 128);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bil_play_integrity_events'::regclass
      and conname = 'bil_play_integrity_events_action_length_check'
  ) then
    alter table public.bil_play_integrity_events
      add constraint bil_play_integrity_events_action_length_check
      check (char_length(action) between 2 and 80);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bil_play_integrity_events'::regclass
      and conname = 'bil_play_integrity_request_hash_len'
  ) then
    alter table public.bil_play_integrity_events
      add constraint bil_play_integrity_request_hash_len
      check (octet_length(request_hash) between 1 and 500);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bil_play_integrity_events'::regclass
      and conname = 'bil_play_integrity_events_mode_check'
  ) then
    alter table public.bil_play_integrity_events
      add constraint bil_play_integrity_events_mode_check
      check (mode = any (array['observe'::text, 'enforce'::text]));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bil_play_integrity_events'::regclass
      and conname = 'bil_play_integrity_events_decision_check'
  ) then
    alter table public.bil_play_integrity_events
      add constraint bil_play_integrity_events_decision_check
      check (
        decision = any (
          array[
            'observe_allow'::text,
            'enforce_allow'::text,
            'enforce_deny'::text,
            'decode_error'::text
          ]
        )
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bil_play_integrity_events'::regclass
      and conname = 'bil_play_integrity_events_payload_digest_check'
  ) then
    alter table public.bil_play_integrity_events
      add constraint bil_play_integrity_events_payload_digest_check
      check (payload_digest ~ '^[0-9a-f]{64}$'::text);
  end if;
end
$$;

alter table public.bil_play_integrity_events
  drop constraint if exists bil_play_integrity_action_len;

create index if not exists bil_play_integrity_events_created_at_idx
  on public.bil_play_integrity_events (created_at desc);

create index if not exists bil_play_integrity_events_owner_created_idx
  on public.bil_play_integrity_events (owner_id, created_at desc);

create index if not exists bil_play_integrity_events_decision_created_idx
  on public.bil_play_integrity_events (decision, created_at desc);

alter table public.bil_play_integrity_events enable row level security;

-- Intentionally no client RLS policies. The Edge Function writes with the
-- server-side service role after independently authenticating the BIL user.