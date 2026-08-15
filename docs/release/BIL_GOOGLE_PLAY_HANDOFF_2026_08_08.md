# BIL Google Play handoff — 2026-08-08

## Approved identity

- Public developer name: `BIL Health`
- Store title: `BIL - Body Intelligence Log`
- Android package name: `com.bilhealth.bodyintelligencelog`
- Official domain: `bilhealth.com`
- Administrative account: `bilhealth.app@gmail.com`
- Public support address: `support@bilhealth.com` (inbound forwarding confirmed)

The package name is owner-approved and applied consistently to Android,
Apple, desktop identifiers, commerce defaults, release audits, and contract
tests. It must be entered exactly when the Google Play app record is created.

## Google Play account state

- Identity verification: owner-confirmed complete.
- Android physical-device access verification: owner-confirmed complete.
- Contact email verification: owner-confirmed complete.
- Contact phone verification: code not received by SMS or voice call.
- Google Play support ticket: owner-confirmed submitted; email receipt received.
- App record: not created while account phone verification remains pending.

Do not create a second developer account or a second app record to work around
the phone-verification ticket. Wait for the response on the administrative
account and preserve the support case number outside source control.

## Android release boundary

- `compileSdk` / `targetSdk`: 36; minimum SDK: 26.
- Release signing never falls back to the debug key.
- Ignored `android/key.properties` has the four required non-empty fields and
  its referenced keystore exists locally; no values are recorded here.
- Release shrinking and resource shrinking are enabled.
- Cleartext traffic and Android automatic backup are disabled.
- The production identifier is
  `com.bilhealth.bodyintelligencelog` in Gradle and all six native Kotlin
  sources are stored under the matching package directory.

No AAB build, upload, Play App Signing enrollment, or physical release install
is claimed by this handoff.

## Workout release boundary

- Initial release contract: exactly 200 movement videos.
- Distribution: 10 categories, exactly 20 videos per category.
- Duration: exactly 7 seconds per video.
- Canonical object path:
  `workouts/v1/movements/<movement-id>.mp4`.
- The app validates unique ids, URLs and SHA-256 digests before installation.
- The remote workout pack remains unavailable until the generated files are
  reviewed, uploaded to HTTPS storage, and `BIL_WELLNESS_MANIFEST_URL` is
  supplied to the release build.

## Visual reference boundary

The preserved visual manifest contains 177/177 historically verified rows,
42 screen families, 22 existing production files, and 29 existing evidence
files. No reference image was regenerated or re-inventoried.

The dashboard header was changed after the 2026-08-05 golden evidence to show
the full `BODY INTELLIGENCE LOG` wordmark. Therefore the existing dashboard
golden is historical evidence, not proof of the current pixels. A refreshed
dashboard visual review remains required when builds/goldens are authorized.

## Remaining external gates

1. Google resolves the contact-phone verification support ticket.
2. Create the Play app with the exact approved package name.
3. Complete Play App Signing and confirm the upload-key offline backup.
4. Build and inspect a signed AAB, then install/upgrade it on a supported
   physical Android device.
5. Complete Data safety, Health apps, App access, content rating and target
   audience forms from the prepared drafts and actual enabled configuration.
6. Upload to Internal testing first; complete any Closed testing requirement
   shown by the current personal-account console.
7. Review the generated 200 videos, publish their signed content manifest, and
   configure its HTTPS URL.
8. Refresh the dashboard golden and conduct the final human visual and
   linguistic review.

## Session constraints

This continuation used only local static inspection and `apply_patch`. It did
not run Flutter/Dart builds, tests, generators, Git, network calls, or paid API
requests.
