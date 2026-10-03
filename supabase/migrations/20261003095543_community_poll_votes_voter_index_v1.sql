set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_poll_votes') is null then
    raise exception 'community_poll_votes_missing';
  end if;
end
$$;

create index if not exists bil_community_poll_votes_voter_idx
  on public.bil_community_poll_votes(voter_id,created_at desc,post_id);

do $$
begin
  if not exists(
    select 1
    from pg_indexes
    where schemaname='public'
      and tablename='bil_community_poll_votes'
      and indexname='bil_community_poll_votes_voter_idx'
  ) then
    raise exception 'community_poll_votes_voter_index_missing';
  end if;
end
$$;
