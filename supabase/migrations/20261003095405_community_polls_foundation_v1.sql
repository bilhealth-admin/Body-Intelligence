set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null then
    raise exception 'community_poll_post_contract_missing';
  end if;
  if to_regclass('public.bil_community_polls') is not null
     or to_regclass('public.bil_community_poll_options') is not null
     or to_regclass('public.bil_community_poll_votes') is not null then
    raise exception 'community_polls_v1_already_exists';
  end if;
end
$$;

create table public.bil_community_polls (
  post_id uuid primary key references public.bil_community_posts(id) on delete cascade,
  question text not null
    check (
      char_length(question) between 1 and 200
      and question=btrim(question)
    ),
  allow_multiple boolean not null default false,
  closes_at timestamptz,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  check (closes_at is null or closes_at>created_at)
);

create table public.bil_community_poll_options (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.bil_community_polls(post_id) on delete cascade,
  position integer not null check (position between 0 and 5),
  option_text text not null
    check (
      char_length(option_text) between 1 and 100
      and option_text=btrim(option_text)
    ),
  unique(post_id,position),
  unique(post_id,id)
);

create table public.bil_community_poll_votes (
  post_id uuid not null,
  option_id uuid not null,
  voter_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(post_id,option_id,voter_id),
  foreign key(post_id,option_id)
    references public.bil_community_poll_options(post_id,id)
    on delete cascade
);

create index bil_community_poll_votes_post_voter_idx
  on public.bil_community_poll_votes(post_id,voter_id,created_at desc);
create index bil_community_poll_votes_option_idx
  on public.bil_community_poll_votes(option_id,created_at desc,voter_id);

alter table public.bil_community_polls enable row level security;
alter table public.bil_community_poll_options enable row level security;
alter table public.bil_community_poll_votes enable row level security;

revoke all on table public.bil_community_polls
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_poll_options
  from public,anon,authenticated,service_role;
revoke all on table public.bil_community_poll_votes
  from public,anon,authenticated,service_role;

create or replace function public.bil_create_my_community_poll_v1(
  p_post_id uuid,
  p_question text,
  p_options text[],
  p_allow_multiple boolean default false,
  p_closes_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_question text;
  v_option text;
  v_index integer:=0;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null
     or p_question is null
     or p_options is null
     or p_allow_multiple is null
     or cardinality(p_options)<2
     or cardinality(p_options)>6
     or p_closes_at is not null
        and p_closes_at<=pg_catalog.clock_timestamp() then
    raise exception 'invalid_community_poll' using errcode='22023';
  end if;

  v_question:=btrim(p_question);
  if char_length(v_question) not between 1 and 200 then
    raise exception 'invalid_community_poll_question' using errcode='22023';
  end if;

  if not exists(
    select 1
    from public.bil_community_posts p
    where p.id=p_post_id
      and p.author_id=v_uid
      and p.deleted_at is null
      and p.moderation_status='pending'
  ) then
    raise exception 'community_poll_post_not_editable' using errcode='42501';
  end if;

  if exists(
    select 1 from public.bil_community_polls p where p.post_id=p_post_id
  ) then
    raise exception 'community_poll_already_exists' using errcode='23505';
  end if;

  if exists(
    select 1
    from (
      select lower(btrim(value)) as normalized
      from unnest(p_options) value
    ) normalized
    group by normalized.normalized
    having count(*)>1
  ) then
    raise exception 'community_poll_options_duplicate' using errcode='22023';
  end if;

  if exists(
    select 1 from unnest(p_options) value
    where value is null
       or char_length(btrim(value)) not between 1 and 100
  ) then
    raise exception 'community_poll_option_invalid' using errcode='22023';
  end if;

  insert into public.bil_community_polls(
    post_id,question,allow_multiple,closes_at
  )
  values(
    p_post_id,v_question,p_allow_multiple,p_closes_at
  );

  foreach v_option in array p_options loop
    insert into public.bil_community_poll_options(
      post_id,position,option_text
    )
    values(p_post_id,v_index,btrim(v_option));
    v_index:=v_index+1;
  end loop;

  return p_post_id;
end
$$;

create or replace function public.bil_vote_community_poll_v1(
  p_post_id uuid,
  p_option_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_poll public.bil_community_polls%rowtype;
  v_count integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null
     or p_option_ids is null
     or cardinality(p_option_ids)<1
     or cardinality(p_option_ids)>6
     or cardinality(p_option_ids)<>(
       select count(distinct value) from unnest(p_option_ids) value
     ) then
    raise exception 'invalid_community_poll_vote' using errcode='22023';
  end if;

  select * into v_poll
  from public.bil_community_polls p
  where p.post_id=p_post_id
  for share;

  if not found
     or not public.bil_social_post_visible_v2(p_post_id) then
    raise exception 'community_poll_unavailable' using errcode='42501';
  end if;
  if v_poll.closes_at is not null
     and v_poll.closes_at<=pg_catalog.clock_timestamp() then
    raise exception 'community_poll_closed' using errcode='22023';
  end if;
  if not v_poll.allow_multiple and cardinality(p_option_ids)<>1 then
    raise exception 'community_poll_single_choice' using errcode='22023';
  end if;

  select count(*)::integer into v_count
  from public.bil_community_poll_options o
  where o.post_id=p_post_id
    and o.id=any(p_option_ids);
  if v_count<>cardinality(p_option_ids) then
    raise exception 'community_poll_option_invalid' using errcode='22023';
  end if;

  delete from public.bil_community_poll_votes
  where post_id=p_post_id and voter_id=v_uid;

  insert into public.bil_community_poll_votes(
    post_id,option_id,voter_id
  )
  select p_post_id,value,v_uid
  from unnest(p_option_ids) value;

  return cardinality(p_option_ids);
end
$$;

create or replace function public.bil_community_poll_v1(
  p_post_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_poll public.bil_community_polls%rowtype;
  v_options jsonb;
  v_total integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_post_id is null
     or not public.bil_social_post_visible_v2(p_post_id) then
    raise exception 'community_poll_unavailable' using errcode='42501';
  end if;

  select * into v_poll
  from public.bil_community_polls p
  where p.post_id=p_post_id;
  if not found then
    return null;
  end if;

  select count(*)::integer into v_total
  from public.bil_community_poll_votes v
  where v.post_id=p_post_id;

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
  into v_options
  from public.bil_community_poll_options o
  where o.post_id=p_post_id;

  return pg_catalog.jsonb_build_object(
    'post_id',v_poll.post_id,
    'question',v_poll.question,
    'allow_multiple',v_poll.allow_multiple,
    'closes_at',v_poll.closes_at,
    'closed',
      v_poll.closes_at is not null
      and v_poll.closes_at<=pg_catalog.clock_timestamp(),
    'total_votes',v_total,
    'options',coalesce(v_options,'[]'::jsonb)
  );
end
$$;

revoke all on function public.bil_create_my_community_poll_v1(
  uuid,text,text[],boolean,timestamptz
) from public,anon,service_role;
grant execute on function public.bil_create_my_community_poll_v1(
  uuid,text,text[],boolean,timestamptz
) to authenticated;

revoke all on function public.bil_vote_community_poll_v1(uuid,uuid[])
  from public,anon,service_role;
grant execute on function public.bil_vote_community_poll_v1(uuid,uuid[])
  to authenticated;

revoke all on function public.bil_community_poll_v1(uuid)
  from public,anon,service_role;
grant execute on function public.bil_community_poll_v1(uuid)
  to authenticated;

do $$
begin
  if to_regprocedure(
      'public.bil_create_my_community_poll_v1(uuid,text,text[],boolean,timestamptz)'
    ) is null
     or to_regprocedure(
       'public.bil_vote_community_poll_v1(uuid,uuid[])'
     ) is null
     or to_regprocedure('public.bil_community_poll_v1(uuid)') is null then
    raise exception 'community_polls_v1_postcondition_failed';
  end if;
end
$$;
