begin;

-- Versioned standard paid-tier rates for prompts <= 200k tokens from the
-- official Gemini Developer API pricing page, checked 2026-08-11.
insert into public.bil_vision_model_pricing(
  provider, model, policy_version, effective_from,
  input_usd_per_million_tokens, output_usd_per_million_tokens,
  source_reference
) values (
  'gemini', 'gemini-2.5-pro', 'google-ai-pricing-2026-08-11',
  '2026-08-11T00:00:00Z', 1.25, 10.00,
  'https://ai.google.dev/gemini-api/docs/pricing'
) on conflict (provider, model, policy_version) do update set
  input_usd_per_million_tokens = excluded.input_usd_per_million_tokens,
  output_usd_per_million_tokens = excluded.output_usd_per_million_tokens,
  source_reference = excluded.source_reference;

commit;
