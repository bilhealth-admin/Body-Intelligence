-- The trigger runs as invoker. Authenticated writers need to execute the
-- deterministic text-only classifier used by that trigger.
begin;
grant execute on function public.bil_community_contact_exchange_violation(text)
  to authenticated, service_role;
commit;
