-- The internal push dispatcher reads pending outbox rows with the Supabase
-- service role, while all state transitions remain inside security-definer RPCs.
grant select on table public.bil_push_outbox to service_role;
