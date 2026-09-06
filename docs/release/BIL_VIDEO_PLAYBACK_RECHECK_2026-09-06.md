# Video playback recheck — 2026-09-06

## Scope and evidence window

This record captures service, Flutter host-widget, and opt-in live-network
evidence, updated after the final whole-project analysis on `2026-09-06`. It covers stream resolution, resume state,
the verified-download cache, fullscreen UI, and one canonical first-party MP4 object. It does
not claim native-decoder, iPhone, iPad, Android-device, or new signed-build
validation. No build, CI, CDN/backend, store listing, price, release, or
production-track state was changed.

## Automated service evidence

| Test surface | Result |
| --- | --- |
| First-party stream resolver | 15 passed |
| Playback resume state | 8 passed |
| Verified media cache | 16 passed |
| Combined service run | **39 passed, 0 failed, exit 0** (`session 39054`) |

The passing service contract verifies that only a canonical trusted BIL workout
URL is eligible for direct streaming; malformed or noncanonical first-party
URLs are rejected rather than silently bypassing validation. A valid licensed
external MP4/WebM remains on the existing verified-download path. The resolver
uses a bounded metadata request, disables automatic redirects, applies a bearer
credential only through the trusted-origin policy, and requires all of the
following before returning a stream:

- HTTP `200` from the canonical object;
- exact catalogue byte length;
- `video/mp4` media type;
- byte-range support;
- a strong quoted entity tag.

The returned playback headers pin the entity with `If-Match`; authorization is
returned only when the trusted-origin credential loader supplied it. Tests also
cover forged URLs, redirect/error statuses, missing or weak entity tags,
metadata mismatch, stalled requests, late-request abort, no cross-origin
authorization leak, and propagation of the configured idle timeout through the
cache facade. No token value is printed or persisted by this path.

## Opt-in live first-party proof

The explicitly enabled live test performed a metadata request against the
canonical first-party object and then requested `bytes=0-31` with the same
strong `If-Match` entity tag.

| Live observation | Read-back |
| --- | --- |
| Metadata status | HTTP `200` |
| Media type | `video/mp4` |
| Exact object length | `18,669,598` bytes |
| Entity protection | strong quoted ETag plus `If-Match` |
| Range read | HTTP `206`, exactly 32 bytes |
| Container signature | MP4 `ftyp` present |
| Live test result | **1 passed, 0 failed, exit 0** (`session 6693`, rerun after final lint cleanup) |

This proves the current origin supports the exact HEAD/range/ETag contract used
by the resolver. It is not a full playback or decoder proof.

## Integrity boundary

Direct first-party playback intentionally does **not** download and SHA-256 hash
the entire file before the first frame. Its trust boundary is the curated
catalogue, canonical HTTPS origin, exact length, strong ETag, and `If-Match`
range pinning. This must not be described as full-byte SHA verification.

The explicit download/cache path remains stricter: it validates the expected
size and SHA-256 digest before committing the media atomically to the cache.
Licensed external media continues to use that verified-download path.

## Player implementation and host-widget evidence

Play opens a dismissible root fullscreen route before a network request. The
complete video frame keeps its original aspect ratio; a blurred cover-fit copy
fills the surrounding viewport. This is not a crop/stretch of the foreground,
and cannot remove black bars already encoded inside a source video. Controls
remain inside safe insets, while the backdrop extends to the viewport edges.

The player provides bottom play/pause, replay, scrubbing, playback speed, elapsed
time, auto-hide, explicit Back, keyboard actions, and localized recovery UI.
It pauses on background and does not autoplay on return. Resume history is
bounded to 100 content-digest entries; completed playback resets to the start.
The older professional-library lesson no longer maintains a separate small
unbounded network player: it delegates to the same verified media surface.

Factory/initialization, native commands, request silence, and stalled buffering
are bounded. Retry uses a fresh controller and preserves the last position.
Back does not await a native Pause or preferences write. A progressing stream
is not timed out merely because its native buffering flag remains set. Late
Play completions are paused before disposal to avoid a plugin timer being
created after disposal. If a native Play future never resolves, cleanup awaits
that native completion outside the UI; this is not a claim that a hung native
plugin can be forcibly cancelled from Dart.

The final combined run (`session 16894`) passed **74/74, exit 0**:

| Surface | Passing tests |
| --- | ---: |
| Fullscreen widgets, lifecycle, retries, speed, RTL and large text | 21 |
| Explicit Play/Download/Back integration | 4 |
| Video wall, unique content and access gating | 5 |
| Fullscreen/shared-player source contracts | 3 |
| Stream/resume/cache services | 39 |
| Architecture file-size guard | 1 |
| Approved brand/release metadata guard | 1 |

These totals are a single run, not a sum of overlapping earlier runs. The
earlier live 1/1 check is separate. Widget tests use an injected video platform,
so they verify Flutter behavior and geometry, not AVFoundation/ExoPlayer decoding.
They cover 390x844, 844x390, 1024x1366 and 1366x1024, plus 320x568 Arabic at 2x
text and 568x320 Arabic error recovery at 3x text. Scoped Dart analysis reported
no issues. Fresh whole-project `flutter analyze --no-pub` also reported
**No issues found**, exit 0, in 158.1 seconds (`session 2010`). This result covers
the source at that run; subsequent unrelated agent edits need their own checks.

`BIL_VIDEO_PLAYBACK_SOURCE_SNAPSHOT_2026-09-06.json` pins 22 relevant source,
test, and dependency files to their SHA-256 values after those runs. It is a
scoped worktree evidence snapshot, not an accepted whole-tree release freeze
or a signed-artifact manifest. Formatting verification over the 17 touched
video source/test files returned 0 changes, exit 0.

## Evidence still pending

- No native AVFoundation/ExoPlayer decoder was exercised.
- No physical iPhone, iPad, or Android device was exercised.
- No new iOS or Android build 8 artifact was built, signed, installed, uploaded,
  or submitted by this recheck.
- Network interruption recovery is service- and host-widget-tested, but end-to-end visual proof
  of spinner removal, retry presentation, fullscreen controls, and resume on a
  native decoder still requires source-matched build/device evidence.

## Primary implementation references

- [`VideoPlayerController.networkUrl` and HTTP headers](https://pub.dev/documentation/video_player/latest/video_player/VideoPlayerController/VideoPlayerController.networkUrl.html)
- [Dart `HttpClient` request lifecycle](https://api.dart.dev/dart-io/HttpClient-class.html)
- [HTTP conditional requests and `If-Match`](https://www.rfc-editor.org/rfc/rfc9110.html#name-if-match)

## Current decision

`VIDEO_SERVICE_CONTRACT=PASS_39_OF_39`

`FIRST_PARTY_LIVE_RANGE_CONTRACT=PASS_1_OF_1`

`FIRST_PARTY_FIRST_PLAY_FULL_SHA256=NO_BY_DESIGN`

`EXPLICIT_DOWNLOAD_SHA256=VERIFIED`

`PLAYER_AND_RELEASE_REGRESSION_TESTS=PASS_74_OF_74`

`WHOLE_PROJECT_FLUTTER_ANALYZE=PASS_NO_ISSUES_SESSION_2010`

`NATIVE_DEVICE_OR_NEW_BUILD_PROOF=NOT_AVAILABLE`
