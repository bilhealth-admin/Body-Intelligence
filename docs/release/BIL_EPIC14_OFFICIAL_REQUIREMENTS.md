# Epic 14 — official release requirements evidence

Checked 2026-08-05. These links are the policy/technical sources used for the
release configuration; store-console state is recorded separately and is never
inferred from source files.

## Google / Android

- [Google Play target API requirement](https://developer.android.com/google/play/requirements/target-sdk): new apps and updates must target Android 16 / API 36 from 2026-08-31. BIL targets API 36.
- [16 KB page-size support](https://developer.android.com/guide/practices/page-sizes): release native ELF segments are checked by the Epic 14 gate; an unverified native binary fails the gate.
- [Health apps declaration](https://support.google.com/googleplay/android-developer/answer/14738291): the owner must complete the Play Console declaration for Activity & Fitness, Nutrition & Weight Management, and the other capabilities actually shipped.
- [Health content and services policy](https://support.google.com/googleplay/android-developer/answer/16679511): the public privacy URL, accurate hardware dependency disclosure, non-medical disclaimer and minimal permissions remain required external listing evidence.
- [Flutter built-in Kotlin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin): the current Flutter 3.44 compatibility bridge remains intentionally pinned because two current transitive plugins still apply legacy KGP. The release AAB build is the acceptance test; migration becomes mandatory when those plugins publish compatible Android modules or before Flutter removes the bridge.

## Apple

- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files): `PrivacyInfo.xcprivacy` is bundled in the Runner resources and validated on macOS.
- [Required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api): BIL declares no app-owned covered API reason because its production native code does not directly call one; merged dependency manifests remain subject to Xcode/App Store validation.
- [Upload and validate builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/): the signed macOS workflow uses a private API key to validate, but not upload, the generated IPA.
- [Create an App Store Connect record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app): membership acceptance and an app record are external prerequisites and are not claimed by Epic 14.

The Kotlin compatibility warning is tracked as release P2 rather than hidden. It
does not change the current stable build result, but it must be reevaluated on
every Flutter or affected-plugin upgrade.
