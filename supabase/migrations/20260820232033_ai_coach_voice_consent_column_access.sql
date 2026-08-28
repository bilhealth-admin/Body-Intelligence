begin;

-- The voice gate reads only the latest decision and policy version. Limit the
-- Edge service role to the columns required by that bounded query.
grant select (user_id, purpose, granted, policy_version, recorded_at)
  on table public.bil_consent_receipts
  to service_role;

commit;;
