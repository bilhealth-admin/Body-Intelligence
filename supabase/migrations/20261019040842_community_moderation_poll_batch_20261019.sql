-- Moderator-only review of poll text/options, including pending posts.
-- Ordinary feed visibility and table grants remain unchanged.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

CREATE OR REPLACE FUNCTION public.bil_community_moderation_polls_v1(p_post_ids uuid[])
 RETURNS TABLE(post_id uuid, poll jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_uid) is null then
    raise exception 'community_moderator_required' using errcode='42501';
  end if;
  if p_post_ids is null
     or cardinality(p_post_ids)<1
     or cardinality(p_post_ids)>100
     or cardinality(p_post_ids)<>(
       select count(distinct value) from unnest(p_post_ids) value
     ) then
    raise exception 'invalid_community_poll_batch' using errcode='22023';
  end if;

  return query
  select
    p.post_id,
    pg_catalog.jsonb_build_object(
      'post_id',p.post_id,
      'question',p.question,
      'allow_multiple',p.allow_multiple,
      'closes_at',p.closes_at,
      'closed',
        p.closes_at is not null
        and p.closes_at<=pg_catalog.clock_timestamp(),
      'total_votes',(
        select count(*)::integer
        from public.bil_community_poll_votes v
        where v.post_id=p.post_id
      ),
      'options',coalesce((
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'id',o.id,
            'position',o.position,
            'text',o.option_text,
            'vote_count',(
              select count(*)::integer
              from public.bil_community_poll_votes v
              where v.option_id=o.id
            ),
            'selected',exists(
              select 1
              from public.bil_community_poll_votes v
              where v.option_id=o.id
                and v.voter_id=v_uid
            )
          )
          order by o.position
        )
        from public.bil_community_poll_options o
        where o.post_id=p.post_id
      ),'[]'::jsonb)
    )
  from public.bil_community_polls p
  join public.bil_community_posts post on post.id=p.post_id
  where p.post_id=any(p_post_ids)
    and post.deleted_at is null
  order by p.post_id;
end
$function$
;

revoke all on function public.bil_community_moderation_polls_v1(uuid[]) from public,anon,service_role;
grant execute on function public.bil_community_moderation_polls_v1(uuid[]) to authenticated;
commit;
