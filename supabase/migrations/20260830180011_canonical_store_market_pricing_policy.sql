begin;

-- Canonical owner-approved store split and pricing-policy alignment
-- (2026-08-29). This migration supersedes the active market assignment from
-- 20260828220000 without rewriting migration history:
--   * EG, IN, PK, and TR sell Premium only.
--   * The remaining 168 Apple launch markets sell Premium + AI Coach.
--   * Unknown and held markets fail closed.
update public.bil_commerce_country_policy
set sale_enabled = false,
    policy_version = '2026-08-29-v3',
    classification_reason = 'not_in_canonical_sale_market_allowlist',
    updated_at = now();

insert into public.bil_commerce_country_policy(
  country_code, market_class, target_plan, classification_reason,
  policy_version, sale_enabled
)
select code, 'token_only', 'premium',
  'owner_canonical_premium_only_market_2026_08_29',
  '2026-08-29-v3', true
from unnest(array['EG','IN','PK','TR']::text[]) code
on conflict (country_code) do update set
  market_class = excluded.market_class,
  target_plan = excluded.target_plan,
  classification_reason = excluded.classification_reason,
  policy_version = excluded.policy_version,
  sale_enabled = excluded.sale_enabled,
  updated_at = now();

insert into public.bil_commerce_country_policy(
  country_code, market_class, target_plan, classification_reason,
  policy_version, sale_enabled
)
select code, 'profitable', 'premium_ai_coach',
  'owner_canonical_all_other_sale_markets_ai_2026_08_29',
  '2026-08-29-v3', true
from unnest(array[
  'AE','AF','AG','AI','AL','AM','AO','AR','AT','AU','AZ','BA','BB','BE','BF',
  'BG','BH','BJ','BM','BN','BO','BR','BS','BT','BW','BZ','CA','CD','CG','CH',
  'CI','CL','CM','CO','CR','CV','CY','CZ','DE','DK','DM','DO','DZ','EC','EE',
  'ES','FI','FJ','FM','FR','GA','GB','GD','GE','GH','GM','GR','GT','GW','GY',
  'HK','HN','HR','HU','ID','IE','IL','IQ','IS','IT','JM','JO','JP','KE','KG',
  'KH','KN','KR','KW','KY','KZ','LA','LB','LC','LK','LR','LT','LU','LV','LY',
  'MA','MD','ME','MG','MK','ML','MM','MN','MO','MR','MS','MT','MU','MV','MW',
  'MX','MY','MZ','NA','NE','NG','NI','NL','NO','NP','NR','NZ','OM','PA','PE',
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

  if v_code = any(array['EGY','IND','PAK','TUR']::text[]) then
    return 'premium';
  end if;
  if v_code = any(array[
    'ARE','AFG','ATG','AIA','ALB','ARM','AGO','ARG','AUT','AUS','AZE','BIH','BRB','BEL','BFA',
    'BGR','BHR','BEN','BMU','BRN','BOL','BRA','BHS','BTN','BWA','BLZ','CAN','COD','COG','CHE',
    'CIV','CHL','CMR','COL','CRI','CPV','CYP','CZE','DEU','DNK','DMA','DOM','DZA','ECU','EST',
    'ESP','FIN','FJI','FSM','FRA','GAB','GBR','GRD','GEO','GHA','GMB','GRC','GTM','GNB','GUY',
    'HKG','HND','HRV','HUN','IDN','IRL','ISR','IRQ','ISL','ITA','JAM','JOR','JPN','KEN','KGZ',
    'KHM','KNA','KOR','KWT','CYM','KAZ','LAO','LBN','LCA','LKA','LBR','LTU','LUX','LVA','LBY',
    'MAR','MDA','MNE','MDG','MKD','MLI','MMR','MNG','MAC','MRT','MSR','MLT','MUS','MDV','MWI',
    'MEX','MYS','MOZ','NAM','NER','NGA','NIC','NLD','NOR','NPL','NRU','NZL','OMN','PAN','PER',
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
