-- Apply the existing reviewed Circle visibility boundary to legacy read paths.
-- Preserve complete effective function bodies, signatures, defaults and ACLs.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $circle_visibility$
declare
  v_change record;
  v_oid regprocedure;
  v_definition text;
  v_definitions text[] := array[]::text[];
  v_old_count integer;
  v_new_count integer;
begin
  if to_regprocedure('private.bil_circle_visible_v1(uuid)') is null then
    raise exception 'circle_visibility_dependency_missing' using errcode='55000';
  end if;
  -- Validate every insertion point before executing any replacement. Unknown
  -- definitions fail closed instead of overwriting newer server protections.
  for v_change in select * from (values
    ('public.bil_list_community_circles_v1()',
$list_old$  where c.active
    and (
      c.access='public'$list_old$,
$list_new$  where c.active
    and private.bil_circle_visible_v1(c.id)
    and (
      c.access='public'$list_new$),
    ('public.bil_community_circle_post_refs_v1(text,timestamp with time zone,uuid,integer)',
$refs_old$  where c.slug=p_slug and c.active;$refs_old$,
$refs_new$  where c.slug=p_slug and c.active
    and private.bil_circle_visible_v1(c.id);$refs_new$),
    ('public.bil_community_post_reference_metadata_v1(uuid[])',
$metadata_old$      where pc.post_id=p.id and cir.active
      order by pc.created_at desc$metadata_old$,
$metadata_new$      where pc.post_id=p.id and cir.active
        and private.bil_circle_visible_v1(cir.id)
      order by pc.created_at desc$metadata_new$)
  ) changes(signature,old_fragment,new_fragment) loop
    v_oid := to_regprocedure(v_change.signature);
    if v_oid is null or not (select prosecdef from pg_proc where oid=v_oid)
      or not has_function_privilege(
        (select proowner from pg_proc where oid=v_oid),
        'private.bil_circle_visible_v1(uuid)', 'EXECUTE'
      ) then
      raise exception 'circle_visibility_rpc_dependency_invalid: %',v_change.signature
        using errcode='55000';
    end if;
    v_definition := replace(pg_get_functiondef(v_oid),chr(13)||chr(10),chr(10));
    v_old_count := (length(v_definition)-length(replace(v_definition,v_change.old_fragment,'')))/length(v_change.old_fragment);
    v_new_count := (length(v_definition)-length(replace(v_definition,v_change.new_fragment,'')))/length(v_change.new_fragment);
    if v_old_count=0 and v_new_count=1 then
      continue; -- Exact reapplication preserves the already guarded definition.
    end if;
    if v_old_count<>1 or v_new_count<>0 then
      raise exception 'circle_visibility_rpc_definition_drift: %',v_change.signature
        using errcode='55000';
    end if;
    v_definitions := array_append(v_definitions,
      replace(v_definition,v_change.old_fragment,v_change.new_fragment));
  end loop;
  foreach v_definition in array v_definitions loop
    execute v_definition;
  end loop;
end
$circle_visibility$;

commit;
