begin;

create extension if not exists pg_trgm with schema extensions;

alter table public.bil_community_food_submissions
  add column if not exists client_food_id text,
  add column if not exists serving_amount numeric,
  add column if not exists serving_unit text,
  add column if not exists sugar_g numeric,
  add column if not exists potassium_mg numeric,
  add column if not exists calcium_mg numeric,
  add column if not exists magnesium_mg numeric,
  add column if not exists phosphorus_mg numeric,
  add column if not exists iron_mg numeric,
  add column if not exists vitamin_c_mg numeric,
  add column if not exists nutrient_evidence_mask integer not null default 0,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists withdrawn_at timestamptz;

create unique index if not exists bil_food_contributor_client_id_uq
  on public.bil_community_food_submissions (contributor_id, client_food_id)
  where client_food_id is not null;

create index if not exists bil_food_live_search_trgm_idx
  on public.bil_community_food_submissions using gin (
    (lower(
      canonical_name || ' ' ||
      coalesce(brand, '') || ' ' ||
      localized_names::text || ' ' ||
      aliases::text
    )) extensions.gin_trgm_ops
  )
  where withdrawn_at is null
    and product_kind in ('food', 'beverage', 'alcohol');

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'bil_food_submission_serving_unit_check'
  ) then
    alter table public.bil_community_food_submissions
      add constraint bil_food_submission_serving_unit_check check (
        serving_unit is null or (
          char_length(serving_unit) between 1 and 24 and
          serving_unit !~ '[[:cntrl:]]'
        )
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'bil_food_submission_client_food_id_check'
  ) then
    alter table public.bil_community_food_submissions
      add constraint bil_food_submission_client_food_id_check check (
        client_food_id is null or client_food_id ~
          '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'bil_food_submission_live_values_check'
  ) then
    alter table public.bil_community_food_submissions
      add constraint bil_food_submission_live_values_check check (
        (serving_amount is null or serving_amount between 0.01 and 100000) and
        (calories_kcal is null or calories_kcal between 0 and 10000) and
        (protein_g is null or protein_g between 0 and 5000) and
        (carbohydrate_g is null or carbohydrate_g between 0 and 5000) and
        (fat_g is null or fat_g between 0 and 5000) and
        (fiber_g is null or fiber_g between 0 and 5000) and
        (sugar_g is null or sugar_g between 0 and 5000) and
        (sodium_mg is null or sodium_mg between 0 and 1000000) and
        (potassium_mg is null or potassium_mg between 0 and 1000000) and
        (calcium_mg is null or calcium_mg between 0 and 1000000) and
        (magnesium_mg is null or magnesium_mg between 0 and 1000000) and
        (phosphorus_mg is null or phosphorus_mg between 0 and 1000000) and
        (iron_mg is null or iron_mg between 0 and 1000000) and
        (vitamin_c_mg is null or vitamin_c_mg between 0 and 1000000) and
        nutrient_evidence_mask between 0 and 2147483647
      );
  end if;
end $$;

create or replace function public.bil_upsert_community_food_contribution(
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_submission_id uuid;
  v_client_food_id text := nullif(trim(p_payload->>'client_food_id'), '');
  v_name text := nullif(trim(p_payload->>'canonical_name'), '');
  v_serving_amount numeric := nullif(p_payload->>'serving_amount', '')::numeric;
  v_serving_unit text := lower(coalesce(nullif(trim(p_payload->>'serving_unit'), ''), 'g'));
  v_mask integer := coalesce(nullif(p_payload->>'nutrient_evidence_mask', '')::integer, 0);
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;
  if v_client_food_id is null or v_client_food_id !~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    raise exception 'invalid_client_food_id';
  end if;
  if v_name is null or char_length(v_name) not between 2 and 180 then
    raise exception 'invalid_food_name';
  end if;
  if v_serving_amount is null or v_serving_amount <= 0 then
    raise exception 'invalid_serving_amount';
  end if;
  insert into public.bil_community_food_submissions (
    contributor_id, client_food_id, canonical_name, localized_names, aliases,
    barcode, serving_grams, serving_amount, serving_unit,
    calories_kcal, protein_g, carbohydrate_g, fat_g, fiber_g, sugar_g,
    sodium_mg, potassium_mg, calcium_mg, magnesium_mg, phosphorus_mg,
    iron_mg, vitamin_c_mg, nutrient_evidence_mask, product_kind,
    submission_source, submission_confidence, status, updated_at, withdrawn_at
  ) values (
    v_user_id,
    v_client_food_id,
    v_name,
    coalesce(p_payload->'localized_names', '{}'::jsonb),
    coalesce(p_payload->'aliases', '[]'::jsonb),
    nullif(regexp_replace(coalesce(p_payload->>'barcode', ''), '[^0-9]', '', 'g'), ''),
    case when v_serving_unit = 'g' then v_serving_amount else null end,
    v_serving_amount,
    v_serving_unit,
    nullif(p_payload->>'calories_kcal', '')::numeric,
    nullif(p_payload->>'protein_g', '')::numeric,
    nullif(p_payload->>'carbohydrate_g', '')::numeric,
    nullif(p_payload->>'fat_g', '')::numeric,
    nullif(p_payload->>'fiber_g', '')::numeric,
    nullif(p_payload->>'sugar_g', '')::numeric,
    nullif(p_payload->>'sodium_mg', '')::numeric,
    nullif(p_payload->>'potassium_mg', '')::numeric,
    nullif(p_payload->>'calcium_mg', '')::numeric,
    nullif(p_payload->>'magnesium_mg', '')::numeric,
    nullif(p_payload->>'phosphorus_mg', '')::numeric,
    nullif(p_payload->>'iron_mg', '')::numeric,
    nullif(p_payload->>'vitamin_c_mg', '')::numeric,
    v_mask,
    'food', 'user_created_food', 'low', 'pending', now(), null
  )
  on conflict (contributor_id, client_food_id) where client_food_id is not null
  do update set
    canonical_name = excluded.canonical_name,
    localized_names = excluded.localized_names,
    aliases = excluded.aliases,
    barcode = excluded.barcode,
    serving_grams = excluded.serving_grams,
    serving_amount = excluded.serving_amount,
    serving_unit = excluded.serving_unit,
    calories_kcal = excluded.calories_kcal,
    protein_g = excluded.protein_g,
    carbohydrate_g = excluded.carbohydrate_g,
    fat_g = excluded.fat_g,
    fiber_g = excluded.fiber_g,
    sugar_g = excluded.sugar_g,
    sodium_mg = excluded.sodium_mg,
    potassium_mg = excluded.potassium_mg,
    calcium_mg = excluded.calcium_mg,
    magnesium_mg = excluded.magnesium_mg,
    phosphorus_mg = excluded.phosphorus_mg,
    iron_mg = excluded.iron_mg,
    vitamin_c_mg = excluded.vitamin_c_mg,
    nutrient_evidence_mask = excluded.nutrient_evidence_mask,
    submission_source = excluded.submission_source,
    submission_confidence = 'low',
    status = 'pending',
    reviewed_at = null,
    review_note = null,
    updated_at = now(),
    withdrawn_at = null
  returning id into v_submission_id;

  return v_submission_id;
end;
$$;

create or replace function public.bil_withdraw_community_food_contribution(
  p_client_food_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  update public.bil_community_food_submissions
  set withdrawn_at = now(), updated_at = now()
  where contributor_id = auth.uid()
    and client_food_id = p_client_food_id
    and withdrawn_at is null;

  return found;
end;
$$;

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
  select
    s.id,
    s.canonical_name,
    s.localized_names,
    s.aliases,
    s.barcode,
    coalesce(s.serving_amount, s.serving_grams, 100),
    coalesce(s.serving_unit, 'g'),
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
    (s.status = 'approved'),
    s.updated_at
  from public.bil_community_food_submissions s
  where s.withdrawn_at is null
    and s.status in ('pending', 'approved')
    and s.product_kind in ('food', 'beverage', 'alcohol')
    and s.serving_amount is not null
    and (
      lower(s.canonical_name) like '%' || v_query || '%' or
      lower(coalesce(s.brand, '')) like '%' || v_query || '%' or
      lower(s.localized_names::text) like '%' || v_query || '%' or
      lower(s.aliases::text) like '%' || v_query || '%' or
      similarity(
        lower(s.canonical_name || ' ' || coalesce(s.brand, '')),
        v_query
      ) >= 0.30
    )
  order by
    (s.status = 'approved') desc,
    (lower(s.canonical_name) = v_query) desc,
    (lower(s.canonical_name) like v_query || '%') desc,
    similarity(lower(s.canonical_name), v_query) desc,
    s.updated_at desc
  limit v_limit;
end;
$$;

revoke all on function public.bil_upsert_community_food_contribution(jsonb)
  from public, anon;
revoke all on function public.bil_withdraw_community_food_contribution(text)
  from public, anon;
revoke all on function public.bil_search_community_foods(text, integer)
  from public, anon;

grant execute on function public.bil_upsert_community_food_contribution(jsonb)
  to authenticated;
grant execute on function public.bil_withdraw_community_food_contribution(text)
  to authenticated;
grant execute on function public.bil_search_community_foods(text, integer)
  to authenticated;

commit;

;
