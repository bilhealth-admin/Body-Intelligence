# Health devices review — 2026-09-09

## Scope and release state

Local implementation and focused automated verification for the dashboard watch,
Apps & Devices, manual health synchronization, fitness Bluetooth, and the
25-language copy touched by these flows.

- Worktree: `G:\BIL_Project\worktrees\bil-unified-release-20260909`
- Branch: `codex/bil-unified-release-20260909`
- Unchanged parent: `8d48db48a9b8b5c59b6c10e8a26868bf590de13f`
- Earlier uncommitted AI Coach changes were preserved.
- No staging, commit, push, store build, upload, or backend deployment in this review.
- **Not a physical-device certification or release-ready declaration.** Native
  compilation/device gates below remain open.

## Findings and changes

### Refresh and navigation

The dashboard's last-sync chip was display-only. It is now an explicit refresh
button. The card still opens Apps & Devices; the redundant navigation arrow has
been removed. A busy refresh tap is consumed without opening the parent route.
The timestamp is updated only when a synchronization result succeeds, not when
the button is pressed.

The Apps & Devices watch icon now calls the same synchronization controller.
Secondary native-source controls have moved into an expandable, full-width
section. Source title, status, and the manual sync action remain visible.
Permission denial, provider installation/update, export permission, and native
settings entry points remain available when applicable.

The first release's manual-only import policy is retained: page entry, resume,
and permission approval do not start a health import. Native synchronization
continues asynchronously. Back navigation does not wait for it. After the visible
25-second timeout, subsequent taps reuse the outstanding native operation rather
than start competing imports and cache writes.

### Actual phone/watch measurements

The face no longer requires a wearable-specific provenance record. A verified
native phone source is valid. A step-history array containing only older dates no
longer masks a valid current-day step signal. Older daily totals are not shown as
today's measurements, and missing readings are not manufactured as zero.

Daily steps, distance, and active energy now come from native aggregate APIs:

- iOS: one-shot `HKStatisticsCollectionQuery`, cumulative sums, local calendar
  days, and no phone/watch source filter.
- Android: Health Connect `aggregateGroupByPeriod`, local-day buckets and only
  granted read metrics, without a data-origin filter.

These native totals replace raw activity projections; they are not added to raw
phone/watch samples. The window contains today and the preceding 29 local dates.
Original contributor identifiers remain in stored provenance. HealthKit's write
authorization status is no longer treated as evidence of read authorization:
explicit BIL consent is still required, and HealthKit controls the data returned.

The watch can show steps, heart rate (resting rate fallback), active calories,
and sleep when valid data exists. Four measurements use a two-by-two layout.
Distance, HRV, weight, and other supported readings remain in the readings list.
This does not add medical or unsupported sensor metrics.

### Readings and language

Recent synchronized signals retain values but no longer display source-name
subtitles such as iPhone, Apple Watch, or bundle/domain identifiers. Values and
units use the app locale. This is a presentation change, not provenance deletion.

The new labels, native status messages, and measurement-unit labels have explicit
catalog entries for the release set:

`ar, en, fr, es, tr, de, it, pt-BR, pt-PT, ur, fa, hi, id, ms, ja, ko, zh-Hans,
zh-Hant, ru, bn, vi, th, pl, nl, uk`.

Locale routing retains Portuguese region and Chinese script distinctions.
International units and product names may intentionally be identical across
languages; this is not a missing translation. The common fallback-audit inventory
now registers the new health catalogs and the earlier Coach review catalog.
Existing 25-locale Coach and meal-image tests were rerun as shared-copy protection.
This is not a claim that every screen has been manually reviewed in all languages
or that translations have independent human-linguist certification.

### Fitness Bluetooth

- iOS duplicate-packet suppression is scoped to a read session instead of the
  process lifetime; an unchanged pulse in a later read is accepted.
- Completed iOS manual reads unsubscribe from notifications.
- Explicit reconnect can retrieve an OS-known saved peripheral after process
  restart (CoreBluetooth identifiers on iOS; validated addresses on Android).
- Reconnect requests native permission again; a saved device is not a permission
  grant or proof that a device is nearby/connected.
- Packet identities include observation time. Malformed Base64 payloads abstain
  instead of failing a whole read.
- The existing supported fitness GATT scope and real connection callbacks are
  retained. Apple Watch data is still obtained through HealthKit, not direct BLE.

## Automated evidence

All Flutter runs were serialized with `--no-pub --concurrency=1`.

| Gate | Result | Evidence under `build/diagnostics/health_devices_review_20260909/` |
| --- | --- | --- |
| Focused health/watch/BLE regression and compatibility suite, 18 files | 139 passed | `final-tests.log` |
| Shared localization, source integrity, Coach and meal-image language suite, 7 files | 107 passed | `shared-localization-tests.log` |
| Dart/Flutter analysis, 13 scoped targets | No issues | `final-analysis.log` |
| Real-font, production-theme render variants | 2 passed; duplicate cases, not counted again | `visual.log` |
| Tracked diff whitespace | Passed with Windows CRLF handling | `git -c core.whitespace=cr-at-eol diff --check` |

**246 distinct automated cases passed.** The focused suite includes 50 widget
cases (25 locales × iOS/Android target settings), as well as permission, timeout,
deduplication, historical steps, and native-channel contract checks. These use
test fixtures/mocked native channels, not live HealthKit/Health Connect readings.
The platform-setting matrix does not compile Swift/Kotlin.

The widget matrix exercises refresh without parent navigation, repeated taps,
completion, opening Apps & Devices, its real refresh callback, back navigation
while a read remains pending, expanded source controls, and removal of source
subtitles. Existing responsive tests additionally cover 160% text scaling.

Captured fixtures (not physical-phone screenshots):

- `iOS_ar_dashboard.png`, `iOS_ar_devices.png`, `iOS_ar_source.png`
- `android_en_dashboard.png`, `android_en_devices.png`, `android_en_source.png`

The dashboard and source-card renders were visually inspected in Arabic/RTL and
English/LTR. No overlap was found in those captured states.

## Native/device gates still open

An offline Android `:app:compileDebugKotlin` attempt failed before application
compilation because this Windows Java/Gradle environment could not establish a
local loopback connection:

```text
java.io.IOException: Unable to establish loopback connection
```

See `android-native-compile.log`. This is **not** a successful Android compile.
Swift/Xcode compilation is unavailable on this Windows host. No physical iPhone,
Apple Watch, Android Health Connect device, or BLE sensor was exercised here.

Before shipping, use a functioning native build environment and verify:

1. Today's totals against the OS health app with phone-only data, then overlapping
   phone/watch data; check permission subsets, midnight, and local-day boundaries.
2. Read access with weight-write access denied on iOS; denied/unavailable data must
   not produce invented values or a false permission-granted claim.
3. Last-sync and page refresh, repeated taps, timeout, and back navigation on-device;
   verify no automatic import on entry/resume.
4. Supported BLE sensors: permission revocation, saved-device reconnect after
   relaunch, repeated equal readings, disconnect, and stopping notification traffic.

This review does not establish that application-wide frame stalls are eliminated;
that requires a profile-mode device trace, not a widget-test claim.

## Native references

- [Apple statistics collection queries](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery)
- [Health Connect aggregation and source priorities](https://developer.android.com/health-and-fitness/health-connect/aggregate-data)
- [Health Connect reading data](https://developer.android.com/health-and-fitness/health-connect/read-data)
- [CoreBluetooth peripheral interaction best practices](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/BestPracticesForInteractingWithARemotePeripheralDevice/BestPracticesForInteractingWithARemotePeripheralDevice.html)
- [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)
