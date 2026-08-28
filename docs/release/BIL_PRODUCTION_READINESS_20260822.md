# BIL production-readiness checkpoint — 2026-08-22

This checkpoint records verified engineering evidence. It is not permission to
upload or publish. Store upload remains prohibited until workout media is
complete and the physical-device soak finishes.

## Installed Android release candidate

- Package: `com.bilhealth.bodyintelligencelog`
- Version: `1.0.0+3`
- Minimum / target SDK: 26 / 36
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- APK SHA-256: `38477CCCF40B3D89EAA10C4DD0287E4BB13FF630882352817317C395816CF1D9`
- Installed on the emulator at `2026-08-22 14:46:00` without clearing the
  authenticated account or its local data.
- `apksigner` result: verified with APK Signature Scheme v2, one RSA-4096
  signer, certificate DN `CN=BIL Upload, OU=Release, O=Body Intelligence Log,
  L=Cairo, ST=Cairo, C=EG`.
- Measured warm force-stop launches: 3.281 s and 2.480 s. The earlier multi-
  minute debug startup was ART/JIT/plugin verification in a debug APK, not the
  signed release runtime.

## Live emulator evidence

The installed release was exercised with the existing authenticated account.

| Surface | Evidence |
| --- | --- |
| Today / connected devices | `artifacts/qa/latest_release_today.png` |
| Diary | `artifacts/qa/latest_release_diary.png` |
| Food search | `artifacts/qa/latest_release_food_search.png` |
| Food detail | `artifacts/qa/latest_release_food_detail.png` |
| Water | `artifacts/qa/latest_release_water.png` |
| Weight progress | `artifacts/qa/latest_release_progress_weight.png` |
| More / latest weight | `artifacts/qa/latest_release_more.png` |
| Sharing, privacy, real last-sync time | `artifacts/qa/latest_release_sync_reenabled_20260822.png` |
| Premium community and friends | `artifacts/qa/latest_release_community.png` |
| Store plans | `artifacts/qa/latest_release_plans.png` |
| AI Coach grounded weight response | `artifacts/qa/latest_release_ai_weight_answer.png` |
| Carb Cycling editor | `artifacts/qa/latest_release_carb_picker_fixed.png` |
| Pregnancy trimester automation | `artifacts/qa/latest_release_pregnancy_t2.png` |

AI Coach returned the verified current weight of 89.2 kg. Voice capture entered
live-listening mode and stopped after the user pause. Closing and reopening the
conversation retained the correct conversation and did not restore the obsolete
pre-import body-history answer.

## Data and date stability

- Supabase contains 128 active weight records for the authenticated owner.
- The latest valid submitted weight is 89.2 kg on 2026-08-20.
- A live manual sync completed again at 2026-08-22 15:48 Cairo and the Release
  UI replaced the previous 13:04 value with the authoritative completion time.
- 51 supplied calorie days total 55,383 kcal (mean 1,085.9 kcal/day).
- Pending, textual, and blank values were not converted into invented numeric
  measurements.
- `dense_date_data_stability_test.dart` inserts and updates 2,192 consecutive
  days, including leap-day and same-day replacement checks, without duplicates.

## Plans, community, advertising, and privacy

- Premium includes ad-free use, analytics, meal planning, connected health,
  premium programs, custom goals, and the Premium community with friends and
  private messaging.
- Premium AI Coach inherits every Premium capability and adds server-authorized
  AI Coach quota; AI Boost remains a consumable and never grants a subscription.
- Runtime entitlement comes from verified server/store state. Cached, expired,
  refunded, revoked, paused, or unknown state fails closed to Free.
- Restore is exposed on the Plans screen and grants access only after store and
  server verification.
- Ads can be requested only for verified Free adults in reviewed non-sensitive
  placements after consent and provider configuration. They disappear and the
  native handle is disposed immediately when paid access is verified.
- The account deletion request is authenticated, idempotent, localized across
  25 locales, and processed by the scheduled privileged server worker.
- The existing private reviewer account is `play-review@bilhealth.com` with a
  server-owned Premium AI Coach closed-test grant. Its password must be entered
  only in private store review notes and never committed.

## Automated evidence rerun on 2026-08-22

- Commerce, community, advertising, and dense-history suite: 173 passing tests.
  A first command also named a nonexistent `test/account_deletion` directory;
  that command-line path error was corrected and is not a product failure.
- Correct account-deletion/community/privacy rerun: 17/17 passing.
- Android, Apple, privacy, signing boundary, Data Safety, purchase/restore,
  Apple receipt-chain, AI, and advertising launch-readiness suite: 105/105
  passing.
- Nutrition plan catalog, Carb Cycling, pregnancy automation, 25 locales, RTL,
  and 160% text: 26/26 passing.
- Targeted analyzer for the last nutrition and store-contract edits: no issues.

## External gates that remain open

1. Generate and inspect all workout videos. The resumable command is:

   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\artifacts\release\run_workout_video_gym_six_month.ps1`

   Live checkpoint at 2026-08-22 15:53 Cairo: the resumable runner is active
   with 74/102 processed videos. The current side-plank provider job has one
   paid attempt, reports provider success, and is resuming its output download;
   the wrapper did not submit a second paid attempt. An independent `ffprobe`
   decode of those 74 processed files found
   74/74 at 720x1280, 30 fps, 300 frames, and 10.00 seconds, with zero contract
   failures. This is partial evidence only; repeat the complete probe at
   102/102 before closing the gate.

   The read-only completion monitor
   `artifacts/release/monitor_workout_video_gym_completion.ps1` is running in a
   hidden PowerShell process. It follows generator PID changes through the
   verified run lock, so a transient wrapper restart cannot finalize a partial
   checkpoint. When the whole runner stops, it validates the exact 102 manifest
   filenames, decodes every file, records dimensions/fps/frames/duration and
   SHA-256, and writes a timestamped JSON report under `artifacts/qa`. It never
   calls the provider or reads its secret. The earlier PID-bound monitor emitted
   an explicitly failed 74/102 partial report; that report is retained as audit
   evidence and is not accepted as final validation.

2. Run the real ten-day physical-device soak. It cannot be replaced by an
   accelerated automated test. HealthKit requires Apple hardware; Health
   Connect and BLE need the intended physical devices. Record each real day
   with `artifacts/release/record_physical_soak_day.ps1`; the append-only
   harness rejects duplicate/backdated days, binds evidence and the tested APK
   by SHA-256, and cannot close day 10 before nine date boundaries have passed.
3. Create the four final subscription products and regional prices in Google
   Play and App Store Connect, then enter their product/base-plan/offer IDs.
4. Perform real Google closed-track and Apple Sandbox/TestFlight purchase,
   renewal, cancellation, refund, and restore cycles.
5. Supply production AdMob identifiers and complete provider review if ads are
   to ship. Until then production ads stay disabled.
6. Complete the owner-controlled Play/App Store questionnaires, legal owner and
   copyright fields, public-policy verification, Apple membership/certificates,
   and final human language/art review.
7. Increment the build number only when preparing the later V3 store candidate.

No Play Console or App Store upload has been performed by this checkpoint.
