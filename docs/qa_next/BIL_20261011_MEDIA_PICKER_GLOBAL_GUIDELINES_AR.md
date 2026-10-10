# BIL Media Review — Platform UX Standards & QA

**Status: separate feature branch; Flutter 3.44.6 and physical-device validation still required. PR #11 QA remains untouched.**

## Official specifications
- [Apple HIG Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons): use understandable system symbols, visible primary/dismissive roles, touch target at least 44x44 points.
- [Apple Photos picker](https://developer.apple.com/documentation/PhotoKit/selecting-photos-and-videos-in-ios): ordered multi-photo selection without requiring full-library permission.
- [Android Photo Picker](https://developer.android.com/training/data-storage/shared/photo-picker): system multi-image selection, bounded number and URI grants.
- [Android PickMultipleVisualMedia](https://developer.android.com/reference/androidx/activity/result/contract/ActivityResultContracts.PickMultipleVisualMedia): native and fallback behavior.
- [Official Flutter image_picker v1.2.3](https://pub.dev/packages/image_picker/versions/1.2.3/changelog): pickMultiImage(limit:) including single-slot limit=1.
- [Flutter icons](https://api.flutter.dev/flutter/material/Icons-class.html), [Cupertino Icons](https://api.flutter.dev/flutter/cupertino/CupertinoIcons-class.html): platform-aware camera and photo affordances.

## Implemented on isolated branch

1. Shared BilCameraCapturePage separates shutter capture from acceptance: photo preview, Retake and Use Photo. The XFile route returns only after deliberate Use Photo; camera caller subsequently applies existing AI consent, review, atomic logging and access checks.
2. Food Log gallery uses existing native picker, followed by a review sheet before AI analysis. Cancel returns without logging or uploading.
3. Community composer can select up to 4 images in one platform picker invocation (or the remaining slots); each is validated and compressed sequentially under existing MIME and size contracts; review sheet permits removing a candidate. Draft changes only after explicit Add to draft. Post publishing still requires the separate Publish action.
4. Profile avatar (Dashboard, Premium Profile, Community) and Community cover also request explicit review before choosing gallery media is saved/uploaded. The ProfilePhotoService optional confirmation callback blocks all local/cloud mutations on Cancel and validates owner again before storing.
5. Camera acceptance waits for the original JPEG frame to decode; slow/corrupt captures cannot be approved blindly, while Retake remains available.
6. Native symbols on iOS (Cupertino icons), outlined Material symbols on Android, minimum 48px touch controls, accessibility labels, Arabic/English review copy and responsive sheets. No heavy drop-shadow treatment.
7. Android image picker recovery now preserves multiple owner-scoped XFiles. Account change during selection returns no foreign media.

## Verification needed before QA integration
- Run Flutter 3.44.6 dart format/analyze and targeted tests on this branch before any merge.
- Test shared media-review-sheet cancel/remove/confirm and Arabic 320px viewport.
- Test community existing photo tests with explicit review acceptance, and 1–4 multi-pick images from native Android and iOS.
- Test Android fallback image picker with 1 remaining slot; do not rely solely on plugin unit mocks.
- Test camera Retake/Use/Back and pending/corrupt frame on Android and iPhone, camera permission denied and lifecycle pause/resume.
- Check 2x text scale, VoiceOver/TalkBack, orientation and retained drafts after errors.
- Verify file copies, Android low-memory process recreation and user A->B->A ownership isolation.
- Confirm each preview is the actual selected original; no automatic publish, photo upload or AI call on Cancel. Verify the previously saved avatar remains untouched when gallery review is cancelled.
- Protect Home dashboard, Log Food layout, bottom 5 navigation, First Use unmerged work, Supabase Production, Trial, subscriptions and stores.

## Not in scope / not proven

Instant feed disk caching and instant food search remain a separate performance workstream requiring owner-aware cache, signed URL renewal, and local-first results. The media UX changes above do not certify those speed improvements. The feature branch has not been Flutter-compiled or tested on device in this conversation.

**Do not merge with qa/bil-quality-ux-integration-20261009 while Codex is editing it.**
