-- Close the remaining direct-Data-API write gaps on the legacy Community
-- tables without changing their RLS policies or the Social v2 schema. Existing
-- rows, moderator/service RPCs, and the current Flutter payloads are preserved.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $legacy_community_write_preflight$
declare
  v_post_columns text[];
  v_message_columns text[];
  v_report_columns text[];
  v_post_guard_definition text;
  v_post_guard_trigger_definition text;
begin
  if pg_catalog.to_regclass('public.bil_community_posts') is null
     or pg_catalog.to_regclass('public.bil_messages') is null
     or pg_catalog.to_regclass('public.bil_community_reports') is null
     or pg_catalog.to_regclass('public.bil_public_profiles') is null
     or pg_catalog.to_regclass(
       'public.bil_community_food_submissions'
     ) is null then
    raise exception 'legacy_community_write_precondition_failed'
      using errcode = '55000',
            detail = 'A reviewed legacy Community table is missing.';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_class relation
    where relation.oid in (
      'public.bil_community_posts'::regclass,
      'public.bil_messages'::regclass,
      'public.bil_community_reports'::regclass,
      'public.bil_public_profiles'::regclass,
      'public.bil_community_food_submissions'::regclass
    )
      and not relation.relrowsecurity
  ) then
    raise exception 'legacy_community_rls_precondition_failed'
      using errcode = '55000',
            detail = 'A report target or protected write table no longer has RLS.';
  end if;

  select pg_catalog.array_agg(
    attribute.attname::text order by attribute.attnum
  )
  into v_post_columns
  from pg_catalog.pg_attribute attribute
  where attribute.attrelid = 'public.bil_community_posts'::regclass
    and attribute.attnum > 0
    and not attribute.attisdropped;

  select pg_catalog.array_agg(
    attribute.attname::text order by attribute.attnum
  )
  into v_message_columns
  from pg_catalog.pg_attribute attribute
  where attribute.attrelid = 'public.bil_messages'::regclass
    and attribute.attnum > 0
    and not attribute.attisdropped;

  select pg_catalog.array_agg(
    attribute.attname::text order by attribute.attnum
  )
  into v_report_columns
  from pg_catalog.pg_attribute attribute
  where attribute.attrelid = 'public.bil_community_reports'::regclass
    and attribute.attnum > 0
    and not attribute.attisdropped;

  if v_post_columns is distinct from array[
       'id', 'author_id', 'body', 'media_url', 'visibility', 'created_at',
       'edited_at', 'deleted_at', 'media_object_path', 'media_mime_type',
       'media_bytes', 'media_width', 'media_height', 'moderation_status',
       'reviewed_at'
     ]::text[]
     or v_message_columns is distinct from array[
       'id', 'sender_id', 'recipient_id', 'body', 'created_at', 'read_at',
       'deleted_by_sender_at', 'deleted_by_recipient_at'
     ]::text[]
     or v_report_columns is distinct from array[
       'id', 'reporter_id', 'target_kind', 'target_id', 'reason', 'status',
       'created_at'
     ]::text[] then
    raise exception 'legacy_community_column_drift_precondition_failed'
      using errcode = '55000';
  end if;

  if pg_catalog.to_regprocedure(
       'public.bil_guard_community_post_moderation()'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_guard_community_member_access()'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_delete_message(uuid)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_mark_conversation_read(uuid)'
     ) is null then
    raise exception 'legacy_community_function_precondition_failed'
      using errcode = '55000';
  end if;

  select pg_catalog.pg_get_functiondef(procedure.oid)
  into v_post_guard_definition
  from pg_catalog.pg_proc procedure
  join pg_catalog.pg_namespace namespace
    on namespace.oid = procedure.pronamespace
  where namespace.nspname = 'public'
    and procedure.proname = 'bil_guard_community_post_moderation'
    and procedure.pronargs = 0
    and not procedure.prosecdef
    and procedure.provolatile = 'v';

  if v_post_guard_definition is null
     or pg_catalog.strpos(
       v_post_guard_definition,
       'current_user in (''anon'', ''authenticated'')'
     ) = 0
     or pg_catalog.strpos(
       v_post_guard_definition,
       'new.author_id = (select auth.uid())'
     ) = 0
     or pg_catalog.strpos(
       v_post_guard_definition,
       'new.deleted_at is not null'
     ) = 0
     or pg_catalog.strpos(
       v_post_guard_definition,
       'new.media_object_path is null'
     ) = 0
     or pg_catalog.strpos(
       v_post_guard_definition,
       'community_post_update_requires_human_review'
     ) = 0 then
    raise exception 'legacy_community_function_definition_precondition_failed'
      using errcode = '55000';
  end if;

  if not exists (
       select 1
       from pg_catalog.pg_trigger trigger_row
       where trigger_row.tgrelid = 'public.bil_community_posts'::regclass
         and trigger_row.tgname = 'bil_00_posts_member_access'
         and trigger_row.tgenabled = 'O'
         and not trigger_row.tgisinternal
     )
     or not exists (
       select 1
       from pg_catalog.pg_trigger trigger_row
       where trigger_row.tgrelid = 'public.bil_community_posts'::regclass
         and trigger_row.tgname = 'bil_01_posts_moderation_guard'
         and trigger_row.tgenabled = 'O'
         and not trigger_row.tgisinternal
         and trigger_row.tgfoid =
           'public.bil_guard_community_post_moderation()'::regprocedure
     ) then
    raise exception 'legacy_community_post_guard_precondition_failed'
      using errcode = '55000';
  end if;

  select pg_catalog.pg_get_triggerdef(trigger_row.oid, true)
  into v_post_guard_trigger_definition
  from pg_catalog.pg_trigger trigger_row
  where trigger_row.tgrelid = 'public.bil_community_posts'::regclass
    and trigger_row.tgname = 'bil_01_posts_moderation_guard'
    and not trigger_row.tgisinternal;

  if pg_catalog.strpos(
       v_post_guard_trigger_definition,
       'BEFORE INSERT OR UPDATE OF moderation_status, reviewed_at ON bil_community_posts'
     ) = 0 then
    raise exception 'legacy_community_post_guard_definition_precondition_failed'
      using errcode = '55000';
  end if;

  if (
    select pg_catalog.count(*)
    from pg_catalog.pg_constraint constraint_row
    where constraint_row.conrelid = 'public.bil_community_posts'::regclass
      and constraint_row.convalidated
      and constraint_row.conname in (
        'bil_community_posts_media_all_or_none',
        'bil_community_posts_media_mime',
        'bil_community_posts_media_size',
        'bil_community_posts_media_dimensions',
        'bil_community_posts_media_owned_path'
      )
  ) <> 5 then
    raise exception 'legacy_community_media_constraint_precondition_failed'
      using errcode = '55000';
  end if;

  if exists (
       select 1
       from (
         values
           ('bil_public_profiles', 'bil_profiles_privacy_read'),
           ('bil_community_posts', 'bil_posts_read'),
           ('bil_messages', 'bil_messages_read_parties'),
           ('bil_community_food_submissions', 'bil_food_read'),
           ('bil_community_reports', 'bil_reports_read_own')
       ) required_policy(table_name, policy_name)
       where not exists (
         select 1
         from pg_catalog.pg_policies policy
         where policy.schemaname = 'public'
           and policy.tablename = required_policy.table_name
           and policy.policyname = required_policy.policy_name
           and policy.cmd = 'SELECT'
           and policy.roles = array['authenticated']::name[]
       )
     )
     or not exists (
       select 1
       from pg_catalog.pg_policies policy
       where policy.schemaname = 'public'
         and policy.tablename = 'bil_community_reports'
         and policy.policyname = 'bil_reports_insert'
         and policy.cmd = 'INSERT'
         and policy.roles = array['authenticated']::name[]
     ) then
    raise exception 'legacy_community_policy_precondition_failed'
      using errcode = '55000';
  end if;

  if not pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_posts', 'SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_messages', 'SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_reports', 'SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_public_profiles', 'SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'authenticated',
       'public.bil_community_food_submissions',
       'SELECT'
     ) then
    raise exception 'legacy_community_select_acl_precondition_failed'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.bil_community_reports report
    where report.status in ('open', 'reviewing')
    group by report.reporter_id, report.target_kind, report.target_id
    having pg_catalog.count(*) > 1
  ) then
    raise exception 'legacy_community_report_duplicate_precondition_failed'
      using errcode = '55000',
            detail = 'Duplicate active reports must be reviewed, not silently deleted.';
  end if;

  if pg_catalog.to_regclass(
       'public.bil_community_reports_active_target_uidx'
     ) is not null
     or pg_catalog.to_regclass(
       'public.bil_community_reports_reporter_created_idx'
     ) is not null
     or pg_catalog.to_regprocedure(
       'public.bil_guard_community_report_write()'
     ) is not null then
    raise exception 'legacy_community_hardening_name_precondition_failed'
      using errcode = '55000';
  end if;
end
$legacy_community_write_preflight$;

-- The reviewed function already enforces the exact owner soft-delete shape,
-- but its historical trigger fired only when moderation columns appeared in
-- the UPDATE target list. Attach it to every direct UPDATE so the column-level
-- grant below cannot be used to republish or swap media references.
drop trigger bil_01_posts_moderation_guard
on public.bil_community_posts;
create trigger bil_01_posts_moderation_guard
before insert or update on public.bil_community_posts
for each row execute function public.bil_guard_community_post_moderation();

-- The mobile post composer needs an explicit UUID only for immutable image
-- paths. Server timestamps, edit/delete state, and human-review fields stay
-- unavailable on INSERT. The only direct UPDATE remains the current
-- privacy-preserving soft-delete/media-reference cleanup payload.
revoke insert, update, delete on table public.bil_community_posts
from public, anon, authenticated;
revoke insert (
  id, author_id, body, media_url, visibility, created_at, edited_at,
  deleted_at, media_object_path, media_mime_type, media_bytes, media_width,
  media_height, moderation_status, reviewed_at
) on table public.bil_community_posts from public, anon, authenticated;
revoke update (
  id, author_id, body, media_url, visibility, created_at, edited_at,
  deleted_at, media_object_path, media_mime_type, media_bytes, media_width,
  media_height, moderation_status, reviewed_at
) on table public.bil_community_posts from public, anon, authenticated;

grant insert (
  id, author_id, body, media_url, visibility, media_object_path,
  media_mime_type, media_bytes, media_width, media_height, moderation_status
) on table public.bil_community_posts to authenticated;
grant update (
  deleted_at, media_url, media_object_path, media_mime_type, media_bytes,
  media_width, media_height
) on table public.bil_community_posts to authenticated;

-- Message lifecycle timestamps remain available only through the existing
-- bil_mark_conversation_read and bil_delete_message SECURITY DEFINER RPCs.
revoke insert, update, delete on table public.bil_messages
from public, anon, authenticated;
revoke insert (
  id, sender_id, recipient_id, body, created_at, read_at,
  deleted_by_sender_at, deleted_by_recipient_at
) on table public.bil_messages from public, anon, authenticated;
revoke update (
  id, sender_id, recipient_id, body, created_at, read_at,
  deleted_by_sender_at, deleted_by_recipient_at
) on table public.bil_messages from public, anon, authenticated;

grant insert (sender_id, recipient_id, body)
on table public.bil_messages to authenticated;

-- A client may provide only the reporter, polymorphic target, and reason.
-- Report identity, workflow status, and timestamps are server defaults.
revoke insert, update, delete on table public.bil_community_reports
from public, anon, authenticated;
revoke insert (
  id, reporter_id, target_kind, target_id, reason, status, created_at
) on table public.bil_community_reports from public, anon, authenticated;
revoke update (
  id, reporter_id, target_kind, target_id, reason, status, created_at
) on table public.bil_community_reports from public, anon, authenticated;

grant insert (reporter_id, target_kind, target_id, reason)
on table public.bil_community_reports to authenticated;

-- Active duplicates are suppressed by the trigger and independently guarded
-- by this index. A closed report does not prevent a genuinely new incident.
create unique index bil_community_reports_active_target_uidx
on public.bil_community_reports (reporter_id, target_kind, target_id)
where status in ('open', 'reviewing');

create index bil_community_reports_reporter_created_idx
on public.bil_community_reports (reporter_id, created_at desc);

create function public.bil_guard_community_report_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_target_visible boolean := false;
  v_recent_count integer;
begin
  if current_user in ('anon', 'authenticated')
     and (
       v_actor_id is null
       or new.reporter_id is distinct from v_actor_id
       or new.status <> 'open'
     ) then
    raise exception 'invalid_community_report'
      using errcode = '42501';
  end if;

  new.reason := pg_catalog.btrim(new.reason);
  if new.reason is null
     or pg_catalog.char_length(new.reason) not between 3 and 500 then
    raise exception 'invalid_community_report'
      using errcode = '22023';
  end if;

  -- SECURITY INVOKER is intentional: these reads pass through the caller's
  -- existing SELECT policies. One generic failure avoids revealing whether a
  -- hidden target exists.
  case new.target_kind
    when 'profile' then
      perform 1
      from public.bil_public_profiles profile
      where profile.user_id = new.target_id
      limit 1;
      v_target_visible := found;
    when 'post' then
      perform 1
      from public.bil_community_posts post
      where post.id = new.target_id
      limit 1;
      v_target_visible := found;
    when 'message' then
      perform 1
      from public.bil_messages message
      where message.id = new.target_id
      limit 1;
      v_target_visible := found;
    when 'food' then
      perform 1
      from public.bil_community_food_submissions food
      where food.id = new.target_id
      limit 1;
      v_target_visible := found;
    else
      v_target_visible := false;
  end case;

  if not v_target_visible then
    raise exception 'community_report_target_unavailable'
      using errcode = '42501';
  end if;

  -- Serialize one reporter's inserts so the rolling limit and duplicate check
  -- remain correct under concurrent retries. Reporting stays available to a
  -- suspended account because it is a safety control, matching the existing
  -- Community access contract.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_report_write:' || new.reporter_id::text,
      0
    )
  );

  if exists (
    select 1
    from public.bil_community_reports report
    where report.reporter_id = new.reporter_id
      and report.target_kind = new.target_kind
      and report.target_id = new.target_id
      and report.status in ('open', 'reviewing')
  ) then
    return null;
  end if;

  if current_user in ('anon', 'authenticated') then
    select pg_catalog.count(*)
    into v_recent_count
    from public.bil_community_reports report
    where report.reporter_id = v_actor_id
      and report.created_at >=
        pg_catalog.statement_timestamp() - interval '1 hour';

    if v_recent_count >= 20 then
      raise exception 'community_report_rate_limit_exceeded'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end
$function$;

revoke all on function public.bil_guard_community_report_write()
from public, anon, authenticated, service_role;

create trigger bil_000_reports_write_guard
before insert on public.bil_community_reports
for each row execute function public.bil_guard_community_report_write();

do $legacy_community_write_postconditions$
declare
  v_post_insert_columns text[];
  v_post_update_columns text[];
  v_message_insert_columns text[];
  v_report_insert_columns text[];
  v_report_guard regprocedure :=
    'public.bil_guard_community_report_write()'::regprocedure;
  v_post_guard_trigger_definition text;
begin
  if not pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_posts', 'SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_messages', 'SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_reports', 'SELECT'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_posts', 'INSERT'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_posts', 'UPDATE'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_posts', 'DELETE'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_messages', 'INSERT'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_messages', 'UPDATE'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_messages', 'DELETE'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_reports', 'INSERT'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_reports', 'UPDATE'
     )
     or pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_community_reports', 'DELETE'
     ) then
    raise exception 'legacy_community_table_acl_postcondition_failed';
  end if;

  select coalesce(
    pg_catalog.array_agg(attribute.attname::text order by attribute.attnum)
      filter (
        where pg_catalog.has_column_privilege(
          'authenticated', 'public.bil_community_posts',
          attribute.attname, 'INSERT'
        )
      ),
    '{}'::text[]
  )
  into v_post_insert_columns
  from pg_catalog.pg_attribute attribute
  where attribute.attrelid = 'public.bil_community_posts'::regclass
    and attribute.attnum > 0
    and not attribute.attisdropped;

  select coalesce(
    pg_catalog.array_agg(attribute.attname::text order by attribute.attnum)
      filter (
        where pg_catalog.has_column_privilege(
          'authenticated', 'public.bil_community_posts',
          attribute.attname, 'UPDATE'
        )
      ),
    '{}'::text[]
  )
  into v_post_update_columns
  from pg_catalog.pg_attribute attribute
  where attribute.attrelid = 'public.bil_community_posts'::regclass
    and attribute.attnum > 0
    and not attribute.attisdropped;

  select coalesce(
    pg_catalog.array_agg(attribute.attname::text order by attribute.attnum)
      filter (
        where pg_catalog.has_column_privilege(
          'authenticated', 'public.bil_messages',
          attribute.attname, 'INSERT'
        )
      ),
    '{}'::text[]
  )
  into v_message_insert_columns
  from pg_catalog.pg_attribute attribute
  where attribute.attrelid = 'public.bil_messages'::regclass
    and attribute.attnum > 0
    and not attribute.attisdropped;

  select coalesce(
    pg_catalog.array_agg(attribute.attname::text order by attribute.attnum)
      filter (
        where pg_catalog.has_column_privilege(
          'authenticated', 'public.bil_community_reports',
          attribute.attname, 'INSERT'
        )
      ),
    '{}'::text[]
  )
  into v_report_insert_columns
  from pg_catalog.pg_attribute attribute
  where attribute.attrelid = 'public.bil_community_reports'::regclass
    and attribute.attnum > 0
    and not attribute.attisdropped;

  if v_post_insert_columns is distinct from array[
       'id', 'author_id', 'body', 'media_url', 'visibility',
       'media_object_path', 'media_mime_type', 'media_bytes', 'media_width',
       'media_height', 'moderation_status'
     ]::text[]
     or v_post_update_columns is distinct from array[
       'media_url', 'deleted_at', 'media_object_path', 'media_mime_type',
       'media_bytes', 'media_width', 'media_height'
     ]::text[]
     or v_message_insert_columns is distinct from array[
       'sender_id', 'recipient_id', 'body'
     ]::text[]
     or v_report_insert_columns is distinct from array[
       'reporter_id', 'target_kind', 'target_id', 'reason'
     ]::text[] then
    raise exception 'legacy_community_column_acl_postcondition_failed';
  end if;

  if exists (
       select 1
       from (
         values
           ('public.bil_messages'::regclass),
           ('public.bil_community_reports'::regclass)
       ) protected_table(table_oid)
       cross join pg_catalog.pg_attribute attribute
       where attribute.attrelid = protected_table.table_oid
         and attribute.attnum > 0
         and not attribute.attisdropped
         and pg_catalog.has_column_privilege(
           'authenticated', protected_table.table_oid,
           attribute.attnum::smallint, 'UPDATE'
         )
     )
     or exists (
       select 1
       from pg_catalog.pg_class relation
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           relation.relacl,
           pg_catalog.acldefault('r', relation.relowner)
         )
       ) privilege
       where relation.oid in (
         'public.bil_community_posts'::regclass,
         'public.bil_messages'::regclass,
         'public.bil_community_reports'::regclass
       )
         and privilege.grantee = 0
         and privilege.privilege_type in ('INSERT', 'UPDATE', 'DELETE')
     ) then
    raise exception 'legacy_community_residual_acl_postcondition_failed';
  end if;

  if not exists (
       select 1
       from pg_catalog.pg_trigger trigger_row
       where trigger_row.tgrelid = 'public.bil_community_reports'::regclass
         and trigger_row.tgname = 'bil_000_reports_write_guard'
         and trigger_row.tgenabled = 'O'
         and not trigger_row.tgisinternal
     )
     or not exists (
       select 1
       from pg_catalog.pg_proc procedure
       where procedure.oid = v_report_guard
         and not procedure.prosecdef
         and procedure.provolatile = 'v'
     )
     or pg_catalog.has_function_privilege(
       'anon', v_report_guard, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated', v_report_guard, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'service_role', v_report_guard, 'EXECUTE'
     ) then
    raise exception 'legacy_community_report_guard_postcondition_failed';
  end if;

  select pg_catalog.pg_get_triggerdef(trigger_row.oid, true)
  into v_post_guard_trigger_definition
  from pg_catalog.pg_trigger trigger_row
  where trigger_row.tgrelid = 'public.bil_community_posts'::regclass
    and trigger_row.tgname = 'bil_01_posts_moderation_guard'
    and trigger_row.tgenabled = 'O'
    and not trigger_row.tgisinternal
    and trigger_row.tgfoid =
      'public.bil_guard_community_post_moderation()'::regprocedure;

  if v_post_guard_trigger_definition is null
     or pg_catalog.strpos(
       v_post_guard_trigger_definition,
       'BEFORE INSERT OR UPDATE ON bil_community_posts'
     ) = 0
     or pg_catalog.strpos(
       v_post_guard_trigger_definition,
       'UPDATE OF moderation_status'
     ) > 0 then
    raise exception 'legacy_community_post_guard_postcondition_failed';
  end if;

  if not exists (
       select 1
       from pg_catalog.pg_index index_row
       where index_row.indexrelid =
         'public.bil_community_reports_active_target_uidx'::regclass
         and index_row.indrelid = 'public.bil_community_reports'::regclass
         and index_row.indisunique
         and index_row.indpred is not null
     )
     or not exists (
       select 1
       from pg_catalog.pg_index index_row
       where index_row.indexrelid =
         'public.bil_community_reports_reporter_created_idx'::regclass
         and index_row.indrelid = 'public.bil_community_reports'::regclass
     )
     or exists (
       select 1
       from pg_catalog.pg_class relation
       where relation.oid in (
         'public.bil_community_posts'::regclass,
         'public.bil_messages'::regclass,
         'public.bil_community_reports'::regclass
       )
         and not relation.relrowsecurity
     ) then
    raise exception 'legacy_community_schema_postcondition_failed';
  end if;
end
$legacy_community_write_postconditions$;

notify pgrst, 'reload schema';

commit;
