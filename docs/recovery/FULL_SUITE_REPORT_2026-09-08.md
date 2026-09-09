# BIL recovery test report — 2026-09-08

Status: **PORTABLE SOURCE SUITE PASS; SIGNED-DEVICE AND STORE GATES OPEN**

Branch: `codex/bil-community-policy-recovery-20260908`
Baseline commit: `21f16767fad82d625ced9b6da2146b66b4b27953`
Flutter/Dart: 3.44.6 / 3.12.2

## Preserved baseline

The supplied pre-recovery log reported 4,261 passed, 73 failed and one skipped.
Sixty-nine failures were in screenshot/golden/visual files. That evidence was
preserved; no blanket golden update, tolerance increase or hidden skip was used.

## Final portable run

The official runner was executed after source changes stopped:

```text
python tool/release/run_portable_release_tests.py
```

| Measure | Final result |
| --- | ---: |
| Test files discovered | 904 |
| Fixed platform/golden/evidence exclusions | 29 |
| Files executed | 875 / 875 |
| Passed tests | 4,071 |
| Failed tests | 0 |
| Skipped tests | 1 |
| Exit code | 0 |
| Duration | 878.584 s (14:38.584) |

The single skip is
`test/features/wellness/wellness_video_stream_live_test.dart`: the real public
stream probe deliberately requires `BIL_LIVE_WORKOUT_STREAM_CHECK`. It is not a
hidden application-test failure and remains a live-network gate.

An earlier complete-partition attempt found one introduced localization
fallback-closure failure after the new Community policy copy was added. The
missing fallback keys were added to
`tool/localization/locale_fallback_closure.dart`; its focused rerun passed, and
the final portable run above completed with zero failures.

## Focused and backend evidence

| Area | Result |
| --- | --- |
| Root `flutter analyze --no-pub` | **PASS — no issues** |
| Community policy SQL static contract | **9/9 PASS** |
| Community policy UI/preflight/static focused batch | **PASS**; Android/iOS target-platform overrides are host widget tests, not device tests |
| Live Community SQL fixture | **PASS** inside `BEGIN`/`ROLLBACK`; zero residue across all fixture categories |
| Supabase migration alignment | **114/114 aligned**, zero local-pending and zero remote-only |
| Edge source parity | **19/19 files semantically equal**; no Edge deployment was made |
| Deno baseline | **129 PASS / 3 FAIL** in pre-existing untracked App Attest fixture paths; no App Attest source was changed |
| Release helper tests | **PASS** |
| Public Community policy page | worker tests **6/6 PASS**; English/Arabic live page previously browser-verified |

The SQL fixture covers no active policy, unaccepted policy, accepted policy,
new-version reacceptance, suspended user, blocked relationship, direct publish
without acceptance, Community Storage upload gating, immutable version identity,
delete/reactivation rejection and privileged `TRUNCATE` rejection. It leaves no
test users, receipts, policies, objects, posts, messages, entitlements,
friendships or blocks.

## Build evidence

The unsigned/debug Android build succeeded with a process-only Java temporary
socket workaround:

```powershell
$env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=G:\BIL_Toolchains\Temp'
flutter build apk --debug --no-pub
```

Artifact: `build/app/outputs/flutter-apk/app-debug.apk`
Bytes: 271,497,350
SHA-256: `4E32D15E71709F91C8DFAC90E1A69E68D3DE88F1957F0ACAF443BE0BC82A2250`

The final rebuild completed after the last application-source edit; its APK
timestamp is `2026-09-08T18:43:58+03:00` and the newest `lib/` source timestamp
is `2026-09-08T18:38:32+03:00`.

This proves the Android debug source can build on this host. It is not a
Play-signed AAB, 16 KB device result or production artifact.

## Evidence deliberately not promoted

- The 29 excluded visual/platform/evidence-only files still require their
  intended environment. Existing screenshot/golden differences were not
  accepted automatically.
- No physical iOS or Android device run was available. Target-platform widget
  overrides do not prove system-browser, lifecycle, accessibility, upload or
  signed-build behavior.
- No macOS/Xcode 26 archive or TestFlight build was produced.
- No Play-signed AAB, Play Integrity/purchase canary or pre-launch report was
  produced.
- Current App Store Connect state was not readable because the retained session
  was at `authResult=FAILED`; authentication was not attempted.

## Conclusion

The final portable source partition is green and the Community policy backend
fixture is green. BIL remains **NOT READY TO SUBMIT OR RELEASE** until visual
evidence is classified, the three pre-existing App Attest fixture failures are
resolved or replaced with valid fixtures, signed iOS/Android device matrices
pass, store canaries pass, Google production access is approved and current
authenticated App Store Connect validation is available.
