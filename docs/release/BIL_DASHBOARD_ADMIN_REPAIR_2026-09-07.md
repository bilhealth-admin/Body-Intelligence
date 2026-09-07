# BIL dashboard and administration repair — 2026-09-07

This note records the source-level repairs prepared for the Android 9 and iOS
10 release candidates. The linked Supabase project was verified with the
owner's authorized session on 2026-09-07: the remote database is up to date and
the current admin, food-search, and community-push functions are deployed.

## Product repairs

- The Dashboard Water tile opens `/daily-log/water?from=%2Fdashboard`, so it
  lands on the focused water editor inside Today and returns to Dashboard.
- `ResponsiveAppShell` now owns a light status-bar contract for the light
  dashboard: transparent status bar, dark icons, light iOS status-bar
  brightness, and dark navigation-bar icons. This prevents the splash overlay
  style from leaking into a later dashboard rebuild.
- The Dashboard BIL wordmark is 44 logical pixels high instead of 38, which
  increases both its readable width and stroke presence while retaining the
  asset's intrinsic aspect ratio.
- The Calories card keeps the title “Calories”; its settings icon is replaced
  by a “Today” action in the same position, and the action opens the Today
  diary route.
- “Delete account” was removed from the More list only. The existing Help
  deletion flow remains reachable, so account deletion capability and the
  privacy/store commitment are not removed.
- The runtime profile catalogue, premium gate, connected-health provider/page,
  Dashboard grid, and Intelligence Center files were split into same-library
  parts. The public API and values remain unchanged, and every guarded source
  file is below the 700-line limit.
- The authenticated food-search path now refreshes expired sessions and sends
  a bounded reviewed English search hint for known multilingual terms, so a
  phrase such as “بطيخ الكيوي” can still resolve through USDA when optional
  translation is unavailable.

## Administration reliability

The three admin gateways now put a 12-second ceiling on mobile-integrity
attestation and a 20-second ceiling on the Edge Function request. A failed or
unavailable remote operation therefore resolves to the existing failure/retry
state instead of leaving a permanent spinner. The operation is still
server-authoritative and atomic; a timeout does not report success.

The admin screens now classify the failure safely for the operator: timeout,
unavailable/unpublished function, authorization/old roster, mobile-integrity
rejection, or generic rejection. They do not display response bodies, UUIDs,
or stack traces. This makes the screenshots' generic failure actionable after
the next QA attempt.

The admin functions and migrations must be deployed as one version set. The
local contracts currently require:

```text
ai-coach-global-reset
bil_global_reset_ai_coach(uuid, text, text)
bil_individual_reset_ai_coach(uuid, uuid, text, text, text)
bil_enqueue_admin_notification_with_message(uuid, text, text, uuid, text, text)
bil_list_community_moderators_for_admin(uuid)
bil_add_community_moderator_by_email(uuid, text, text)
bil_remove_community_moderator(uuid, uuid, text)
bil_list_suspended_community_members_for_admin(uuid)
bil_suspend_community_member_by_email(uuid, text, text, text)
bil_reinstate_community_member(uuid, uuid, text)
```

The authorized CLI verification completed with the following commands; the
database reported no pending migrations and each function reported a successful
deployment:

```text
npx supabase db push --linked --skip-vault
npx supabase functions deploy ai-coach-global-reset --project-ref tgmanzhqulksykhslrzb --use-api
npx supabase functions deploy food-search --project-ref tgmanzhqulksykhslrzb --use-api
npx supabase functions deploy community-push-dispatch --project-ref tgmanzhqulksykhslrzb --use-api
```

For simulator/legacy QA, the backend integrity setting must remain `off`. For
store builds, turn it to `enforce` only after the signed iOS App Attest and
Android Play Integrity grants have passed a canary. The app's release workflows
already require the matching backend release identifier before producing a
store artifact.

The current project has the translation and USDA lookup keys required by the
food-search function. No SMTP/mail-provider or internal push-gateway secret is
configured yet, so email delivery and operating-system push notifications must
remain explicitly unavailable until those providers are verified.

## Verification record

The following source and Flutter checks are part of this repair record:

```text
flutter analyze --no-pub
flutter test --no-pub test/architecture_source_file_size_guard_test.dart
flutter test --no-pub test/features/dashboard/dashboard_water_navigation_contract_test.dart
flutter test --no-pub test/features/admin/ai_coach_global_reset_test.dart
flutter test --no-pub test/features/admin/community_moderator_admin_contract_test.dart
flutter test --no-pub test/features/admin/community_member_access_admin_contract_test.dart
flutter test --no-pub test/features/admin/admin_notification_controls_test.dart
flutter test --no-pub test/features/admin/admin_operation_resilience_contract_test.dart
```

The Windows checkout cannot produce a signed iOS archive. The GitHub macOS
workflow remains the correct place to create the iOS 10 signed artifact; the
Android 9 candidate likewise needs the repository signing secrets and the
Play-linked integrity project variables.
