# BIL AI Coach usage and cost audit — 2026-08-20

## Unified BIL AI Token observatory — 2026-08-21

The closed-test owner is evaluating replacing separate text, vision, and voice
allowances with one weekly balance. Production telemetry now reports a common
`BIL AI Token` alongside provider tokens and USD cost:

- `1 BIL AI Token = USD 0.0001` of recorded provider cost.
- A successful provider request is rounded up to the next whole BIL AI Token.
- Local deterministic answers, on-device speech recognition, and device TTS
  remain zero-token operations.
- The observatory reports 7, 30, and 365-day aggregates without storing or
  returning prompt, health-context, transcript, or answer text.

The current production sample contains real successful calls across all three
provider-backed modalities:

| Modality / model | Calls | Avg input | Avg billed output | Avg USD | Avg BIL AI Tokens |
| --- | ---: | ---: | ---: | ---: | ---: |
| Text / Gemini 3.7 Flash HIGH | 5 | 1,490 | 1,253 | 0.00581775 | 58.6 |
| Voice / Gemini 3.7 Flash HIGH | 7 | 1,892 | 975 | 0.00507643 | 51.14 |
| Vision / Gemini 2.5 Flash | 2 | 1,266 | 460 | 0.00152855 | 15.29 |

The seven voice calls averaged 8.3 recorded seconds. Their observed combined
transcription-and-answer cost was USD 0.03676034 per audio minute. Google
documents audio input at 32 provider tokens per second; BIL continues to use
returned `usageMetadata` and recorded USD cost as the billing authority.

### Closed-test enforcement baseline

The unified ledger is now enforced at **5,000 BIL AI Tokens per week** for an
active AI Coach subscription. It caps recorded provider spend at USD 0.50 per
fully used user-week. At the current observed averages, that balance corresponds
to about 86 high-thinking text turns, 98 short voice turns, or 327 vision
analyses when used entirely on one modality. Actual users can mix all three.

This is an approved technical closed-test limit, not an approved store price or
final commercial allowance. Monthly and annual distribution and subscription
prices remain deliberately unset until country taxes, store fees, US tax,
provider usage variance, and competitor pricing are modeled together.

## Superseding production measurement — 2026-08-21

The modern Coach now routes every cloud text turn to `gemini-3.7-flash` with
high thinking. The default telemetry rate is $0.75 per 1M input tokens and
$3.75 per 1M billed output tokens. Local deterministic facts and the Daily
Brief still cost zero provider tokens.

The single authorized post-deployment production check recorded:

| Field | Recorded value |
| --- | ---: |
| Model | `gemini-3.7-flash` |
| Input tokens | 724 |
| Billed output tokens (visible + thinking) | 735 |
| Provider latency | 8,321 ms |
| Recorded cost | **$0.00329925** |
| BIL text quota | used 1, reserved 0 |

Formula verification:

`(724 × $0.75 + 735 × $3.75) / 1,000,000 = $0.00329925`

The duplicate request was rejected with HTTP 409 without a second Gemini
call or debit. The synthetic session was revoked, the user was deleted, and
cascade verification found zero remaining rows. Weekly, monthly, and annual
aggregates are now exposed to each signed-in user by
`bil_get_ai_coach_cost_observatory()` without storing prompt or reply text.

This is one measured shape, so it is sufficient to verify accounting but not
to set final consumer allowances. Quotas should be calibrated after collecting
a representative mix of short questions, longitudinal analyses, and voice
turns in closed testing.

This audit covers the deployed code paths and includes one authorized live
Gemini measurement. Planning ranges remain estimates for other request shapes.

## What consumes the BIL allowance

| User action | BIL allowance debit | Gemini/provider effect |
| --- | ---: | --- |
| Local fact or deterministic tool, such as the latest recorded weight | 0 | No provider call |
| Typed Coach question that needs Gemini | Actual BIL AI Tokens from recorded USD cost | One text generation call |
| Spoken Coach question with global voice enabled | Actual BIL AI Tokens from recorded USD cost | One audio-understanding and answer call; language is detected by Gemini |
| Automatic spoken welcome, acknowledgement, or short answer | 0 voice minutes | Android `TextToSpeech` / iOS `AVSpeechSynthesizer`; no Gemini TTS call |
| New meal photo analysis | Actual BIL AI Tokens from recorded USD cost | One multimodal generation call, subject to bounded retry |
| Exact previously successful meal photo | 0 | Cached response; no new provider call |

The configured closed-test allowance is one shared weekly balance of 5,000 BIL
AI Tokens. Text, global voice, and Vision stop together when the combined weekly
and non-expiring Boost balances are exhausted. Local answers and device TTS do
not draw from the balance.

## Paid Gemini rates represented in code

The default text routing is intentionally separate from Vision:

- Simple text: `gemini-2.5-flash-lite` — $0.10 per 1M input tokens and $0.40 per
  1M output tokens.
- Personal analysis and meal Vision: `gemini-2.5-flash` — $0.30 per 1M
  text/image input tokens and $2.50 per 1M output tokens.
- Output cost includes thinking tokens. Telemetry therefore stores visible
  output plus `thoughtsTokenCount` as billed output.

Formula:

`USD = (input_tokens × input_rate + billed_output_tokens × output_rate) / 1,000,000`

Sources:

- https://ai.google.dev/gemini-api/docs/pricing
- https://ai.google.dev/gemini-api/docs/tokens
- https://ai.google.dev/gemini-api/docs/thinking

## Practical estimates

These are planning ranges, not substitutes for the recorded `cost_usd` value:

| Request | Example token shape | Estimated paid-tier cost |
| --- | ---: | ---: |
| Short Flash-Lite answer | 1,000–3,000 input; 100–150 output | $0.00014–$0.00036 |
| Personalized Flash analysis | 3,000–6,000 input; 300–500 billed output | $0.00165–$0.00305 |
| Meal image at the app’s bounded resolution | roughly 1,158–3,222 input including prompt/image; 300–500 output | about $0.00110–$0.00222 |
| On-device speech around either text request | no provider audio tokens | $0 additional |

Google documents images at 258 tokens when both dimensions are at most 384
pixels; larger images are tiled into 768×768 regions at 258 tokens per tile.
BIL preprocesses meal photos to a maximum dimension of 1,600 pixels, so the
actual `usageMetadata` returned by Gemini is authoritative.

At typical usage, 125 text requests plus 25 image requests are roughly
$0.05–$0.44 per active user per week, depending mainly on how many questions
need personalized Flash analysis. This excludes free-tier effects. A transient
provider retry can create additional provider cost even when BIL refunds the
user-facing allowance, so provider attempts are recorded and capped at two.

## Cost controls implemented in this review

- Simple text no longer inherits the Vision model secret.
- Local questions are answered before Gemini when possible.
- Simple questions omit personal context from the provider prompt.
- Conversation history is capped at 12,000 characters and 12 turns.
- Provider output is capped at 512 tokens for simple answers and 1,536 for
  analysis.
- Spoken summaries are capped to approximately ten seconds.
- Visible output and thinking tokens are both included in cost telemetry.
- Every successful cloud response carries the metered request ID so feedback
  can be joined to model, latency, tokens, and cost without storing the health
  question or answer.

## Live production measurement

The authorized smoke test used a synthetic goal-analysis question and produced:

| Field | Recorded value |
| --- | ---: |
| Model | `gemini-2.5-flash` |
| Input tokens | 561 |
| Billed output tokens (visible + thinking) | 308 |
| Provider latency | 2,586 ms |
| Recorded cost | **$0.00093830** |
| BIL text quota | used 1, reserved 0 |

The value matches the implemented formula exactly:

`(561 × $0.30 + 308 × $2.50) / 1,000,000 = $0.00093830`

Reusing the same request ID returned HTTP 409 and did not create a second debit.
The synthetic user and all cascaded usage/feedback rows were removed after the
measurement.
