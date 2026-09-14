-- Repair production drift discovered during App Review on 2026-09-14.
-- The canonical StoreKit/Play product is bil_ai_boost. The original schema and
-- bil_credit_ai_boost_verified() already enforce that ID, but one deployed
-- database had drifted to a legacy bil_ai_boost_499 CHECK and therefore
-- rejected otherwise verified 2,500-token purchases at the persistence step.

alter table public.bil_ai_boost_purchases
  drop constraint if exists bil_ai_boost_purchases_product_id_check;

alter table public.bil_ai_boost_purchases
  add constraint bil_ai_boost_purchases_product_id_check
  check (product_id = 'bil_ai_boost');
