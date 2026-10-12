-- Actual deployed public wrappers; read-only catalog, 2026-10-11.
CREATE OR REPLACE FUNCTION public.bil_get_my_admin_subscription()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select bil_admin_private.my_subscription()
$function$
;
CREATE OR REPLACE FUNCTION public.bil_list_admin_subscriptions(p_actor_id uuid, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select bil_admin_private.list_subscriptions(p_actor_id, p_offset)
$function$
;
CREATE OR REPLACE FUNCTION public.bil_manage_admin_subscription(p_actor_id uuid, p_operation text, p_idempotency_key text, p_email text DEFAULT NULL::text, p_plan_id text DEFAULT NULL::text, p_duration_days integer DEFAULT NULL::integer, p_reason text DEFAULT ''::text, p_grant_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  select bil_admin_private.manage_subscription(p_actor_id, p_operation, p_idempotency_key,
    p_email, p_plan_id, p_duration_days, p_reason, p_grant_id)
$function$
;
revoke all on function public.bil_manage_admin_subscription(uuid,text,text,text,text,integer,text,uuid), public.bil_list_admin_subscriptions(uuid,integer) from public,anon,authenticated;
grant execute on function public.bil_manage_admin_subscription(uuid,text,text,text,text,integer,text,uuid), public.bil_list_admin_subscriptions(uuid,integer) to service_role;
revoke all on function public.bil_get_my_admin_subscription() from public,anon;
grant execute on function public.bil_get_my_admin_subscription() to authenticated;
