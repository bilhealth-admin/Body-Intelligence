# Flutter Community policy UI recovery — 8 September 2026

## Scope

This note records the client-side recovery work for the production Community
policy. It does not alter production Supabase data, grants, RLS, purchases, or
any entitlement.

## Findings and corrections

- `lib/features/community/domain/community_content_policy.dart` had duplicate
  declarations of `CommunityMembershipAccessFailure` and
  `CommunityMembershipAccessException`. Dart cannot compile a library with
  duplicate type names. The duplicate block was removed; one canonical mapping
  remains for suspended and relationship-blocked Community access.
- `CommunitySafetyPage` presents separate, non-misleading states for policy
  loading, verification failure, no active policy, acceptance required, and
  an accepted active version. It does not claim to have recorded acceptance
  when no policy exists.
- The repository now reads the server-clock status RPC rather than deciding
  effective policy time solely from the device clock. It fails closed unless
  exactly one effective version is available and the server confirms the
  caller's exact receipt.
- Acceptance requires a deliberate user checkbox and then invokes
  `acceptContentPolicy(version)`. The UI does not pre-fill, synthesize, or
  submit acceptance for a user.
- Publishing and messages preserve their draft/error state when the repository
  reports a missing policy, an unaccepted version, or a suspended/blocked
  membership. Policy failures expose an explicit route to review the policy.
- Image-upload failures are reconciled against the authoritative readiness RPC,
  so acceptance/suspension races remain clear without replacing unrelated
  Storage diagnostics.
- English opens the real canonical URL unchanged; Arabic opens the same route
  with `?lang=ar`. Neither path is a placeholder.

## Regression coverage added

`test/features/community/community_policy_acceptance_ui_test.dart` contains 13
widget cases covering:

1. no active policy: a clear lock state and no acceptance control;
2. active unaccepted policy: the user must check the confirmation before the
   acceptance action enables;
3. accepted policy: the accepted state is shown only after the repository
   persists the current version;
4. a new active policy version: prior-version acceptance does not unlock it;
5. Arabic widget rendering under Android and iOS target-platform overrides on
   the host; this is not simulator or physical-device evidence;
6. a publish rejected for missing acceptance: the composer keeps the draft and
   shows the policy message; and
7. a suspended member: publishing stays locked and the draft is retained;
8. server re-read failure never creates optimistic acceptance;
9. explicit decline/navigation paths create no receipt; and
10. English/Arabic canonical link routing preserves the policy version.

`test/features/intelligence_center/coach_answer_with_action_regression_test.dart`
also remains the targeted regression suite for a model reply that contains both
an answer and an action. The obsolete comment claiming the test had never been
run was removed; it is not evidence of a successful run.

## Verification status

- `dart format` ran on the changed Dart files.
- `git diff --check` passed for the policy domain file, the added policy UI
  test, and the AI Coach regression test.
- The final four-file policy/locale focused batch passed **36/36**. The
  post-format Community/shared regression batch passed **193/193**, and root
  `flutter analyze --no-pub` reported no issues.
- The official portable runner then executed 875/875 scheduled files with
  **4,071 PASS / 0 FAIL / 1 opt-in live-stream SKIP**. These are host Flutter
  results only; no signed iOS or Android device was exercised.

Required host commands:

```powershell
flutter test --no-pub test/launch_readiness/community_policy_v1_sql_contract_test.dart test/features/community/community_policy_acceptance_ui_test.dart test/features/community/community_publish_preflight_test.dart test/localization/bil_25_locale_fallback_closure_test.dart
flutter analyze --no-pub
```

The host automated suites above passed. The release gate remains closed for the
signed-device Community policy/publish matrix, exact signed-candidate
provenance, App Attest fixture repair and visual/store evidence gates.
