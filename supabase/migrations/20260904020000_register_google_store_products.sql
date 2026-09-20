begin;

-- The product registry is provider-scoped. Register the canonical Google Play
-- subscriptions explicitly so a fresh database and a recovered deployment do
-- not depend on rows that were created manually outside migration history.
-- This does not create or activate products in Google Play Console; it only
-- permits the backend to persist an otherwise fully verified Play purchase.
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
    'google',
    'bil_premium',
    'com.bilhealth.bodyintelligencelog',
    'premium',
    'monthly',
    true
  ),
  (
    'google',
    'bil_premium_annual',
    'com.bilhealth.bodyintelligencelog',
    'premium',
    'annual',
    true
  ),
  (
    'google',
    'bil_premium_ai_coach',
    'com.bilhealth.bodyintelligencelog',
    'premium_ai_coach',
    'monthly',
    true
  ),
  (
    'google',
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
