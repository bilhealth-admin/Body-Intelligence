create table if not exists public.bil_food_translation_cache (
  source_locale text not null,
  target_locale text not null,
  source_text text not null,
  translated_text text not null,
  provider text not null,
  updated_at timestamptz not null default now(),
  primary key (source_locale, target_locale, source_text),
  constraint bil_food_translation_cache_source_locale_check
    check (source_locale ~ '^[a-z]{2}(-[A-Z][a-z]{3})?$'),
  constraint bil_food_translation_cache_target_locale_check
    check (target_locale ~ '^[a-z]{2}(-[A-Z][a-z]{3})?$'),
  constraint bil_food_translation_cache_source_text_check
    check (char_length(source_text) between 2 and 240),
  constraint bil_food_translation_cache_translated_text_check
    check (char_length(translated_text) between 2 and 240)
);

alter table public.bil_food_translation_cache enable row level security;
revoke all on table public.bil_food_translation_cache from public, anon, authenticated;
grant select, insert, update on table public.bil_food_translation_cache to service_role;

comment on table public.bil_food_translation_cache is
  'Server-only cache of food catalog labels translated by the BIL food-search Edge Function. No account, health, or query identity is stored.';
