begin;

-- Versioned standard Gemini 3.7 Flash rates for the direct Gemini API.
-- Keep the introductory 2026 rate bounded so future price changes cannot be
-- silently applied to historical receipts.
insert into public.bil_vision_model_pricing(
  provider, model, policy_version, effective_from, effective_to,
  input_usd_per_million_tokens, output_usd_per_million_tokens,
  source_reference
) values
(
  'gemini', 'gemini-3.7-flash', 'google-ai-pricing-2026-09-15',
  '2026-09-15T00:00:00Z', '2027-01-01T00:00:00Z', 0.75, 3.75,
  'https://ai.google.dev/gemini-api/docs/pricing'
),
(
  'gemini', 'gemini-3.7-flash', 'google-ai-pricing-2027-01-01',
  '2027-01-01T00:00:00Z', null, 1.50, 7.50,
  'https://ai.google.dev/gemini-api/docs/pricing'
)
on conflict (provider, model, policy_version) do update set
  effective_from = excluded.effective_from,
  effective_to = excluded.effective_to,
  input_usd_per_million_tokens = excluded.input_usd_per_million_tokens,
  output_usd_per_million_tokens = excluded.output_usd_per_million_tokens,
  source_reference = excluded.source_reference;

commit;
