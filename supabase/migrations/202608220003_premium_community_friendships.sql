begin;

-- Premium community relationships are authorized by server-owned commerce
-- truth. Existing friendships remain readable/manageable after expiry so a
-- member can always message, remove, or block safely; only creating a new
-- request and accepting it require current Premium access.
create or replace function public.bil_has_active_premium(p_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_owner_id is not null and (
    exists (
      select 1
      from public.bil_entitlements e
      where e.owner_id = p_owner_id
        and e.entitlement_id in (
          'plan:premium',
          'plan:premium_ai_coach',
          'plan:legacy_plus'
        )
        and e.active = true
        and (e.expires_at is null or e.expires_at > now())
    )
    or exists (
      select 1
      from public.bil_subscriptions s
      where s.owner_id = p_owner_id
        and s.plan_id in ('premium', 'premium_ai_coach', 'legacy_plus')
        and s.lifecycle in ('trial', 'active', 'grace_period')
        and (
          coalesce(s.grace_period_ends_at, s.expires_at) is null
          or coalesce(s.grace_period_ends_at, s.expires_at) > now()
        )
    )
  );
$$;

revoke all on function public.bil_has_active_premium(uuid)
from public, anon, authenticated;

create or replace function public.bil_require_premium_friendship()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.requester_id <> auth.uid()
       or not public.bil_has_active_premium(new.requester_id) then
      raise exception 'premium_required' using errcode = 'P0001';
    end if;
  elsif tg_op = 'UPDATE'
        and old.status = 'pending'
        and new.status = 'accepted' then
    if new.addressee_id <> auth.uid()
       or not public.bil_has_active_premium(new.addressee_id) then
      raise exception 'premium_required' using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.bil_require_premium_friendship()
from public, anon, authenticated;

drop trigger if exists bil_friendships_require_premium
  on public.bil_friendships;
create trigger bil_friendships_require_premium
before insert or update of status on public.bil_friendships
for each row execute function public.bil_require_premium_friendship();

commit;
