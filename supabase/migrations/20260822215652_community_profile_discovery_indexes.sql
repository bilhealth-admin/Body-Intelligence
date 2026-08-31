create index if not exists bil_blocks_blocked_id_idx
  on public.bil_blocks (blocked_id, blocker_id);

create index if not exists bil_public_profiles_discoverable_name_idx
  on public.bil_public_profiles (display_name, user_id)
  where discoverable = true and allow_friend_requests = true;;
