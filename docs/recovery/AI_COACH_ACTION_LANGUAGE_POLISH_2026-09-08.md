# AI Coach action, language, and conversation polish closure — 2026-09-08

> Superseded operational state (2026-09-09): the audit-time v49/v50 discussion
> below remains historical. The current active function is `ai-coach` v51 with
> exact normalized parity to the five local bundle files. v51 adds explicit
> Gemini safety settings and fail-closed prompt/candidate safety handling; the
> Flutter client adds a dedicated, non-retryable safety state in all 25 locales.
> Deno 24/24 and focused Flutter 42/42 passed. Authenticated signed-device
> canaries remain required.

## Executive result

The eight supplied screenshots expose a real client/action-receipt defect, not a missing Supabase table or a failed data lookup. The Coach successfully read weight data, but a proposed navigation was rendered as conversational success before Flutter had opened a route. The same contract gap explains the visible `فتح الخطة` chip that did not open the plan until the user acted on it.

The local worktree now keeps model proposals separate from execution receipts, opens explicit safe read-only navigation requests through an allow-listed Flutter route, shows an in-progress state, and exposes an inline localized failure with retry. Sensitive or mutating actions still require confirmation. No live Edge Function, database, device build, store, purchase flow, or production data was changed.

## Screenshot evidence, in order

| Image | Observed behavior | Assessment |
| --- | --- | --- |
| 1 | The Arabic request `استعرض سجل اوزاني` received a correct weight summary, then the assistant said it had opened the weight-history page while the chat remained visible. `افتحها` then lost its referent, and a later weight-history request repeated the false success claim. | Retrieval worked; action parsing, referential follow-up, and navigation receipt were broken. |
| 2 | The conversation included real values such as 86.1 kg and roughly 7.1 kg remaining to goal. | The core read path was available; the failure was not lack of weight context. |
| 3 | A weekly diet request produced a plan response and an action affordance. | The assistant could propose a plan route, but proposal and execution semantics were not clear. |
| 4 | An English workout/nutrition exchange continued normally. | General answer generation was available. |
| 5 | A request to translate to Arabic caused an Arabic response. | Explicit language switching worked in this sequence. |
| 6 | `فتح الخطة` remained a chip and the user asked why the plan did not open. | Read-only navigation had been treated like a confirmation-gated proposal rather than an explicit open command. |
| 7 | Repeated workout questions were answered in English. | English response selection worked for clear English text. |
| 8 | Short `hi` received English. | The screenshot outcome was correct, but the pre-fix resolver did not recognize `hi`; it could fall back to the UI locale and therefore was not a dependable contract. |

The screenshots have no signed-build identifier or source revision. They therefore cannot be proven to come from the current worktree. Their behavior is, however, consistent with the pre-fix Flutter action flow used with live AI Coach v49.

## End-to-end root cause

1. The Edge response schema returns a **proposed action**. That object is not evidence that an effect happened.
2. The prior prompt told the model not to invent completion, but did not state a sufficiently explicit proposal-versus-receipt protocol. A model sentence could still say that a page had opened.
3. `open_weight_log` was mapped through a legacy `addWeight` path. With no numeric weight, Flutter opened `/daily-check-in`, not `/weight-history`.
4. Arabic plural wording such as `أوزاني` was not recognized by the local weight-history intent.
5. Safe navigation actions were persisted as chips. An explicit request to open a read-only page did not necessarily execute the route, and `افتحها` had no bounded contextual resolution.
6. Invalid navigation targets could return without an explicit per-action failure state. The UI had a generic snackbar but no durable inline retry on the original action.
7. The input-language resolver did not recognize short `hi`, did not remember the last clearly written language, and could choose Arabic merely because any Arabic script was present in mixed input.
8. The resolved question language was used for some local acknowledgement copy, but the original/null hint could still reach the remote generation path.

## Implemented closure

### Navigation and trustworthy receipts

- `open_weight_log` now resolves to a trusted `navigate` action with `target=weight_history`.
- Arabic plural weight-history commands and explicit English view/show-history commands resolve to the history route.
- Tested allow-listed destinations are:
  - weight history: `/weight-history`
  - plan: `/plan?origin=dashboard`
  - meals: `/daily-log?focus=meal`
  - workouts: `/wellness/workouts/log`
- A direct, explicit safe-navigation request is represented with pending copy and then dispatched by Flutter. Model prose is not used as a success receipt.
- The narrowly scoped follow-ups `open it` / `افتحها` and their reviewed variants can reuse only the immediately preceding trusted Coach navigation action. Older actions are never replayed by a pronoun.
- Navigation chips have running, failed, and retry states. A failed dispatch remains visible and retry executes the same trusted action.
- Confirmation behavior for sensitive, mutating, or destructive actions is unchanged. The auto-open policy rejects every confirmation-gated action.

### Response language and direction

- Clear written input determines the response language independently of the interface locale.
- Ambiguous typed input uses the last clearly detected written language, then the UI locale only as a fallback.
- Short `hi`, `hello`, and `hey` are explicitly English.
- Arabic/English mixed input uses reviewed dominance signals rather than treating one Arabic character as conclusive.
- An explicit speech-recognition BCP-47 language hint remains authoritative for spoken input.
- The effective language hint is propagated through the model gateway to the Edge contract.
- Message direction remains derived from the actual message text, so Arabic-script output is RTL and Latin-script output is LTR.

Flutter and the mobile OS do **not** expose a reliable cross-platform API for reading the user's currently active system keyboard language. `TextField.hintLocales` is a preference/hint for the input method, not a keyboard-language getter. This implementation therefore detects submitted text and remembers the last clear written language; it does not claim access to the system keyboard.

### Localized action-state copy

An AI-Coach-specific catalog supplies `navigationReady`, `opening`, `navigationFailed`, and `retry` for the exact 25 BIL production locale tags, including distinct `pt-BR` and `pt-PT` wording. It is independent from the Community catalogs.

### Architecture

The navigation executor and action execution phases were moved into the cohesive `intelligence_action_runtime.dart` part. `intelligence_center_page.dart` is now 698 lines, below the unchanged 700-line default ceiling. No architecture exception was added.

## Live v49 / HEAD / local matrix

Read-only commands used against project `tgmanzhqulksykhslrzb`:

```text
npx supabase functions list --project-ref tgmanzhqulksykhslrzb --output json
npx supabase functions download ai-coach --project-ref tgmanzhqulksykhslrzb --workdir <validated temporary audit directory>
```

The live function was active at version 49, function id `8484c037-8c77-498f-a621-434a04224b91`, with bundle digest `ezbr_sha256=24c0a8f88be1c1d94549ca22dd8a616f1cc7ca04bf1b52914a8ff4f83e735066`. `verify_jwt=false` is configured at the platform gateway while the function performs its own auth/integrity checks. The downloaded live `server.ts` SHA-256 was `4DD94AA5FBA786E26D59BE6529FFA9E79BF0CDB60F651DF111BEAB48CC601369`.

The audit-time committed HEAD is `99d464b8d0c4ef1989d1c73e68991a405ff7bf17` (`fix(db): restrict vision settlement execution`). The downloaded live v49 source was not byte-identical to committed HEAD. Before this task's prompt-only addition, the already-dirty local `server.ts` was byte-identical to live v49. The current uncommitted local `server.ts` SHA-256 is `D8C4B3FD57A232BD17C56087385C9B09D4E9135953654EDB0BECA9388BA4FD3F`; its deliberate difference from live is the proposal-versus-execution prompt contract and its test. It has **not** been deployed.

| Contract | Committed HEAD | Live Edge v49 | Current local uncommitted Flutter/Edge |
| --- | --- | --- | --- |
| Input language | Older committed behavior; not the source of the supplied screenshots with certainty. | Uses latest-message script/high-signal detection plus optional `language_hint`; ambiguous text can remain `auto`. | Flutter resolves clear typed/spoken input, `hi`, mixed Arabic/English, and last-clear written language, then sends an effective hint. |
| RTL/LTR | Existing message rendering contract. | Returns text; it does not control Flutter direction. | Flutter derives direction from each message's text. |
| Tool/action schema | Registry exists but the checked-out worktree contains extensive uncommitted evolution. | 22 allow-listed proposed action types. Parsed model actions are confirmation-gated until Flutter's trusted registry evaluates them. | Same allow-list boundary; `open_weight_log` maps to `weight_history`; proposals are explicitly not receipts. |
| Weight / plan / meals / workouts | No claim that committed HEAD contains this closure. | Can propose `open_weight_log`, `open_plan`, `open_meals`, and `open_workouts`; it cannot navigate a device. | Explicit safe open requests dispatch the four tested Flutter routes; failure/retry is visible. |
| Sensitive confirmation | Existing trusted-client confirmation boundary. | Proposed actions are normalized with `requires_confirmation=true`. | Trusted Flutter registry remains authoritative; confirmation-gated actions never auto-run. |
| Failure / retry | Generic request/action handling existed. | Two bounded attempts for transient provider errors. | Request retry remains, and navigation now has inline running/failure/retry state. |
| Streaming | Not established in the committed app contract. | Uses buffered Gemini `generateContent`, not SSE token streaming. | No false streaming claim. Existing delayed progress, cancel, and retry UX remains; real token streaming requires a coordinated Edge/client protocol change. |
| Moderation / health safety | Existing client safety and reporting code is present in the dirty worktree. | Prompt includes medical-red-flag and no-invent rules. No explicit `safetySettings` request or `promptFeedback` inspection was found. | No threshold change was made without a health-safety evaluation. Existing urgent/diagnosis guards, reaction/report affordances, and server prompt remain. |
| 25 BIL locales | Not claimed for this new copy. | Response language is driven by text/hint rather than a fixed UI-locale list. | Four static navigation-state strings are authored and mechanically verified for all 25 production locale tags. |

## Conversation UX research and decision

- Flutter's official optimistic-state guidance models running and error states and supports revert/retry; the action chip now follows that state model: [Optimistic state](https://docs.flutter.dev/app-architecture/design-patterns/optimistic-state).
- Flutter documents `ActionChip` as a contextual action that can expose progress/confirmation behavior: [ActionChip](https://api.flutter.dev/flutter/material/ActionChip-class.html).
- Route changes remain on Flutter's established navigation/go_router boundary: [Navigation and routing](https://docs.flutter.dev/ui/navigation).
- The existing reversed history, near-latest auto-follow, and jump-to-latest behavior was retained; it already follows the available list/history primitives: [ListView](https://api.flutter.dev/flutter/widgets/ListView-class.html).
- `hintLocales` only communicates expected languages to an input method and is not an active-keyboard query: [TextField.hintLocales](https://api.flutter.dev/flutter/material/TextField/hintLocales.html), [TextInputConfiguration](https://api.flutter.dev/flutter/services/TextInputConfiguration-class.html).
- Google ML Kit can classify a submitted text string with confidence but adds a separate dependency and does not expose the system keyboard. It was not needed for this bounded fix: [ML Kit language identification](https://developers.google.com/ml-kit/language/identification), [Android language identification behavior](https://developers.google.com/ml-kit/language/identification/android).
- Gemini distinguishes buffered `generateContent` from `streamGenerateContent`; introducing real SSE would require a versioned Edge/mobile protocol and was intentionally not simulated: [Gemini text generation and streaming](https://ai.google.dev/gemini-api/docs/generate-content/text-generation?hl=en), [Structured output streaming](https://ai.google.dev/gemini-api/docs/generate-content/structured-output?hl=en).
- Gemini documents explicit safety settings, blocked-result metadata, and post-processing/evaluation responsibilities. Because BIL is a health product, no safety threshold was changed without a dedicated evaluation: [Safety settings](https://ai.google.dev/gemini-api/docs/safety-settings?authuser=01&hl=en), [Safety and factuality guidance](https://ai.google.dev/gemini-api/docs/safety-guidance?authuser=0&hl=en).
- Supabase supports streamed Edge responses, but both the audit-time v49 and
  current v51 contracts are buffered: [Edge Functions](https://supabase.com/docs/guides/functions), [Edge Function resource monitoring](https://supabase.com/docs/guides/troubleshooting/edge-function-monitoring-resource-usage).

## Verification

All commands were run from `G:\BIL_Project\worktrees\bil-community-policy-recovery-20260908` after the final architecture split.

| Gate | Result |
| --- | --- |
| `flutter test test/features/intelligence_center` | **196 passed, 0 failed** |
| `flutter test test/architecture_source_file_size_guard_test.dart` | **1 passed, 0 failed** |
| `flutter analyze lib/features/intelligence_center` | **No issues found** |
| `deno test --allow-env supabase/functions/ai-coach/server_test.ts supabase/functions/ai-coach/mobile_integrity_test.ts` | **22 passed, 0 failed** (21 server contract tests + 1 integrity-guard test) |

Coverage includes all 25 locale entries, Portuguese regional separation, short `hi`, last-clear-language retention, clear-language override, Arabic/English mixed input, typed and spoken hints, safe versus sensitive actions, Arabic plural weight history, the weight/plan/meals/workout route matrix, an explicit `open it` follow-up, navigation running state, injected navigation failure, inline error, and successful retry. No Golden or signed-device test was run under this task's boundary.

## Files changed by this task

New files:

- `lib/features/intelligence_center/ai_coach_chat_copy.dart`
- `lib/features/intelligence_center/presentation/intelligence_action_runtime.dart`
- `lib/features/intelligence_center/services/coach_action_presentation_policy.dart`
- `test/features/intelligence_center/ai_coach_chat_copy_test.dart`
- `test/features/intelligence_center/coach_action_presentation_policy_test.dart`
- `test/features/intelligence_center/ai_coach_navigation_receipt_test.dart`
- `docs/recovery/AI_COACH_ACTION_LANGUAGE_POLISH_2026-09-08.md`

Existing files with task-owned hunks:

- `lib/features/intelligence_center/services/coach_language_resolver.dart`
- `lib/features/intelligence_center/domain/bil_tool_registry.dart`
- `lib/features/intelligence_center/services/local_coach_api.dart`
- `lib/features/intelligence_center/services/local_coach_command_parser.dart`
- `lib/features/intelligence_center/presentation/intelligence_center_page.dart`
- `lib/features/intelligence_center/presentation/intelligence_query_flow.dart`
- `lib/features/intelligence_center/presentation/intelligence_action_flow.dart`
- `lib/features/intelligence_center/presentation/intelligence_center_message_widgets.dart`
- `lib/features/intelligence_center/presentation/intelligence_conversation_persistence.dart`
- `supabase/functions/ai-coach/server.ts`
- `supabase/functions/ai-coach/server_test.ts`
- `test/features/intelligence_center/coach_language_resolver_test.dart`
- `test/features/intelligence_center/bil_tool_registry_test.dart`
- `test/features/intelligence_center/coach_conversation_and_routing_test.dart`

The shared worktree was already highly dirty. Several existing files above already contained unrelated uncommitted edits before this task; this list identifies this task's files/hunks and does not attribute each file's entire diff to this closure. No Community catalog was touched.

## Production impact, residual limits, and rollback

- Production mutations: **none**.
- Supabase access: read-only function list/download only; no deploy, secret change, SQL, or data write.
- Dependencies added: **none**.
- Device/store work: **none**; no signed build, Golden, purchase, Play, TestFlight, or App Store operation.
- Real token streaming remains a future coordinated protocol task; the app must not market the current buffered response as token streaming.
- Resolved forward in live v51: four explicit Gemini `safetySettings` use
  `BLOCK_ONLY_HIGH`; prompt feedback, candidate ratings, and safety finish
  reasons fail closed to a refunded `422 ai_safety_blocked` response. This does
  not replace authenticated device evaluation of real health-language prompts.
- The screenshot build provenance is unavailable, so on-device closure requires a later authorized device run against a frozen source revision.

Rollback is source-only: revert the task-owned hunks and remove the new files listed above. No database or user-data rollback exists. Reverting the `open_weight_log -> weight_history` mapping or the proposal-versus-receipt boundary would deliberately reintroduce the observed false-navigation defect. The local Edge prompt change requires no production rollback because it was never deployed.
