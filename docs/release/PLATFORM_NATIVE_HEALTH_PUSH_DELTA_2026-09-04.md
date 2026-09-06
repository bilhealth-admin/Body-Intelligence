# Native health and platform push delta — 2026-09-04

This delta records only the HealthKit/Health Connect parity and Android/iOS
remote-push work completed after the platform parity audit. It does not replace
the release audit or constitute signed-device certification.

## Health Connect parity closed in source

- Android now exposes the same 20 canonical read signals as the HealthKit
  bridge: steps, distance, active energy, workouts, sleep, weight, body fat,
  lean mass, heart rate, resting heart rate, HRV, hydration, energy, protein,
  carbohydrate, fat, fibre, sugar, sodium, and potassium.
- Hydration is no longer unreachable: `READ_HYDRATION`, the logical `water`
  type, `HydrationRecord`, initial read, incremental serialization, and the
  canonical `mL` unit are connected end to end.
- Health Connect's one `NutritionRecord` permission is queried once and emits
  only the requested, present nutrient values. Missing energy or nutrients are
  not manufactured as zero.
- Distance, body-fat and lean-mass permissions and serializers are present.
- Imported records retain source package, stable record id, device metadata,
  observed time, and wearable provenance. Records authored by BIL remain
  excluded to prevent an import/export echo.
- Every sample in a Health Connect heart-rate series is imported under a
  deterministic child identity. A series upsert replaces its previous child
  set and a parent deletion removes all children, without repeatedly scanning
  the persisted signal bucket for each sample or parent.
- Android asks for historical access only when the installed Health Connect
  reports `FEATURE_READ_HEALTH_DATA_HISTORY`. A grant selects the same bounded
  365-day bootstrap window used by HealthKit; refusal or unavailable support
  safely selects the normal 30-day window.
- The durable changes-token scope includes the effective history grant, so
  granting or revoking historical access later forces one correctly bounded
  bootstrap instead of reusing an anchor created for a different window.
- Clinical permissions remain excluded. No background-read permission was
  added because this release performs foreground refresh only.

Official basis:

- Android Health Connect data types and their manifest permissions:
  https://developer.android.com/health-and-fitness/health-connect/data-types
- Android's 30-day default and explicit history permission:
  https://developer.android.com/health-and-fitness/health-connect/read-data#read-data-older-30
- `HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY` feature check:
  https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_HISTORY()
- Health Connect changes-token expiry and resynchronization guidance:
  https://developer.android.com/health-and-fitness/health-connect/sync-data

## iOS APNs routing closed as far as source can prove

- `UNUserNotificationCenter.current().delegate` is assigned before application
  launch finishes, so foreground delivery and notification actions do not race
  Flutter startup.
- APNs notifications are distinguished with `UNPushNotificationTrigger`.
  Foreground remote notifications use the intended visible presentation path,
  and a selected remote notification is routed through the native push bridge.
  Non-APNs/local-notification handling continues through the Flutter plugin's
  existing superclass callbacks.
- Direct or nested `deep_link` data is accepted only when it is bounded to 512
  characters and uses the `bil:` scheme. Warm taps are forwarded immediately;
  cold-start taps are retained until Dart installs its handler and calls
  `takeInitialPayload`.
- The Dart handler returns an explicit Boolean acknowledgement. Native clears a
  pending cold-start payload only after receiving `true`, so a tap that arrives
  before Dart is ready is not silently lost.
- The native bridge reports provider status, and token deletion unregisters the
  application from remote notifications.
- `UIBackgroundModes` `remote-notification` was removed because this release
  implements visible notification delivery/taps, not background-content
  execution. No background-delivery capability is claimed.

Official basis:

- Notification-center delegates should be assigned before launch completes:
  https://developer.apple.com/documentation/UserNotifications/UNUserNotificationCenterDelegate
- APNs notification trigger:
  https://developer.apple.com/documentation/usernotifications/unpushnotificationtrigger
- Notification action handling:
  https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions

## Android remote push closed as far as source can prove

- The native `bil/push` bridge now reports runtime provider capability instead
  of letting compile-time flags imply that FCM exists.
- The current placeholder provider truthfully reports unconfigured and cannot
  mint a device token. Dart checks that capability before token registration or
  a server enable call, and the settings surface disables the switch if a build
  falsely advertises readiness.
- A `deep_link` delivered in the launch Intent is consumed once on cold start.
  A new Intent is forwarded while the app is warm. Native accepts only bounded
  `bil:` payloads, and Dart applies the existing route allow-list before any
  navigation.
- Dispatch now uses an additive per-outbox/per-device delivery ledger with
  atomic, bounded leases. Successful device deliveries are monotonic, so one
  failed device no longer causes already successful devices to be sent the
  same notification again. Concurrent dispatchers skip one another's leases.
- Every gateway request has a ten-second abort boundary, rejects redirects and
  non-HTTPS gateway URLs, and carries the stable delivery key in both the
  `idempotency-key` header and JSON body. The configured APNs/FCM gateway must
  enforce that key to cover the narrow crash window after provider acceptance
  but before the database result is recorded.
- Internal dispatch authentication now fails closed when the server-side
  secret is absent; an omitted header can no longer match an omitted secret.
- Lock-screen privacy no longer treats the whole `ai_coach` category as safe
  visible copy. A full notification body is now shown only for the explicit
  `safeVisibleCopyKeys` allow-list or when that device has
  `sensitive_preview_allowed`; otherwise the generic private-update text is
  used.
- Local notification routing is unchanged.

### Unpublished database dependency

`supabase/migrations/20260904040000_push_delivery_idempotency.sql` is a new,
additive **UNPUBLISHED** migration created in this source delta. It has not been
deployed by this work. Apply and verify that migration before deploying either
copy of the `community-push-dispatch` Edge Function; the function intentionally
fails delivery claims until its three service-role-only RPCs exist. Do not
deploy the function first. Rollout also requires confirming that the selected
gateway honours the supplied idempotency key.

Official basis:

- FCM background notification taps expose data in the launcher Activity
  Intent: https://firebase.google.com/docs/cloud-messaging/android/receive-messages#background
- FCM notification/data message behavior:
  https://firebase.google.com/docs/cloud-messaging/customize-messages/set-message-type

## External release blockers not fabricated in source

1. iOS universal-link publication is not release-ready. At the recorded live
   check, `/.well-known/apple-app-site-association` and
   `/apple-app-site-association` returned the site's `text/html` SPA, while
   Apple's CDN returned a 404/bad-JSON result. A real Apple Team ID, generated
   AASA, deployment/read-back, and an installed production-signed return test remain
   external requirements; source routing cannot substitute for them.
2. APNs provider credentials/environment, a production gateway delivery, and
   cold/warm/terminated-state taps still require a signed iPhone/iPad test.
   The source bridge does not prove that an external provider delivered a push.
3. Android still needs an approved production FCM project, app registration,
   `google-services.json`, messaging dependency/plugin, and a real
   `BILPushProvider` implementation. Until those owner inputs exist, remote
   community push remains fail-closed.
4. The configured FCM gateway URL/secret and end-to-end provider delivery must
   be verified outside this repository, including provider-side enforcement of
   the stable per-device idempotency key.
5. Google Play's Health apps declaration/Data Safety answers must be updated to
   exactly match the added distance, body-composition, hydration, nutrition,
   and historical-access permissions before release.
6. Play Integrity remains a separate source/backend increment: the current
   bootstrap-only observe/fail-open path is not request-bound enforcement for
   protected operations.
7. A signed physical-device pass is still required for partial permission,
   history denied/granted, Health Connect provider versions, cold/warm push
   taps, process death, and OEM behavior. Source tests do not replace it.

## Verification performed

- The previously recorded independent targeted Flutter verification completed
  **38/38** tests successfully.
- The focused Health Connect/push pass completed **37/37** tests successfully;
  the final privacy-specific rerun completed **28/28** successfully.
- The focused iOS notification-navigation suite completed **5/5** tests, and
  the combined Android/iOS notification-navigation pass completed **14/14**.
  These cover source dispatch, explicit Dart acknowledgement, and retained
  cold-start payload behavior; they do not simulate APNs delivery.
- The SwiftPM/permissions contract completed **6/6** tests. `pubspec.yaml`
  explicitly enables Flutter Swift Package Manager, and
  `permission_handler_apple` 9.5.0 derives camera, microphone, speech and photo
  capabilities from the matching `Info.plist` usage descriptions. A Podfile
  macro workaround is neither required nor claimed.
- Scoped Flutter analysis reported no issues, both dispatch copies passed Deno
  type checking, and `git diff --check` passed.
- Targeted Flutter tests cover canonical unit validation, source/device
  provenance, invalid-unit rejection, platform read-scope equality, manifest
  boundaries, heart-rate series replacement/deletion, history-scope anchor
  reset, cold/warm remote tap routing, per-device delivery idempotency, unsafe
  URL rejection, lock-screen privacy, timeout behavior, and the unconfigured
  provider fail-closed state.
- The AndroidX Health Connect 1.1.0 artifact present in the dependency cache was
  inspected to verify the history feature API and record/unit accessors used by
  the bridge.
- One full-tree Flutter snapshot exercised 4,900 tests. It reported 4,899
  ordinary passes plus one evidence-metadata hash error after an intentional
  golden update; resynchronizing the visual-reference metadata made the
  verifier and its **2/2** truth contract pass. Thus all 4,900 test bodies were
  green at that snapshot. APNs/SwiftPM source changed afterward, so this is not
  represented as the final frozen-tree rerun.
- No mobile build, deployment, signing, store edit, credential change, or
  external configuration was performed, per the owner's instruction.
