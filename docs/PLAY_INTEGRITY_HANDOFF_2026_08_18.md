# BIL Play Integrity handoff â€” 2026-08-18

## Source baseline
- Branch before checkpoint: `fix/cloud-sync-closure-20260817-123334`
- Base HEAD before Play Integrity work: `7c3834163a035da89a35bb6dd952e36092e0b40b`
- Do not reset/rewrite the earlier cloud-sync closure work.

## Google Play / Google Cloud
- Android package: `com.bilhealth.bodyintelligencelog`
- Google Cloud project: `BIL Health`
- Project ID: `bil-health`
- Project number: `1041595138122`
- Play Integrity API linked from Play Console and enabled in the BIL Health project.
- Core response fields enabled in Play Console:
  - App licensing
  - Application integrity
  - Device integrity
- Optional response fields remain off during Closed Testing.
- Play App Signing remains managed by Google. No signing key reset/change was performed.

## Service account
- Service account: `bil-play-integrity@bil-health.iam.gserviceaccount.com`
- Private JSON key value is NOT committed to Git.
- The JSON exists only as the Supabase Edge Function secret:
  `BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON`
- Never print, commit, or expose that JSON.

## Supabase production
Project: `body-intelligence-log` (`tgmanzhqulksykhslrzb`)

Custom secrets present:
- `BIL_PLAY_INTEGRITY_MODE=observe`
- `BIL_PLAY_INTEGRITY_PACKAGE_NAME=com.bilhealth.bodyintelligencelog`
- `BIL_PLAY_INTEGRITY_PROJECT_NUMBER=1041595138122`
- `BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON=<secret>`

Edge Function:
- slug: `play-integrity`
- deployed version at handoff: `3`
- JWT verification: enabled
- server decodes Google Play Integrity Standard tokens
- server binds token verdict to:
  `SHA-256("bil-integrity-v2\n" + action + "\n" + requestId + "\n" + payloadDigest)`
- raw integrity tokens are not persisted.

Database:
- `public.bil_play_integrity_events`
- RLS enabled
- no client policies
- writes are server-side through the authenticated Edge Function
- production database already contains the schema; local migration is intentionally idempotent.

Production migrations applied directly during this session include:
- `add_play_integrity_observe_log`
- `play_integrity_payload_binding`
- `play_integrity_payload_binding_index`
- `play_integrity_event_action_length_hardening`
- `play_integrity_remove_duplicate_action_constraint`
- `play_integrity_payload_digest_not_null`

## Flutter / Android implementation
Files introduced/changed:
- `android/app/build.gradle.kts`
- `android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt`
- `android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILPlayIntegrityBridge.kt`
- `lib/app/security/bil_play_integrity_service.dart`
- `lib/main.dart`
- `supabase/functions/play-integrity/index.ts`
- `docs/db/checkpoints/202608180001_bil_play_integrity_observe_consolidated.sql`

Dependency:
- `com.google.android.play:integrity:1.6.0`

Current rollout policy:
- OBSERVE ONLY.
- Integrity failures must not block Closed Testing users.
- Do not switch `BIL_PLAY_INTEGRITY_MODE` to `enforce` until Play-installed,
  physical-device verdicts have been reviewed.

Planned enforcement targets after observation:
- trial start
- purchase / restore
- AI Coach
- AI Vision
- AI Voice
- sensitive Cloud operations

## Verification already completed
- `git diff --check`: passed before compile gate.
- Android debug APK build: PASSED.
- `flutter analyze --no-pub lib/app/security/bil_play_integrity_service.dart`: No issues.
- `flutter analyze --no-pub lib/main.dart`: No issues.
- Whole-project `flutter analyze --no-pub`: reports 18 pre-existing info/warnings in cloud-platform files; none of the displayed findings were in the new Play Integrity files.
- Emulator launched successfully with the modified build.
- No Play Integrity event was recorded from the debug emulator at this point; the real acceptance test is a physical Android device installing the Closed Testing build from Google Play.

## Codex continuation rule
First inspect this checkpoint and the remote Supabase state. Do not recreate the Play Integrity architecture, do not create another service-account key, and do not change/reset signing keys. Continue from observe mode, test a Play-installed physical device, then gate sensitive actions progressively.
