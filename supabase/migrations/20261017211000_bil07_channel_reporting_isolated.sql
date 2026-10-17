-- BIL07 message reports/moderation — ISOLATED ONLY, not production approved.
-- No admin route is embedded in the mobile app; these are server guardrails.
begin;
set local lock_timeout='5s';
set local statement_timeout='40s';
do $guard$
begin
 if pg_catalog.to_regclass('public.bil07_channel_messages_v1') is null
   or pg_catalog.to_regclass('public.bil_community_moderators') is null
   or pg_catalog.to_regprocedure('private.bil07_channel_assert_v1(uuid,boolean)') is null then
   raise exception 'bil07_channel_moderation_dependencies_missing' using errcode='55000';
 end if;
 if pg_catalog.to_regclass('private.bil07_channel_reports_v1') is not null then
   raise exception 'bil07_channel_moderation_schema_present_review_required' using errcode='55000';
 end if;
end $guard$;

create table private.bil07_channel_reports_v1 (
 id uuid primary key default pg_catalog.gen_random_uuid(),
 channel_id uuid not null references public.bil07_channels_v1(id) on delete cascade,
 message_id uuid not null references public.bil07_channel_messages_v1(id) on delete cascade,
 reporter_id uuid not null references auth.users(id) on delete cascade,
 reason text not null check(pg_catalog.char_length(reason) between 3 and 500),
 status text not null default 'open' check(status in ('open','closed')),
 created_at timestamptz not null default pg_catalog.clock_timestamp(),
 reviewed_by uuid references auth.users(id) on delete set null,
 reviewed_at timestamptz,
 decision_remove boolean,
 unique (message_id,reporter_id),
 check ((status='open' and reviewed_at is null and decision_remove is null)
    or (status='closed' and reviewed_at is not null and decision_remove is not null))
);
create index bil07_reports_review_queue_idx
  on private.bil07_channel_reports_v1(status,created_at,id);
alter table private.bil07_channel_reports_v1 enable row level security;
revoke all on private.bil07_channel_reports_v1
  from public,anon,authenticated,service_role;

create function private.bil07_assert_reviewer_v1()
returns uuid language plpgsql stable security definer set search_path=''
as $fn$
declare v_owner uuid := (select auth.uid());
begin
 if v_owner is null or not exists(
   select 1 from public.bil_community_moderators where user_id=v_owner)
 then raise exception 'community_moderator_required' using errcode='42501'; end if;
 return v_owner;
end $fn$;

create function public.bil07_channel_report_v1(
 p_channel_id uuid,p_message_id uuid,p_reason text
) returns jsonb language plpgsql volatile security definer set search_path=''
as $fn$
declare
 v_owner uuid := (select auth.uid());
 v_message public.bil07_channel_messages_v1%rowtype;
 v_report private.bil07_channel_reports_v1%rowtype;
 v_count bigint;
 v_replay boolean := false;
begin
 perform private.bil07_channel_assert_v1(p_channel_id,false);
 if p_message_id is null or p_reason is null
   or pg_catalog.char_length(p_reason) not between 3 and 500
   or p_reason ~ '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' then
   raise exception 'invalid_channel_report' using errcode='22023';
 end if;
 select * into v_message from public.bil07_channel_messages_v1
   where id=p_message_id and channel_id=p_channel_id and hidden_at is null;
 if not found or v_message.author_id=v_owner
   or private.bil_is_blocked_with(v_message.author_id) then
   raise exception 'channel_report_denied' using errcode='42501';
 end if;
 -- Only the authenticated reporter can occupy this serialized rate bucket.
 perform pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended('bil07_report:'||v_owner::text,0));
 select * into v_report from private.bil07_channel_reports_v1
   where reporter_id=v_owner and message_id=p_message_id;
 if found then
   if v_report.reason<>p_reason then
     raise exception 'channel_report_payload_mismatch' using errcode='22023';
   end if;
   v_replay:=true;
 else
   select pg_catalog.count(*) into v_count
     from private.bil07_channel_reports_v1 where reporter_id=v_owner
       and created_at>pg_catalog.clock_timestamp()-interval '24 hours';
   if v_count>=20 then
     raise exception 'channel_report_rate_limited' using errcode='42501';
   end if;
   insert into private.bil07_channel_reports_v1(channel_id,message_id,reporter_id,reason)
     values(p_channel_id,p_message_id,v_owner,p_reason)
     returning * into v_report;
 end if;
 return pg_catalog.jsonb_build_object(
   'contract_version',1,'owner_id',v_owner,'channel_id',p_channel_id,
   'report_id',v_report.id,'status',v_report.status,
   'idempotent_replay',v_replay,'server_time',pg_catalog.clock_timestamp());
end $fn$;

create function public.bil07_channel_review_queue_v1(p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path=''
as $fn$
declare
 v_reviewer uuid := private.bil07_assert_reviewer_v1();
 v_array jsonb:='[]'::jsonb;
 v_entry record;
begin
 if p_limit is null or p_limit not between 1 and 100 then
   raise exception 'invalid_review_limit' using errcode='22023'; end if;
 for v_entry in
   select r.id,r.channel_id,r.message_id,r.reporter_id,r.reason,
     r.created_at,m.author_id,m.text,m.hidden_at
     from private.bil07_channel_reports_v1 r
     join public.bil07_channel_messages_v1 m on m.id=r.message_id
     where r.status='open'
     order by r.created_at,r.id
     limit p_limit
 loop
   v_array:=v_array||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
     'id',v_entry.id,'channel_id',v_entry.channel_id,
     'message_id',v_entry.message_id,'reporter_id',v_entry.reporter_id,
     'reason',v_entry.reason,'created_at',v_entry.created_at,
     'author_id',v_entry.author_id,'text',v_entry.text,
     'already_hidden',v_entry.hidden_at is not null));
 end loop;
 return pg_catalog.jsonb_build_object('contract_version',1,
   'reviewer_id',v_reviewer,'reports',v_array,'server_time',pg_catalog.clock_timestamp());
end $fn$;

create function public.bil07_channel_decide_report_v1(
 p_report_id uuid,p_remove boolean
) returns jsonb language plpgsql volatile security definer set search_path=''
as $fn$
declare
 v_reviewer uuid:=private.bil07_assert_reviewer_v1();
 v_report private.bil07_channel_reports_v1%rowtype;
 v_replay boolean:=false;
begin
 if p_report_id is null or p_remove is null then
   raise exception 'invalid_channel_decision' using errcode='22023'; end if;
 select * into v_report from private.bil07_channel_reports_v1
   where id=p_report_id for update;
 if not found then
   raise exception 'channel_report_not_found' using errcode='42501'; end if;
 if v_report.status='closed' then
   if v_report.decision_remove is distinct from p_remove then
     raise exception 'channel_decision_conflict' using errcode='22023'; end if;
   v_replay:=true;
 else
   if p_remove then
     update public.bil07_channel_messages_v1
       set hidden_at=coalesce(hidden_at,pg_catalog.clock_timestamp())
       where id=v_report.message_id and channel_id=v_report.channel_id;
   end if;
   update private.bil07_channel_reports_v1
     set status='closed',decision_remove=p_remove,reviewed_by=v_reviewer,
       reviewed_at=pg_catalog.clock_timestamp()
     where id=p_report_id;
 end if;
 return pg_catalog.jsonb_build_object('contract_version',1,
   'reviewer_id',v_reviewer,'report_id',p_report_id,
   'decision_remove',p_remove,'idempotent_replay',v_replay,
   'server_time',pg_catalog.clock_timestamp());
end $fn$;

revoke all on function private.bil07_assert_reviewer_v1()
  from public,anon,authenticated,service_role;
revoke all on function public.bil07_channel_report_v1(uuid,uuid,text),
 public.bil07_channel_review_queue_v1(integer),
 public.bil07_channel_decide_report_v1(uuid,boolean)
 from public,anon,authenticated,service_role;
grant execute on function public.bil07_channel_report_v1(uuid,uuid,text),
 public.bil07_channel_review_queue_v1(integer),
 public.bil07_channel_decide_report_v1(uuid,boolean)
 to authenticated;
-- Production deployment still requires a reviewed UI report action and
-- separate staff moderation application. Neither is created by this SQL.
commit;
