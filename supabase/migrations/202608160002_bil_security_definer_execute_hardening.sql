begin;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Remove that
-- default for future functions created by the migration owner.
alter default privileges in schema public
  revoke execute on functions from public;

-- Remove inherited anonymous execution from every current SECURITY DEFINER
-- function. Existing explicit authenticated grants remain intact. The trusted
-- service role receives an explicit grant so Edge Functions do not depend on
-- PUBLIC privileges.
do $$
declare
  target record;
begin
  for target in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
  loop
    execute format(
      'revoke all on function %s from public, anon',
      target.signature
    );
    execute format(
      'grant execute on function %s to service_role',
      target.signature
    );
  end loop;
end;
$$;

-- This helper is called both by authenticated RPCs and receipt-verification
-- Edge Functions. Its body still validates auth.uid()/service-side inputs.
grant execute on function public.bil_consume_rate_limit(text, integer, integer)
  to authenticated, service_role;

commit;
