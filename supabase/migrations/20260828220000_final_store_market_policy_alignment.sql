begin;

-- Final owner-approved launch split (2026-08-28):
--   * EG, NG, PK, and TR sell Premium only.
--   * Every other enabled sale market sells Premium AI Coach.
--   * Countries outside this explicit allow-list are not sale markets.
-- This supersedes the older profit-floor classification without rewriting its
-- migration history.
alter table public.bil_commerce_country_policy
  add column if not exists sale_enabled boolean not null default false;

-- Fail closed on reruns and on countries left behind by an older policy.
update public.bil_commerce_country_policy
set sale_enabled = false,
    policy_version = '2026-08-28-v2',
    classification_reason = 'not_in_final_sale_market_allowlist',
    updated_at = now();

insert into public.bil_commerce_country_policy(
  country_code, market_class, target_plan, classification_reason,
  policy_version, sale_enabled
)
select code, 'token_only', 'premium',
  'owner_final_premium_only_market_2026_08_28', '2026-08-28-v2', true
from unnest(array['EG','NG','PK','TR']::text[]) code
on conflict (country_code) do update set
  market_class = excluded.market_class,
  target_plan = excluded.target_plan,
  classification_reason = excluded.classification_reason,
  policy_version = excluded.policy_version,
  sale_enabled = excluded.sale_enabled,
  updated_at = now();

-- These are the 168 AI-inclusive sale markets in the final store matrix.
insert into public.bil_commerce_country_policy(
  country_code, market_class, target_plan, classification_reason,
  policy_version, sale_enabled
)
select code, 'profitable', 'premium_ai_coach',
  'owner_final_all_other_sale_markets_ai_2026_08_28',
  '2026-08-28-v2', true
from unnest(array[
  'AE','AF','AG','AI','AL','AM','AO','AR','AT','AU','AZ','BA','BB','BE','BF',
  'BG','BH','BJ','BM','BN','BO','BR','BS','BT','BW','BZ','CA','CD','CG','CH',
  'CI','CL','CM','CO','CR','CV','CY','CZ','DE','DK','DM','DO','DZ','EC','EE',
  'ES','FI','FJ','FM','FR','GA','GB','GD','GE','GH','GM','GR','GT','GW','GY',
  'HK','HN','HR','HU','ID','IE','IL','IN','IQ','IS','IT','JM','JO','JP','KE',
  'KG','KH','KN','KR','KW','KY','KZ','LA','LB','LC','LK','LR','LT','LU','LV',
  'LY','MA','MD','ME','MG','MK','ML','MM','MN','MO','MR','MS','MT','MU','MV',
  'MW','MX','MY','MZ','NA','NE','NI','NL','NO','NP','NR','NZ','OM','PA','PE',
  'PG','PH','PL','PT','PW','PY','QA','RO','RS','RW','SA','SB','SC','SE','SG',
  'SI','SK','SL','SN','SR','ST','SV','SZ','TC','TD','TH','TJ','TM','TN','TO',
  'TT','TW','TZ','UA','UG','US','UY','UZ','VC','VE','VG','VN','VU','XK','YE',
  'ZA','ZM','ZW'
]::text[]) code
on conflict (country_code) do update set
  market_class = excluded.market_class,
  target_plan = excluded.target_plan,
  classification_reason = excluded.classification_reason,
  policy_version = excluded.policy_version,
  sale_enabled = excluded.sale_enabled,
  updated_at = now();

-- Canonical subscription identifiers must never be registered against the
-- wrong plan/term. AI Boost is a consumable verified by its dedicated flow and
-- must not be inserted into this subscription registry.
update public.bil_store_product_registry
set plan_id = case product_id
      when 'bil_premium' then 'premium'
      when 'bil_premium_annual' then 'premium'
      when 'bil_premium_ai_coach' then 'premium_ai_coach'
      when 'bil_premium_ai_coach_annual' then 'premium_ai_coach'
      else plan_id
    end,
    billing_term = case product_id
      when 'bil_premium' then 'monthly'
      when 'bil_premium_annual' then 'annual'
      when 'bil_premium_ai_coach' then 'monthly'
      when 'bil_premium_ai_coach_annual' then 'annual'
      else billing_term
    end,
    updated_at = now()
where product_id in (
  'bil_premium', 'bil_premium_annual',
  'bil_premium_ai_coach', 'bil_premium_ai_coach_annual'
);

alter table public.bil_store_product_registry
  drop constraint if exists bil_store_registry_canonical_product_mapping;
alter table public.bil_store_product_registry
  add constraint bil_store_registry_canonical_product_mapping check (
    (product_id = 'bil_premium'
      and plan_id = 'premium' and billing_term = 'monthly')
    or (product_id = 'bil_premium_annual'
      and plan_id = 'premium' and billing_term = 'annual')
    or (product_id = 'bil_premium_ai_coach'
      and plan_id = 'premium_ai_coach' and billing_term = 'monthly')
    or (product_id = 'bil_premium_ai_coach_annual'
      and plan_id = 'premium_ai_coach' and billing_term = 'annual')
    or product_id not in (
      'bil_premium', 'bil_premium_annual',
      'bil_premium_ai_coach', 'bil_premium_ai_coach_annual',
      'bil_ai_boost'
    )
  );

create or replace function public.bil_market_plan_for_store_country(
  p_store_country_code text
) returns text
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_code text := upper(trim(coalesce(p_store_country_code, '')));
  v_plan text;
begin
  if v_code ~ '^[A-Z]{2}$' then
    select target_plan into v_plan
    from public.bil_commerce_country_policy
    where country_code = v_code and sale_enabled = true;
    return coalesce(v_plan, 'not_for_sale');
  end if;

  -- Some verified store payloads expose ISO alpha-3 storefront codes. Keep
  -- this allow-list identical to the two-letter launch policy above.
  if v_code = any(array['EGY','NGA','PAK','TUR']::text[]) then
    return 'premium';
  end if;
  if v_code = any(array[
    'ARE','AFG','ATG','AIA','ALB','ARM','AGO','ARG','AUT','AUS','AZE','BIH','BRB','BEL','BFA',
    'BGR','BHR','BEN','BMU','BRN','BOL','BRA','BHS','BTN','BWA','BLZ','CAN','COD','COG','CHE',
    'CIV','CHL','CMR','COL','CRI','CPV','CYP','CZE','DEU','DNK','DMA','DOM','DZA','ECU','EST',
    'ESP','FIN','FJI','FSM','FRA','GAB','GBR','GRD','GEO','GHA','GMB','GRC','GTM','GNB','GUY',
    'HKG','HND','HRV','HUN','IDN','IRL','ISR','IND','IRQ','ISL','ITA','JAM','JOR','JPN','KEN',
    'KGZ','KHM','KNA','KOR','KWT','CYM','KAZ','LAO','LBN','LCA','LKA','LBR','LTU','LUX','LVA',
    'LBY','MAR','MDA','MNE','MDG','MKD','MLI','MMR','MNG','MAC','MRT','MSR','MLT','MUS','MDV',
    'MWI','MEX','MYS','MOZ','NAM','NER','NIC','NLD','NOR','NPL','NRU','NZL','OMN','PAN','PER',
    'PNG','PHL','POL','PRT','PLW','PRY','QAT','ROU','SRB','RWA','SAU','SLB','SYC','SWE','SGP',
    'SVN','SVK','SLE','SEN','SUR','STP','SLV','SWZ','TCA','TCD','THA','TJK','TKM','TUN','TON',
    'TTO','TWN','TZA','UKR','UGA','USA','URY','UZB','VCT','VEN','VGB','VNM','VUT','XKS','YEM',
    'ZAF','ZMB','ZWE'
  ]::text[]) then
    return 'premium_ai_coach';
  end if;

  return 'not_for_sale';
end
$$;

revoke all on function public.bil_market_plan_for_store_country(text)
  from public;
grant execute on function public.bil_market_plan_for_store_country(text)
  to anon, authenticated, service_role;

commit;
