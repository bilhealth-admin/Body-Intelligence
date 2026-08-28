alter table public.bil_play_integrity_events
  drop constraint if exists bil_play_integrity_events_action_length_check;

alter table public.bil_play_integrity_events
  add constraint bil_play_integrity_events_action_length_check
  check (char_length(action) between 2 and 80);;
