-- Align the durable AI Boost ledger with the live App Store / Play product.
-- Production was corrected on 2026-09-14 after the table check constraint
-- still accepted the retired bil_ai_boost_499 identifier while the verified
-- purchase function and store catalog used bil_ai_boost.
alter table public.bil_ai_boost_purchases
  drop constraint if exists bil_ai_boost_purchases_product_id_check;

alter table public.bil_ai_boost_purchases
  add constraint bil_ai_boost_purchases_product_id_check
  check (product_id = 'bil_ai_boost');
