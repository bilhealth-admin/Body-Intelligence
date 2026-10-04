-- Unfiltered auth-user FK lookup coverage, inspected in Production 2026-10-04.
-- Existing status/client-id/source-key partials do not cover all FK rows.
-- Five other IS NOT NULL FK partials already cover equality and are untouched.
-- The five inspected tables are currently 49-147 KiB (including all indexes).
-- Ordinary transactional index creation is deliberately bounded; if the lock
-- or build cannot finish, abort and reassess instead of silently waiting.
set local lock_timeout='3s';
set local statement_timeout='30s';

do $fk_lookup_indexes$
declare
  v_target record;
  v_table regclass;
  v_column smallint;
  v_auth_id smallint;
begin
  if pg_catalog.to_regclass('auth.users') is null then
    raise exception 'fk_lookup_auth_table_missing' using errcode='55000';
  end if;
  select a.attnum into v_auth_id from pg_catalog.pg_attribute a
  where a.attrelid='auth.users'::regclass and a.attname='id'
    and a.atttypid='uuid'::regtype and not a.attisdropped;
  if v_auth_id is null then
    raise exception 'fk_lookup_auth_id_changed' using errcode='55000';
  end if;

  -- One fixed alphabetical lock order prevents schema drift during validation.
  -- SHARE blocks writes only for this short, all-or-nothing migration.
  lock table public.bil_account_deletion_requests,
    public.bil_community_food_submissions, public.bil_friendships,
    public.bil_messages, public.bil_push_outbox in share mode;

  for v_target in select * from (values
    ('bil_account_deletion_requests','user_id','bil_account_deletion_user_fk_lookup_idx'),
    ('bil_community_food_submissions','contributor_id','bil_food_contributor_fk_lookup_idx'),
    ('bil_friendships','addressee_id','bil_friendships_addressee_fk_lookup_idx'),
    ('bil_messages','recipient_id','bil_messages_recipient_fk_lookup_idx'),
    ('bil_push_outbox','recipient_id','bil_push_outbox_recipient_fk_lookup_idx')
  ) as targets(table_name,column_name,index_name) loop
    v_table:=pg_catalog.to_regclass('public.'||v_target.table_name);
    v_column:=null;
    select a.attnum into v_column from pg_catalog.pg_attribute a
    join pg_catalog.pg_class t on t.oid=a.attrelid
    where a.attrelid=v_table and a.attname=v_target.column_name
      and not a.attisdropped and a.attnotnull
      and a.atttypid='uuid'::regtype and t.relkind='r';
    if v_column is null or not exists (
      select 1 from pg_catalog.pg_constraint c
      where c.conrelid=v_table and c.contype='f' and c.convalidated
        and c.conkey=array[v_column]::smallint[]
        and c.confrelid='auth.users'::regclass
        and c.confkey=array[v_auth_id]::smallint[] and c.confdeltype='c'
    ) then
      raise exception 'fk_lookup_constraint_changed: %.%',
        v_target.table_name,v_target.column_name using errcode='55000';
    end if;
    if pg_catalog.to_regclass('public.'||v_target.index_name) is not null then
      raise exception 'fk_lookup_reserved_index_name_exists: %',v_target.index_name
        using errcode='55000';
    end if;
    if exists (
      select 1 from pg_catalog.pg_index i
      join pg_catalog.pg_class ci on ci.oid=i.indexrelid
      join pg_catalog.pg_am am on am.oid=ci.relam
      where i.indrelid=v_table and i.indisvalid and i.indisready
        and am.amname='btree' and i.indkey[0]=v_column
        and (i.indpred is null or pg_catalog.pg_get_expr(i.indpred,i.indrelid)=
          pg_catalog.format('(%I IS NOT NULL)',v_target.column_name))
    ) then
      raise exception 'fk_lookup_already_covered_review_required: %.%',
        v_target.table_name,v_target.column_name using errcode='55000';
    end if;
  end loop;

  create index bil_account_deletion_user_fk_lookup_idx
    on public.bil_account_deletion_requests using btree(user_id);
  create index bil_food_contributor_fk_lookup_idx
    on public.bil_community_food_submissions using btree(contributor_id);
  create index bil_friendships_addressee_fk_lookup_idx
    on public.bil_friendships using btree(addressee_id);
  create index bil_messages_recipient_fk_lookup_idx
    on public.bil_messages using btree(recipient_id);
  create index bil_push_outbox_recipient_fk_lookup_idx
    on public.bil_push_outbox using btree(recipient_id);

  if (select count(*) from pg_catalog.pg_index i
      join pg_catalog.pg_class ci on ci.oid=i.indexrelid
      join pg_catalog.pg_am am on am.oid=ci.relam
      where ci.relnamespace='public'::regnamespace
        and ci.relname in ('bil_account_deletion_user_fk_lookup_idx',
          'bil_food_contributor_fk_lookup_idx','bil_friendships_addressee_fk_lookup_idx',
          'bil_messages_recipient_fk_lookup_idx','bil_push_outbox_recipient_fk_lookup_idx')
        and i.indisvalid and i.indisready and not i.indisunique
        and i.indpred is null and i.indexprs is null
        and i.indnkeyatts=1 and am.amname='btree')<>5 then
    raise exception 'fk_lookup_index_postcondition_failed' using errcode='55000';
  end if;
end
$fk_lookup_indexes$;
