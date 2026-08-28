# Workout bundle 302 handoff

Status: local metadata and runtime trust boundary PASS; remote publication is
blocked only because an authorized HTTPS Storage/CDN destination has not been
selected. No upload, app build, or install was performed in this closure.

## Owner decision and inventory

The BIL owner approved every generated workout clip without exception.

| Bundle | Content pack | Logical records | Local source |
| --- | --- | ---: | --- |
| Home Training | `bil-workouts-home-v1` | 200 | `G:\BIL_Workout_Media\bulk_1000\processed` (60), `bulk_1000_female_10s\processed` (138), and `output\fal_longcat_pilot\processed` (2 originals) |
| Gym six-month | `bil-workouts-gym-six-month-v1` | 102 | `G:\BIL_Workout_Media\bulk_1000_gym_six_month\processed`, matched exactly to `tool/workout_media/pipeline/contracts/gym_six_month_video_plan.json` |

Combined truth: 302 bundle-scoped logical records, 302 unique release keys,
301 unique payload SHA-256 values. Ninety-four asset names intentionally occur
in both bundles. One identical SHA-256 is an intentional shared payload, not a
missing file or overwritten record.

The earlier 200-total interpretation came from the legacy single-release
manifest: its builder inserted the 102 Gym results into 200 canonical slots as
replacement candidates. That representation hid the fact that the paid Home
200 files and Gym 102 plan files are separate physical/package inventories.
The two-manifest registry removes that ambiguity and never overwrites one
bundle with the other.

## Technical delivery evidence

- 302/302 delivery objects: MP4, H.264, 720x1280, 30 fps.
- 61 clips: 7 seconds / 210 frames.
- 241 clips: 10 seconds / 300 frames.
- The two original pilot clips used MPEG-4 Part 2. They remain preserved, and
  non-destructive H.264 delivery derivatives were created under
  `G:\BIL_Workout_Media\delivery_h264\home`. Each derivative manifest row
  records operation, original relative path, original codec, source SHA-256,
  and `sourcePreserved: true`.

The authoritative entry point is
`artifacts/workout_media/workout_release_bundle_registry_v1.json`. It pins both
bundle manifests and both owner-approval records by SHA-256. Each bundle row
pins its remote object path, delivery SHA-256, exact byte length, duration,
frame count, dimensions, frame rate, codec, primary group and plan memberships.

## Runtime and product boundary

- Flutter assets contain metadata only; no MP4 bytes are packaged in APK/AAB.
- Registry, manifest, approval, pack and cached-media mismatches fail closed.
- Identity uses `<bundleId>:<assetId>`, preventing the 94 cross-bundle name
  overlaps from colliding in saved state.
- One premium Workout Library route filters Gym, Home and My plans. Gym uses
  real Push/Pull/Legs and program-family membership; Home uses its ten real
  categories. Sections initially expose at most five cards and expand with
  See all within the same route.
- Premium glass remains driven by verified entitlement. The final visual skin
  remains intentionally adaptable until the owner's visual reference arrives.

## Publication blocker

The exact target bucket/CDN origin and public HTTPS base URL are not configured.
Until the owner selects that destination, object upload and production pack URL
generation must remain blocked. This does not invalidate the 302 local media or
their owner approval.
