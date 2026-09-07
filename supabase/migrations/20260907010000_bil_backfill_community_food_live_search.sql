begin;

-- Compatibility backfill for rows created before the live community-food
-- search contract. It preserves nutrition, review status, and ownership.
update public.bil_community_food_submissions
set
  serving_amount = coalesce(serving_amount, serving_grams),
  serving_unit = coalesce(nullif(trim(serving_unit), ''), 'g'),
  updated_at = now()
where serving_grams is not null
  and (serving_amount is null or serving_unit is null or trim(serving_unit) = '');

commit;
