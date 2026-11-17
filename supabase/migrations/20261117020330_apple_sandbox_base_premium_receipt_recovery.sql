-- EXTERNAL PROPOSAL ONLY. Root review/tests required before applying.
-- One exact predicate; Apple SANDBOX base Premium receipt fulfillment only.
-- Keeps current SKU plan Premium; no catalogue, AI allowance or grants change.
begin;
do $bil_sandbox_base_receipt$
declare
  v_oid oid := to_regprocedure('private.bil_persist_verified_store_purchase_unordered(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text)');
  v_before text;
  v_after text;
  v_old text := $old$    if v_plan_id <> v_expected_plan then$old$;
  v_new text := $new$    if v_plan_id <> v_expected_plan
       and not coalesce((
         p_provider = 'apple'
         and p_environment = 'sandbox'
         and p_product_id in ('bil_premium', 'bil_premium_annual')
         and v_plan_id = 'premium'
         and v_expected_plan = 'premium_ai_coach'
       ), false) then$new$;
begin
  if v_oid is null then raise exception 'required_market_guard_function_missing'; end if;
  v_before := pg_get_functiondef(v_oid);
  if encode(sha256(convert_to(v_before,'UTF8')),'hex') <> '4544d66c792a9e5bf94815196ea55357d00eea0cb7aa32d524f49a5211a56710' then
    raise exception 'unexpected_market_guard_preimage';
  end if;
  if (length(v_before)-length(replace(v_before,v_old,'')))/length(v_old) <> 1 then
    raise exception 'market_guard_predicate_not_unique';
  end if;
  v_after := replace(v_before,v_old,v_new);
  if encode(sha256(convert_to(v_after,'UTF8')),'hex') <> 'c0d6b0cd8bad21aad20000a83389e8e40863b399d33a6a9c68584557bbc111a5' then
    raise exception 'unexpected_market_guard_candidate';
  end if;
  execute v_after;
  if pg_get_functiondef(v_oid) is distinct from v_after then
    raise exception 'market_guard_postwrite_definition_mismatch';
  end if;
end
$bil_sandbox_base_receipt$;
commit;
