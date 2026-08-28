# BIL AI Coach completion audit — 2026-08-20

## Scope and release boundary

This audit covers the approved AI Coach rebuild and its authorized Supabase /
Gemini production verification. The database migrations and Edge Function are
deployed and the paid smoke test passed. No application build was run. Actual
closed-tester provisioning remains pending their email addresses or user IDs.

## Requirement evidence

| Requirement | Authoritative evidence | Status |
| --- | --- | --- |
| Closed-test access is server-issued and auditable | deployed migrations `20260820115847` and `20260820172843`; remote ACL/RLS proof; live grant | Deployed and verified |
| No silent Gemini fallback or false charging | `server.ts` reservation/settlement states; service-status UI; Deno refund and consent tests | Deployed and verified |
| Multi-turn conversation with bounded history | `local_model_gateway_io.dart`; conversation/routing tests; server message bounds | Complete locally |
| Canonical Body Twin / Truth Engine context | `coach_context_provider.dart`, `coach_context_snapshot.dart`; minimal-view tests | Complete locally |
| Memory and safe tools require confirmation | `bil_tool_registry.dart`, `local_coach_api.dart`; tool-parity and confirmation contracts | Complete locally |
| Feedback is correlated to a real cloud response without storing conversation text | response ID propagation plus migration feedback RPC; successful live feedback UUID | Deployed and verified |
| Automatic localized welcome | `intelligence_center_page.dart` invokes device TTS for a new/reset conversation | Complete locally |
| “How much do I weigh?” speaks a wait acknowledgement and writes the local record | speech policy plus local latest-weight answer; Arabic and Spanish engine tests | Complete locally |
| Weight analysis is not replaced by the latest-weight shortcut | explicit engine regression for “Why is my weight stable?” | Complete locally |
| “How much should I sleep?” is answered directly in under ten seconds | deterministic local 7–9-hour answer; no model call test; 25-locale duration test | Complete locally |
| Long goal analysis speaks an immediate acknowledgement and writes recommendations | goal-analysis policy and page acknowledgement/write path | Complete locally |
| Male profile selects coach voice; female profile selects coach voice | profile-gender resolver, Dart channel test, Android and iOS bridge contracts | Complete locally; device voice availability remains OS-dependent |
| Speech and writing remain language-specific across all 25 release locales | 75-question weight/sleep/goal routing matrix; 831-source fallback audit | Complete locally |
| Text, voice, and image quota/cost behavior is explicit | cost audit; settings copy; live usage ledger settlement | Deployed and verified |

## Verification snapshot

- Flutter AI Coach tests: **66 passed, 0 failed**.
- Edge Function Deno tests: **11 passed, 0 failed**.
- Targeted Flutter analysis: **no issues found**.
- Localization audit: **831 required sources**, **2,293 catalog sources**,
  no missing sources, no direct English fallbacks, no Android locale failures.
- Supabase linked schema lint: one pre-existing unrelated warning in
  `public.bil_register_push_token` for unused parameter
  `p_sensitive_preview_allowed`.
- No Flutter/Android/iOS application build was run.
- Database migrations `20260820115847` and `20260820172843` are applied; final
  dry run is up to date with zero pending migrations.
- Remote proof confirms RLS on grants and feedback, no anonymous table/RPC
  access, authenticated self-read/feedback access, and service-role-only grant
  and consent-check execution.
- `ai-coach` is `ACTIVE`, version **16**.
- Live request `coachlivec7913faf66354cfe8f2a641835f4ae11` succeeded on
  `gemini-2.5-flash`: 561 input tokens, 308 billed output tokens, 2,586 ms,
  `$0.00093830`, quota `used=1`, `reserved=0`.
- The repeated request returned HTTP 409 without a second debit; feedback was
  accepted against the same response ID.
- The test session was globally revoked, the ephemeral user was deleted, and
  an independent database query confirmed zero remaining user, usage, and
  feedback rows.

## Remaining external input

Provision the actual closed testers after receiving their email addresses or
Supabase user IDs. The server path itself is deployed and verified; no shared
client-side access code is used.
