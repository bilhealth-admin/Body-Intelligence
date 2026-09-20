-- Bound the legacy authenticated rate-limit RPC to the exact action/limit/
-- window tuples used by reviewed database functions and Edge Functions. The
-- old body accepted arbitrary action strings, allowing an authenticated user
-- to amplify writes by creating unbounded bucket keys. Existing buckets,
-- callers, grants, RLS, and business data are preserved.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $rate_limit_contract_preflight$
declare
  v_function oid :=
    'public.bil_consume_rate_limit(text,integer,integer)'::regprocedure;
begin
  if pg_catalog.to_regclass('public.bil_rate_limit_buckets') is null
     or v_function is null then
    raise exception 'rate_limit_contract_precondition_failed'
      using errcode = '55000',
            detail = 'The reviewed rate-limit table or RPC is missing.';
  end if;

  if not (
       select procedure.prosecdef
       from pg_catalog.pg_proc procedure
       where procedure.oid = v_function
     )
     or (
       select procedure.provolatile <> 'v'
       from pg_catalog.pg_proc procedure
       where procedure.oid = v_function
     )
     or (
       select pg_catalog.pg_get_userbyid(procedure.proowner) <> 'postgres'
       from pg_catalog.pg_proc procedure
       where procedure.oid = v_function
     ) then
    raise exception 'rate_limit_contract_precondition_failed'
      using errcode = '55000',
            detail = 'The live rate-limit RPC no longer matches its reviewed owner/security boundary.';
  end if;

  if exists (
    select 1
    from public.bil_rate_limit_buckets bucket
    where not exists (
      select 1
      from (
        values
          ('account_deletion', 3, 3600),
          ('account_deletion', 3, 86400),
          ('account_export', 3, 3600),
          ('ai_boost_purchase_verification', 20, 3600),
          ('app_attest_issue', 60, 3600),
          ('admin_ai_coach_global_reset', 3, 3600),
          ('admin_ai_coach_individual_reset', 20, 3600),
          ('admin_community_member_list', 120, 3600),
          ('admin_community_member_reinstate', 30, 3600),
          ('admin_community_member_suspend', 30, 3600),
          ('admin_community_moderator_add', 30, 3600),
          ('admin_community_moderator_list', 120, 3600),
          ('admin_community_moderator_remove', 30, 3600),
          ('admin_notification_all', 10, 3600),
          ('admin_notification_individual', 50, 3600),
          ('community_comment_report_v2', 20, 3600),
          ('community_comment_v2', 60, 3600),
          ('community_handle_claim_v2', 10, 3600),
          ('community_handle_search_v2', 60, 60),
          ('community_like_v2', 120, 60),
          ('community_post_save_v2', 120, 60),
          ('community_public_code_resolve_v2', 60, 60),
          ('community_public_code_rotate_v2', 5, 86400),
          ('follow', 40, 3600),
          ('food_search_hour', 60, 3600),
          ('food_search_minute', 10, 60),
          ('friend_request', 20, 3600),
          ('meal_image_analysis', 30, 3600),
          ('message', 60, 3600),
          ('play_integrity_issue', 60, 3600),
          ('post', 12, 3600),
          ('store_purchase_verification', 20, 3600)
      ) allowed(action_name, limit_count, window_seconds)
      where allowed.action_name = bucket.action
    )
  ) then
    raise exception 'rate_limit_contract_precondition_failed'
      using errcode = '55000',
            detail = 'An existing bucket action is outside the reviewed canonical action set.';
  end if;
end
$rate_limit_contract_preflight$;

create or replace function public.bil_consume_rate_limit(
  p_action text,
  p_limit integer,
  p_window_seconds integer
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_window_started_at timestamp with time zone;
  v_hit_count integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if pg_catalog.octet_length(p_action) not between 1 and 64
     or not exists (
       select 1
       from (
         values
           ('account_deletion', 3, 3600),
           ('account_deletion', 3, 86400),
           ('account_export', 3, 3600),
           ('ai_boost_purchase_verification', 20, 3600),
           ('app_attest_issue', 60, 3600),
           ('admin_ai_coach_global_reset', 3, 3600),
           ('admin_ai_coach_individual_reset', 20, 3600),
           ('admin_community_member_list', 120, 3600),
           ('admin_community_member_reinstate', 30, 3600),
           ('admin_community_member_suspend', 30, 3600),
           ('admin_community_moderator_add', 30, 3600),
           ('admin_community_moderator_list', 120, 3600),
           ('admin_community_moderator_remove', 30, 3600),
           ('admin_notification_all', 10, 3600),
           ('admin_notification_individual', 50, 3600),
           ('community_comment_report_v2', 20, 3600),
           ('community_comment_v2', 60, 3600),
           ('community_handle_claim_v2', 10, 3600),
           ('community_handle_search_v2', 60, 60),
           ('community_like_v2', 120, 60),
           ('community_post_save_v2', 120, 60),
           ('community_public_code_resolve_v2', 60, 60),
           ('community_public_code_rotate_v2', 5, 86400),
           ('follow', 40, 3600),
           ('food_search_hour', 60, 3600),
           ('food_search_minute', 10, 60),
           ('friend_request', 20, 3600),
           ('meal_image_analysis', 30, 3600),
           ('message', 60, 3600),
           ('play_integrity_issue', 60, 3600),
           ('post', 12, 3600),
           ('store_purchase_verification', 20, 3600)
       ) allowed(action_name, limit_count, window_seconds)
       where allowed.action_name = p_action
         and allowed.limit_count = p_limit
         and allowed.window_seconds = p_window_seconds
     ) then
    raise exception 'invalid_rate_limit_contract' using errcode = '22023';
  end if;

  v_window_started_at := pg_catalog.to_timestamp(
    pg_catalog.floor(
      extract(epoch from pg_catalog.statement_timestamp()) /
      p_window_seconds
    ) * p_window_seconds
  );

  insert into public.bil_rate_limit_buckets(
    user_id, action, window_started_at, hit_count
  ) values (
    v_user_id, p_action, v_window_started_at, 1
  )
  on conflict (user_id, action, window_started_at)
  do update
  set hit_count = bil_rate_limit_buckets.hit_count + 1
  returning hit_count into v_hit_count;

  if v_hit_count > p_limit then
    raise exception 'rate limit exceeded' using errcode = 'P0001';
  end if;
end
$function$;

revoke all on function
  public.bil_consume_rate_limit(text, integer, integer)
from public, anon, authenticated, service_role;

grant execute on function
  public.bil_consume_rate_limit(text, integer, integer)
to authenticated, service_role;

do $rate_limit_contract_postconditions$
declare
  v_function regprocedure :=
    'public.bil_consume_rate_limit(text,integer,integer)'::regprocedure;
begin
  if not (
       select procedure.prosecdef
       from pg_catalog.pg_proc procedure
       where procedure.oid = v_function
     )
     or (
       select procedure.provolatile <> 'v'
       from pg_catalog.pg_proc procedure
       where procedure.oid = v_function
     )
     or not exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.unnest(procedure.proconfig)
         configuration(setting)
       where procedure.oid = v_function
         and configuration.setting in ('search_path=', 'search_path=""')
     )
     or not pg_catalog.has_function_privilege(
       'authenticated', v_function, 'EXECUTE'
     )
     or not pg_catalog.has_function_privilege(
       'service_role', v_function, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege('anon', v_function, 'EXECUTE')
     or exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) privilege
       where procedure.oid = v_function
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'rate_limit_contract_postcondition_failed'
      using errcode = '55000',
            detail = 'The hardened rate-limit RPC security or ACL boundary is invalid.';
  end if;
end
$rate_limit_contract_postconditions$;

notify pgrst, 'reload schema';

commit;
