begin;

-- Meal-photo Vision is part of the shared AI Coach token meter.  Keep the
-- historical function name because the Edge Function already calls it, but
-- delegate to the canonical reservation authority so weekly/included Coach
-- tokens are consumed before non-expiring paid tokens.  This also preserves
-- the existing idempotency, expiry cleanup, monthly cap, and row-lock rules.
create or replace function public.bil_reserve_paid_ai_vision_usage(
  p_owner_id uuid,
  p_request_id text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_owner_id is null
     or length(trim(p_request_id)) not between 16 and 128 then
    raise exception 'invalid_ai_usage_request';
  end if;

  v_result := public.bil_reserve_ai_usage(
    p_owner_id,
    trim(p_request_id),
    'vision',
    1
  );

  return v_result || jsonb_build_object(
    'billing_source', case
      when coalesce((v_result->>'weekly_tokens_reserved')::bigint, 0) > 0
       and coalesce((v_result->>'paid_tokens_reserved')::bigint, 0) > 0
        then 'ai_coach_then_paid_boost'
      when coalesce((v_result->>'weekly_tokens_reserved')::bigint, 0) > 0
        then 'ai_coach'
      else 'paid_boost'
    end
  );
end
$$;

revoke all on function public.bil_reserve_paid_ai_vision_usage(uuid,text)
  from public, anon, authenticated;
grant execute on function public.bil_reserve_paid_ai_vision_usage(uuid,text)
  to service_role;

commit;
