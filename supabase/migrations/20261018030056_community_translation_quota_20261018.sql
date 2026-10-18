-- Dedicated fixed quota; existing rate contracts, RLS and grants stay intact.
create or replace function public.bil_consume_community_translation_quota()
returns void language plpgsql security definer set search_path = '' as $function$
declare
  owner uuid := (select auth.uid());
  bucket record;
  hits integer;
  started timestamptz;
begin
  if owner is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  for bucket in select * from (values
    ('community_translation_minute', 10, 60),
    ('community_translation_hour', 60, 3600)
  ) as quotas(action_name, maximum, seconds) loop
    started := pg_catalog.to_timestamp(pg_catalog.floor(extract(epoch from pg_catalog.statement_timestamp()) / bucket.seconds) * bucket.seconds);
    insert into public.bil_rate_limit_buckets(user_id, action, window_started_at, hit_count)
      values (owner, bucket.action_name, started, 1)
      on conflict (user_id, action, window_started_at) do update
      set hit_count = bil_rate_limit_buckets.hit_count + 1 returning hit_count into hits;
    if hits > bucket.maximum then raise exception 'rate limit exceeded' using errcode = 'P0001'; end if;
  end loop;
end
$function$;
revoke all on function public.bil_consume_community_translation_quota() from public, anon;
grant execute on function public.bil_consume_community_translation_quota() to authenticated;
