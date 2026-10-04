-- Align only the draft body CHECK with the approved LF/CR/TAB RPC contract.
-- The original CHECK rejected genuine multiline drafts after RPC validation.
-- No body-size increase, data rewrite, privilege, RLS or function change.
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $draft_body_whitespace$
declare
  v_before text;
  v_validated boolean;
begin
  if pg_catalog.to_regclass('public.bil_community_post_drafts_v1') is null then
    raise exception 'community_draft_body_constraint_precondition_failed'
      using errcode='55000';
  end if;

  -- Serialize the drift check and replacement; fail instead of overwriting
  -- any constraint that changed after the actual Production inspection.
  lock table public.bil_community_post_drafts_v1 in access exclusive mode;
  select pg_catalog.pg_get_constraintdef(c.oid),c.convalidated
    into v_before,v_validated
    from pg_catalog.pg_constraint c
    where c.conrelid='public.bil_community_post_drafts_v1'::regclass
      and c.conname='bil_community_post_drafts_v1_body_check'
      and c.contype='c';
  if v_before is distinct from
       'CHECK (((char_length(body) <= 1200) AND (body !~ ''[[:cntrl:]]''::text)))'
     or v_validated is not true then
    raise exception 'community_draft_body_constraint_changed_since_inspection'
      using errcode='55000';
  end if;

  alter table public.bil_community_post_drafts_v1
    drop constraint bil_community_post_drafts_v1_body_check,
    add constraint bil_community_post_drafts_v1_body_check check (
      char_length(body)<=1200
      and pg_catalog.translate(body,E'\n\r\t','') !~ '[[:cntrl:]]'
    );

  if not exists (
    select 1 from pg_catalog.pg_constraint c
    where c.conrelid='public.bil_community_post_drafts_v1'::regclass
      and c.conname='bil_community_post_drafts_v1_body_check'
      and c.contype='c' and c.convalidated
  ) then
    raise exception 'community_draft_body_constraint_postcondition_failed'
      using errcode='55000';
  end if;
end
$draft_body_whitespace$;
