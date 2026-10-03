-- Cover the foreign-key columns introduced by the durable Community
-- notification inbox so user/profile and friendship deletes do not require
-- avoidable sequential scans.
set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_notifications') is null then
    raise exception 'bil_community_notifications_missing';
  end if;
  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='bil_community_notifications'
      and column_name='actor_id'
  ) then
    raise exception 'bil_community_notifications_actor_id_missing';
  end if;
  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='bil_community_notifications'
      and column_name='friendship_id'
  ) then
    raise exception 'bil_community_notifications_friendship_id_missing';
  end if;
end
$$;

create index if not exists bil_community_notifications_actor_id_idx
  on public.bil_community_notifications(actor_id);

create index if not exists bil_community_notifications_friendship_id_idx
  on public.bil_community_notifications(friendship_id);

do $$
begin
  if to_regclass('public.bil_community_notifications_actor_id_idx') is null then
    raise exception 'bil_community_notifications_actor_id_idx_missing';
  end if;
  if to_regclass('public.bil_community_notifications_friendship_id_idx') is null then
    raise exception 'bil_community_notifications_friendship_id_idx_missing';
  end if;
end
$$;
