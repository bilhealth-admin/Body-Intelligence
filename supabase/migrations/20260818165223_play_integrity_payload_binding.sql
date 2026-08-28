alter table public.bil_play_integrity_events
  add column if not exists payload_digest text;

alter table public.bil_play_integrity_events
  drop constraint if exists bil_play_integrity_events_payload_digest_check;

alter table public.bil_play_integrity_events
  add constraint bil_play_integrity_events_payload_digest_check
  check (payload_digest is null or payload_digest ~ '^[0-9a-f]{64}$');;
