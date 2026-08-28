create table if not exists public.bil_play_integrity_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_id text not null,
  action text not null,
  request_hash text not null,
  mode text not null default 'observe' check (mode in ('observe','enforce')),
  request_package_name text,
  request_timestamp timestamptz,
  app_licensing_verdict text,
  app_recognition_verdict text,
  device_recognition_verdict text[] not null default '{}',
  decision text not null check (decision in ('observe_allow','enforce_allow','enforce_deny','decode_error')),
  reason text not null,
  created_at timestamptz not null default now(),
  constraint bil_play_integrity_request_id_len check (char_length(request_id) between 8 and 128),
  constraint bil_play_integrity_action_len check (char_length(action) between 2 and 80),
  constraint bil_play_integrity_request_hash_len check (octet_length(request_hash) between 1 and 500),
  unique(owner_id, request_id)
);

alter table public.bil_play_integrity_events enable row level security;

create index if not exists bil_play_integrity_events_owner_created_idx
  on public.bil_play_integrity_events(owner_id, created_at desc);

create index if not exists bil_play_integrity_events_decision_created_idx
  on public.bil_play_integrity_events(decision, created_at desc);

comment on table public.bil_play_integrity_events is
  'Server-written Play Integrity verdict audit. Raw integrity tokens are intentionally never stored.';;
