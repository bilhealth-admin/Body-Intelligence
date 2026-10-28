# BIL iOS40 internal configuration

Build40 is an owner-authorized internal TestFlight update above the signed
Build39 source69ebb89279f11a8da5ee8e631016a88f3d24333d. It is not App Store review
submission or public-release approval. Existing prices, subscriptions, production
identity, protected purchase arrow, signing, encryption and privacy gates remain.

- Version1.0.0, build40 passed explicitly to Flutter, preserving Build38/39 refs.
- Bundle: com.bilhealth.bodyintelligencelog.
- Source branch: codex/bil40-device-fixes-20261028.
- Signing trigger: codex/bil40-internal-testflight-20261028 at the same tested SHA.
- All10 configured exact-source push workflows and every required job must pass.
  iPhone and iPad continue as independent jobs/runs. Old39 results cannot satisfy40.
- tools/qa/bil40_internal_build_ci.py verifies receipts, protected sources and
  BIL40_VERIFIED_CLOUD_SOURCE_SHA before signing credentials are used.
- Unchanged cloud code may use fresh read-only published-source continuity
  verification and prior live evidence for that deployed version. Local isolated
  tests and HTTP success are not new Production inference proof. No cloud publish
  is implied by this application update.
- The cloud-source variable is an operator attestation, not an independent
  file-comparison engine. Set it only after comparing all published function
  files against actual committed Git blobs at the final SHA and saving the
  timestamped comparison evidence outside the repository.
- The signing acceptance manifest is generated only after CI, names actual runs,
  and explicitly keeps physical40 acceptance pending installation.
- Reuse the successful39 signing/export/upload implementation. Validate exact
  original IPA bytes, version40, bundle/team/profile, plugin/permission inventory,
  Apple processing and existing internal test group availability.
- An existing Apple build40 blocks duplicate upload. Do not submit App Review.

The physical39 findings and any remaining untested cases are tracked separately.
Every change needs behavioral regression evidence; no test may be deleted or
weakened to force release. Raw phone logs, credentials and health data stay local.
