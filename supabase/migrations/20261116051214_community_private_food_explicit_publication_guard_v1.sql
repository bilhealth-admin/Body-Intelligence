-- Ordinary private food saves in older clients called this legacy RPC without
-- a food-specific Community choice. Stop new implicit contributions, and keep
-- existing automatic/unknown-source rows out of public discovery without
-- deleting or rewriting them. Their owner and authorized moderation paths stay.
-- user_submission is the existing explicit food/product-review source; this
-- source-based precaution does not assert individual consent for historical
-- rows backfilled with that default. Official food catalog data is unchanged.
begin;

do $community_food_privacy_precondition$
begin
  if pg_catalog.to_regprocedure('public.bil_upsert_community_food_contribution(jsonb)') is null
     or pg_catalog.to_regprocedure('public.bil_search_community_foods(text,integer)') is null
     or pg_catalog.to_regprocedure('public.bil_community_profile_reviews_v1(uuid,timestamptz,uuid,integer)') is null
     or not exists (
       select 1 from pg_catalog.pg_policies
       where schemaname='public' and tablename='bil_community_food_submissions'
         and policyname='bil_food_read' and cmd='SELECT'
         and roles=array['authenticated']::name[]
     ) then
    raise exception 'community_food_privacy_baseline_missing' using errcode='55000';
  end if;
end;
$community_food_privacy_precondition$;

-- CREATE OR REPLACE keeps the existing uuid signature, owner and EXECUTE ACL.
-- No client-supplied boolean or source label can authorize this retired route.
create or replace function public.bil_upsert_community_food_contribution(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
begin
  raise exception 'explicit_community_submission_required' using errcode='42501';
end;
$function$;

-- Preserve private owner access, including pending/withdrawn legacy records.
-- Only approved explicit-source records are visible to other regular users.
alter policy bil_food_read on public.bil_community_food_submissions
using (
  contributor_id = (select auth.uid())
  or (
    status = 'approved'
    and submission_source = 'user_submission'
    and withdrawn_at is null
  )
);

create or replace function public.bil_search_community_foods(
  p_query text,
  p_limit integer default 10
)
returns table (
  id uuid,
  canonical_name text,
  localized_names jsonb,
  aliases jsonb,
  barcode text,
  serving_amount numeric,
  serving_unit text,
  calories_kcal numeric,
  protein_g numeric,
  carbohydrate_g numeric,
  fat_g numeric,
  fiber_g numeric,
  sugar_g numeric,
  sodium_mg numeric,
  potassium_mg numeric,
  calcium_mg numeric,
  magnesium_mg numeric,
  phosphorus_mg numeric,
  iron_mg numeric,
  vitamin_c_mg numeric,
  nutrient_evidence_mask integer,
  status text,
  verified boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_query text := lower(trim(coalesce(p_query, '')));
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 20);
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if char_length(v_query) < 2 then
    return;
  end if;

  return query
  with candidates as (
    select
      s.id,
      s.canonical_name,
      s.localized_names,
      s.aliases,
      s.barcode,
      coalesce(s.serving_amount, s.serving_grams, 100) as serving_amount,
      coalesce(s.serving_unit, 'g') as serving_unit,
      s.calories_kcal,
      s.protein_g,
      s.carbohydrate_g,
      s.fat_g,
      s.fiber_g,
      s.sugar_g,
      s.sodium_mg,
      s.potassium_mg,
      s.calcium_mg,
      s.magnesium_mg,
      s.phosphorus_mg,
      s.iron_mg,
      s.vitamin_c_mg,
      s.nutrient_evidence_mask,
      s.status,
      (s.status = 'approved') as verified,
      s.updated_at,
      lower(s.canonical_name || ' ' || coalesce(s.brand, '') || ' ' ||
        s.localized_names::text || ' ' || s.aliases::text) as search_text
    from public.bil_community_food_submissions s
    where s.withdrawn_at is null
      and s.status = 'approved'
      and s.submission_source = 'user_submission'
      and s.product_kind in ('food', 'beverage', 'alcohol')
      and s.serving_amount is not null

    union all

    select
      f.id,
      f.canonical_name,
      f.localized_names,
      f.aliases,
      null::text as barcode,
      f.serving_amount,
      f.serving_unit,
      f.calories_kcal,
      f.protein_g,
      f.carbohydrate_g,
      f.fat_g,
      f.fiber_g,
      f.sugar_g,
      f.sodium_mg,
      f.potassium_mg,
      f.calcium_mg,
      f.magnesium_mg,
      f.phosphorus_mg,
      f.iron_mg,
      f.vitamin_c_mg,
      f.nutrient_evidence_mask,
      'approved'::text as status,
      true as verified,
      f.updated_at,
      lower(f.canonical_name || ' ' || f.localized_names::text || ' ' ||
        f.aliases::text) as search_text
    from public.bil_official_food_catalog f
  )
  select
    c.id, c.canonical_name, c.localized_names, c.aliases, c.barcode,
    c.serving_amount, c.serving_unit, c.calories_kcal, c.protein_g,
    c.carbohydrate_g, c.fat_g, c.fiber_g, c.sugar_g, c.sodium_mg,
    c.potassium_mg, c.calcium_mg, c.magnesium_mg, c.phosphorus_mg,
    c.iron_mg, c.vitamin_c_mg, c.nutrient_evidence_mask, c.status,
    c.verified, c.updated_at
  from candidates c
  where c.search_text like '%' || v_query || '%'
     or similarity(c.search_text, v_query) >= 0.30
  order by
    c.verified desc,
    exists (
      select 1 from jsonb_each_text(c.localized_names) localized
      where lower(localized.value) = v_query
    ) desc,
    exists (
      select 1 from jsonb_array_elements_text(c.aliases) alias
      where lower(alias) = v_query
    ) desc,
    (lower(c.canonical_name) = v_query) desc,
    (c.search_text like v_query || '%') desc,
    similarity(c.search_text, v_query) desc,
    c.updated_at desc
  limit v_limit;
end;
$$;

create or replace function public.bil_community_profile_reviews_v1(
  p_user_id uuid,
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 24
)
returns table(
  review_id uuid,
  product_kind text,
  canonical_name text,
  brand text,
  review_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_viewer uuid:=(select auth.uid());
  v_profile public.bil_public_profiles%rowtype;
begin
  if v_viewer is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_user_id is null
     or (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>60 then
    raise exception 'invalid_profile_reviews_request' using errcode='22023';
  end if;

  select * into v_profile
  from public.bil_public_profiles p
  where p.user_id=p_user_id;
  if not found then
    raise exception 'community_profile_not_found' using errcode='P0002';
  end if;
  if p_user_id<>v_viewer
     and (not public.bil_social_profile_visible_v2(p_user_id)
       or not v_profile.show_posts) then
    return;
  end if;

  return query
  select s.id,s.product_kind,s.canonical_name,s.brand,s.review_note,s.created_at
  from public.bil_community_food_submissions s
  where s.contributor_id=p_user_id
    and s.status='approved'
    and s.submission_source='user_submission'
    and s.withdrawn_at is null
    and (p_before is null or (s.created_at,s.id)<(p_before,p_before_id))
  order by s.created_at desc,s.id desc
  limit p_limit;
end
$$;

commit;
