# iOS build 9 Runner crash triage — 2026-09-06

## Evidence

The owner-provided `Runner-2026-09-06-233533.ips` belongs to:

- bundle: `com.bilhealth.bodyintelligencelog`
- version/build: `1.0.0 (9)`
- device/OS: `iPhone14,3`, iOS `26.6.1`
- capture: `2026-09-06 23:35:33 +0300`
- exception: `EXC_CRASH`, `SIGABRT`
- termination: `Abort trap: 6`, by `Runner`
- faulting queue: `com.apple.main-thread`

The backtrace contains an uncaught Objective-C assertion through
`NSAssertionHandler`, followed by `abort()`. It is not a Jetsam report, memory
termination, USDA failure, Supabase failure, or Google Mobile Ads startup
failure. The report does not include the assertion's native message, so it
cannot prove one exact source line.

The earlier build-8 startup failure was a separate Google Mobile Ads native
initialization issue. Build 9 does not load the ads frameworks in this report
and this crash occurred about 56 minutes after launch, not during startup.

## Hardening applied

The highest-risk matching native path is the iOS speech/audio bridge, which
uses `AVAudioEngine` and can receive a transiently invalid hardware route while
Bluetooth, a microphone permission sheet, or another audio session is being
released. The following protections are now in the iOS Runner target:

- Objective-C exception boundary around audio-format reads, tap installation,
  and engine startup; native assertions become recoverable bridge errors.
- Active input and valid sample-rate/channel checks remain required.
- `installTap` uses the active hardware format (`format: nil`) instead of a
  format that may become stale during a route change.
- The catcher is compiled into Runner through the Xcode project and bridging
  header.

## Validation

- iOS native runtime safety contract: passed.
- iOS audio-session contract: passed.
- Full `flutter analyze --no-pub`: passed.
- Full Flutter test run was started; it reached unrelated pre-existing failures
  in `architecture_source_file_size_guard_test.dart` for oversized Dart files
  already modified in the worktree. It was stopped after that failure; no
  failure was reported by the new audio contracts.

Final confirmation still requires a macOS/Xcode build of iOS build 10 and a
physical-device TestFlight test that exercises AI Coach voice, meal voice, and
weight voice while changing or disconnecting the audio route.
