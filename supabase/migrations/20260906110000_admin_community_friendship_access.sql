begin;

-- The protected owner/administrator uses Community as an ordinary member for
-- operational testing. Keep the Premium gate for customers, but do not make
-- the owner purchase an entitlement merely to send or accept a friend link.
create or replace function public.bil_require_premium_friendship()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.requester_id <> auth.uid()
       or (
         not public.bil_has_active_premium(new.requester_id)
         and not exists (
           select 1
           from private.bil_ai_coach_admins administrator
           where administrator.user_id = new.requester_id
             and administrator.active
         )
       ) then
      raise exception 'premium_required' using errcode = 'P0001';
    end if;
  elsif tg_op = 'UPDATE'
        and old.status = 'pending'
        and new.status = 'accepted' then
    if new.addressee_id <> auth.uid()
       or (
         not public.bil_has_active_premium(new.addressee_id)
         and not exists (
           select 1
           from private.bil_ai_coach_admins administrator
           where administrator.user_id = new.addressee_id
             and administrator.active
         )
       ) then
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
