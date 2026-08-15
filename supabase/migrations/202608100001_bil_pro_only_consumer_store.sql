begin;

-- Plus is retained as a readable historical plan identifier, but it can no
-- longer be enabled as a sellable store product. BIL Pro is the sole consumer
-- subscription from this migration onward.
update public.bil_store_product_registry
set enabled = false,
    updated_at = now()
where plan_id = 'plus' and enabled = true;

alter table public.bil_store_product_registry
drop constraint if exists bil_store_registry_only_pro_can_be_enabled;

alter table public.bil_store_product_registry
add constraint bil_store_registry_only_pro_can_be_enabled
check (not enabled or plan_id = 'pro');

commit;
