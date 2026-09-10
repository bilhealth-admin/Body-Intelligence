# Settings, session and purchase feedback review — 2026-09-09

Original scope: the BIL app and its existing Community Supabase project.
The user later explicitly requested one bounded agent for the Google Android
developer-verification notice; that read-only result is recorded separately in
[the verification report](ANDROID_DEVELOPER_VERIFICATION_2026-09-10.md). The
package was already registered, its four keys were verified, and the agent was
stopped after closing the empty registration dialog.
The user then separately authorized that single agent to audit both stores and
compare their disclosures with the live domain policies and application code.
The user also authorized reading the latest Apple DSA/phone-verification email
thread, then explicitly requested a reply. One reply was sent in the existing
Apple support thread and verified in Gmail on 10 September at 01:36 Cairo time.
It was the only external write; no OTP request or phone-number change was made.
The [store/domain audit](STORE_READINESS_AUDIT_2026-09-10.md) records the evidence
and the current wait-for-Apple decision. The agent completed its task and stopped.
No App Store Connect / Play Console settings, releases,
production grants, notifications, schema, policies or membership data changed.

## Preserved baseline

- Checkout: `codex/bil-unified-release-20260909`, base `8d48db48a9b8b5c59b6c10e8a26868bf590de13f`.
- Prior dirty work was preserved. Before editing, 104 dirty/untracked files were
  copied and SHA-verified under
  `build/diagnostics/platform_polish_20260909/before-20260909-231133/`.

## Implemented locally

- Settings account action follows the authoritative auth identity: Sign in when
  signed out; explicit local-device sign out when signed in. It waits for success,
  prevents duplicate submissions and stays on the page on failure. An already
  cleared local session is treated as signed out even if remote revocation is
  temporarily unavailable; a changed active owner is never signed out by the old
  action. Sign-out failure copy is covered in all 25 supported locales.
- Community listens to Supabase auth changes, replaces its repository and feed
  key on owner changes, and discards the previous member's visible feed on logout.
- Profile values/labels and administrator email rows use single-line ellipsis.
  Tooltips and semantics retain full values; email direction stays LTR inside RTL.
- Settings/Profile icon pilot: UIKit `UIImage(systemName:)` on iOS and 23 official
  Google Material Symbols Rounded VectorDrawables on Android. Rounded square,
  vivid tiles replace pastel circles in these pilot rows only. Bounded local PNG
  caching coalesces repeat calls; desktop/web previews cannot count as native proof.
- A transient native-icon failure is no longer retained for the whole session.
  The next page request can retry, while an older failed request cannot evict a
  newer successful/pending cache entry. No automatic retry loop was added.
- Purchase cancellation remains silent. Native request failure, pending approval
  and unavailable receipt verification have separate localized feedback in all
  25 supported locales. Verification failure no longer claims that no access was
  granted. A thrown request no longer exposes the raw `purchase_failed` key.
- Store connections are initialized lazily after session readiness is checked.
  Initialization coalesces overlapping retries; read-only entitlement and
  native price queries overlap; native purchase updates are processed in order;
  late entitlement lookups cannot overwrite a newer owner/refresh, and disposed
  services do not notify removed listeners. Price/history/entitlement reads have
  bounded waits; the native purchase sheet itself is not timed out or bypassed.
  No receipt verification was bypassed.

## Live Community configuration (read-only)

Project `tgmanzhqulksykhslrzb` was checked directly. RLS is enabled on public
profiles, posts, friendships, reports, moderators and post-approval grants.
Anonymous access to policy/moderator/admin-authority RPCs is denied. Authenticated
members can query their applicable policy and authority; the administrative
notification mutation is not executable by `anon` or `authenticated`.

The inspected authority functions use server-maintained admin/moderator records,
not client-controlled user metadata. Administrative mutation paths remain
server-role gated and audited. No sample grant or notification was sent.

## Verification and limits

Local regression results (2026-09-10, Cairo): **319 distinct tests passed**.
The original 317 passed across three serial terminal-complete runs, with no
test assertion disabled:

| Run | Passed | Log under `build/diagnostics/platform_polish_20260909/` |
| --- | ---: | --- |
| Settings, session, profile and account switch | 57 | `settings-session-profile-final.log` |
| Authenticated community interactions, isolated | 22 | `community-auth-isolated-final.log` |
| Community, administration, commerce and cloud boundaries | 238 | `remaining-focused-tests.log` |

After the user stopped visual checks, two non-visual cache regressions were
added. The retry test first reproduced the defect (`native-cache-retry-before.log`:
retry returned null). After the cache fix, all 20 icon/session/profile tests
passed (`native-cache-retry-after.log`), including both new cases and 18 already
counted above. The total is therefore 319 distinct tests, not 337.

The first combined attempt did **not** complete: Dart 3.12.2 ran out of memory
while optimizing Flutter `_RenderObjectSemantics._updateChildren` in its CSE
pass (`final-focused-tests.log`). The exact affected file then passed all 22
tests in isolation, and both other partitions completed as recorded above.
The failed combined attempt is not counted as an additional successful run.

Static analysis covered 21 touched Dart source/test files: no errors or warnings.
Its one informational unused import in the native-symbol test was removed and
the affected file was reanalyzed successfully (`analyze-import-cleanup.log`: no
issues). The initial analyzer output is retained as `final-analyze.log`.
After the final cache-retry change, its source/test and both native QA drivers
were analyzed again: `native-cache-final-analyze-clean.log` reports no issues
across all four files. A braces-only lint in the new test was corrected first.

The Android native integration test built, installed and passed: all 23 symbol
names returned real PNGs through the Android method channel; Profile and
Settings rendered without fallback icons or layout exceptions. The final host
driver run also completed successfully in 21 seconds
(`native-capture-driver-inspect.log`: `All tests passed.`), preserving both page
captures before shutdown. Earlier failed attempts remain documented below.

This is not a release approval.
The Android emulator uses isolated in-memory QA fixtures, not a real member or
purchase. iOS compilation/rendering and an actual native-store purchase have not
been verified on this Windows host. The implemented native-icon scope is still
the Settings/Profile pilot, not an application-wide replacement. The user
subsequently explicitly stopped visual checking; no further screenshot review
or reference comparison was performed, and visual matching is not claimed.

Free accounts can use AI when their authoritative remaining credit is positive;
that does not automatically turn them into Premium or open the paid Community
route. Existing access policy was not changed. End-to-end production grant
delivery to two real accounts has not been executed.

The supplied Apple sandbox authorization alert is native system UI. App copy
changes cannot hide it or establish that payment completed. No store-account
permission change was attempted after the user's scope clarification.

### Windows native-test prerequisite

The initial Android build failed before app compilation with Java 21
`Unable to establish loopback connection` / `UnixDomainSockets.connect0`.
IPv4 preference and an alternate selector did not resolve it. An isolated
`Selector.open()` probe succeeded using this process-only option:

```powershell
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:\develop\bil-java-qa-20260909'
```

The task-specific directory was created for the test; no global Java/Flutter,
firewall, antivirus or store-account settings were changed. Native test command:

```powershell
flutter test --no-pub --no-uninstall -d emulator-5554 integration_test/native_settings_polish_test.dart
```

The first successful native test used Flutter's default uninstall behavior,
which removed screenshots saved inside the temporary app's files directory.
The first capture rerun used `--no-uninstall`; the final recovery instead used
the prebuilt APK and a host screenshot callback.

That capture rebuild was interrupted by a Windows resource error while reading
the installed `characters` package (`android-native-capture-final.log`), not a
missing source file. The dependency file was checked and remained present.
No packages, SDK files, global virtual-memory settings or caches were altered.
Capture recovery separates APK compilation from emulator startup, uses a
process-only 2 GiB Gradle heap limit, and receives images on the host through
Flutter's documented [integration screenshot callback](https://api.flutter.dev/flutter/package-integration_test_integration_test_driver_extended/integrationDriver.html).
The host callback checks PNG signatures and requires both page captures; it
does not claim an automatic pixel match to Apple's Settings reference.

The isolated debug-only QA APK build completed successfully in 332.4 seconds
(`android-capture-build-isolated.log`). It is a test harness, not a release
artifact. The host screenshot driver passed static analysis with no issues
(`capture-driver-analyze.log`).

The first prebuilt-APK driver attempt did not pass
(`native-capture-driver-final.log`): it could not find the rendered native email
icon after page setup. A contemporaneous emulator screenshot showed Android's
"System UI isn't responding" dialog
(`native-capture-debug.png` in the diagnostics directory). All 23 direct native
symbol checks had passed before that page assertion. This failed attempt is
not counted as native visual approval. Recovery retains the same APK and
assertions, while reducing only the temporary read-only emulator framebuffer
to 720 x 1600 and adjusting its runtime memory/CPU allocation; no permanent AVD,
SDK or application settings are changed.

The smaller-emulator retry also failed the same email-image assertion
(`native-capture-driver-light.log`), so resource pressure was not treated as a
proven complete explanation. A diagnostic rerun retained the same APK and all
assertions, with `--keep-app-running`; that run completed with `All tests passed`
in 21 seconds and saved:

- `docs/qa/native_settings_20260910/profile-ar-android.png` (142803 bytes)
- `docs/qa/native_settings_20260910/settings-ar-android.png` (111175 bytes)

The user then requested no visual inspection. The running command had already
completed when the stop was delivered. The temporary `BIL_Phone_API36`
read-only emulator was identified and closed. The two successful captures were
not visually reviewed or used to assert an Apple-reference match. Repeated
cold-start stability and physical-device performance remain unproven.
The later Dart cache-retry fix was verified by local functional tests only;
the native APK/captures predate that small fix and were not rebuilt after the
user stopped visual checks.

Targeted `git diff --check` passed. Whole-tree warnings in the weight repository
and native BLE bridge predate this task: their SHA-256 values still match the
verified before-edit backup. They were preserved, not silently rewritten.

General lag is not declared fixed: this work addresses specific duplicate/serial
store operations. Physical iOS/Android profiling, real store transactions and
device-to-device health-sync tests are still required. Automatic health upload
and existing consent/owner boundaries remain unchanged.

## Documentation closure — 10 September 2026

The local [privacy inventory](../APP_STORE_PRIVACY_DATA_INVENTORY.md) was backed
up with matching SHA-256 before its stale deployment and Apple-token-custody
statements were reconciled against current source and the live audit metadata.
This was a documentation-only correction: it did not change the published
policy or backend, and it does not establish a successful account deletion.

## Remaining requested work — not represented as complete

- Native icon adoption throughout the rest of the app; the implemented scope is
  the Settings/Profile pilot. Visual checking was stopped at the user's request,
  not silently counted as approved or continued in the background.
- Native iOS compilation and functional checks on a Mac/iPhone environment.
- A real, authorized sandbox purchase and receipt-to-entitlement confirmation;
  app feedback changes do not fix the Apple account's sandbox authorization.
- End-to-end administration/grant delivery to designated free/paid QA accounts;
  no production entitlements, messages or balances were changed during this task.
- Physical-device lag profiling and HealthKit/Health Connect synchronization
  validation; local code/contract tests do not establish phone performance.
- External store/domain remediation identified by the separate read-only audit,
  including health-data metadata alignment with the next verified binary.
  These remain recommendations, not completed external changes; the local
  privacy-inventory documentation correction above is complete.

## Primary implementation references

- [Apple symbol rendering](https://developer.apple.com/documentation/uikit/configuring-and-displaying-symbol-images-in-your-ui)
- [Google purchase lifecycle and verification](https://developer.android.com/google/play/billing/integrate)
- [Pinned official Android symbols](https://github.com/google/material-design-icons/tree/0cbb08816df07faaae3dca060d4ebb10b66c214f/symbols/android)
