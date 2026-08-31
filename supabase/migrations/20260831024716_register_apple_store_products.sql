begin;

-- Apple and Google use the same four canonical subscription product IDs, but
-- the registry key is provider-scoped.  Keep the verified App Store bundle
-- and product catalogue authoritative so Apple receipts can be persisted by
-- bil_persist_verified_store_purchase instead of failing product_not_enabled.
insert into public.bil_store_product_registry(
  provider,
  product_id,
  package_or_bundle_id,
  plan_id,
  billing_term,
  enabled
)
values
  (
    'apple',
    'bil_premium',
    'com.bilhealth.bodyintelligencelog',
    'premium',
    'monthly',
    true
  ),
  (
    'apple',
    'bil_premium_annual',
    'com.bilhealth.bodyintelligencelog',
    'premium',
    'annual',
    true
  ),
  (
    'apple',
    'bil_premium_ai_coach',
    'com.bilhealth.bodyintelligencelog',
    'premium_ai_coach',
    'monthly',
    true
  ),
  (
    'apple',
    'bil_premium_ai_coach_annual',
    'com.bilhealth.bodyintelligencelog',
    'premium_ai_coach',
    'annual',
    true
  )
on conflict (provider, product_id) do update set
  package_or_bundle_id = excluded.package_or_bundle_id,
  plan_id = excluded.plan_id,
  billing_term = excluded.billing_term,
  enabled = excluded.enabled,
  updated_at = now();

commit;

