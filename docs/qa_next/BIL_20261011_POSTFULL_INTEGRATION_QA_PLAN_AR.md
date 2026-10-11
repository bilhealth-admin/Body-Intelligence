# BIL 2026 — Post-Full Integration QA Gates — 11 Oct 2026

STATUS: isolated source integration, UNTESTED. No main, Production, store builds, PR#11 modification, or publishing.

## Immutable baseline
- QA PR11 full handoff d073dcb39c4d4ba5cef856a5d39935ca1f7de1ca.
- Actual Full executed on c1f1f47a627169fb692763d3a96dc81afcdc7b17: **8528 PASS, 0 FAIL, 3 SKIP**. Two of those SKIP were then passed under special optional conditions; one independent visual-evidence check remains unapproved.
- Media feature branch 57526fedbbf272801620ab6af0a9f4f426553a27.
- Store policy audit branch 6e63fe5e0315e88ace9c748281d3607e4334d146.
- Integration branch integration/bil-qa-media-policy-20261011 was created FROM proven QA head; two merge commits retain both feature branch ancestries.
- Exactly 25 source/test/docs paths were compared at Git blob level and had ZERO file overlap conflicts with QA, not zero runtime defects. All 8528 previous PASS refer to older source, NOT this integration.
- First Use + first meal celebration local worktree (10 files, separately reported ~175 tests) is NOT on GitHub integration. Do not overwrite local worktree; its new source is untested here.
- Desktop Commander device was offline as of review. No Flutter/Gradle/Xcode or device tests executed for this integration yet.

## Gate A: fast and focused before any Full8
1. Use Flutter 3.44.6; verify clean isolated worktree, latest integration HEAD, unchanged dependency lockfiles. Never mutate QA or Codex worktrees.
2. Run dart format check on changed Dart only, then flutter analyze --no-pub. Format actual diffs if necessary; never suppress analyzer.
3. Run read-only policy inspector:
   python tool/prebuild/store_policy_source_guard.py --json-out build/store-policy/guard.json
   python -m unittest discover -s tool/prebuild -p test_store_policy_source_guard.py
4. Run affected tests one at a time, using flutter test --no-pub --concurrency=1 PATH:
   test/shared/widgets/bil_media_review_sheet_test.dart
   test/features/community/community_post_image_support_test.dart
   test/features/community/community_multi_image_v1_contract_test.dart
   test/features/community/community_draft_mosaic_repository_test.dart
   test/features/community/community_post_gallery_behavior_test.dart
   test/features/profile/profile_photo_account_isolation_test.dart
   test/features/profile/premium_profile_page_test.dart
   test/features/daily_log/meal_photo_initial_action_test.dart
   test/features/daily_log/quick_add_meal_camera_contract_test.dart
   test/app/services/store_review_prompt_service_test.dart
5. Repair any genuine source/fixture regression narrowly. Rerun its single test, then its file, preserving assertions.
6. Preserve photo ownership, explicit review before any upload/AI processing, draft cancellation, 4-photo cap, atomic food logs, real UGC moderation and permission guards. No automatic publishing or upload without user action.

## Gate B: native iOS/Android proof
- iPhone + iPad: camera capture -> preview -> Retake / Use Photo / Back. Original photo, not a substitute; revoke permissions, corrupt image, pending decode, lifecycle, tablet/VoiceOver.
- Android native Photo Picker multi-select of up to remaining capacity: 1/2/3/4; already 2 photos allows only 2 more; older-platform fallback, owner A->B->A, Android process-death restoration; cancel leaves draft unchanged.
- Profile avatar and cover original image: Cancel must not change local or cloud stored image. Test offline and upload-retry behavior.
- Arabic and English RTL/LTR, 320/390/430/iPad, 1x and 2x accessibility, light/dark and device orientations.
- Apple StoreKit in-app review on development-installed iOS, recognizing Apple may suppress it; it does not display in TestFlight. Google Play review through approved Play test-track installation; Google owns appearance/quota.
- Confirm real subscriptions/reviewer access/UGC/backend health permission lifecycle separately before store submission.

## Gate C: merge remaining First Use, visual approval and Full
- Recover local First Use sources through authorized PC or explicit handoff bundle, preserving 10 files and all user modifications. Review as a 3-way merge, never assume prior 175 tests validate this branch.
- One broader visual-evidence bundle check remains unapproved. Previous 29 Golden cases passed on the Codex source, but do not blindly update/approve other unrelated baselines. Protect metallic watch and Home/iPad/5 tab design.
- After source frozen and all focused gates green, rerun affected P0/Focused/Broad, then one Full8 with 2 concurrent shards (1 test concurrency per shard) on same code fingerprint, 8 indexes 0..7.
- Any new Full failures: isolate precise test and fix root cause, do not blindly rerun all shards.

## Play Console blocker
Official Google email last recorded on Oct 8 had Suspended status. Current Play Console status remains unverified; green Flutter does not restore a suspended app. Authorized owner must confirm account app status and reviewer access; no hidden premium bypass, new AAB, appeal or console mutation without explicit decision.

## One final handoff after QA
Return tested SHA; test PASS/FAIL/SKIP and logs; device tests done/not done; First Use and visual package status. Do not claim release ready without native device and store access proof.
