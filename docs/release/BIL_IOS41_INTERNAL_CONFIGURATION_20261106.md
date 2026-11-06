# BIL iOS41 internal configuration

This is configuration for the authorized internal TestFlight update above signed
Build40 (0c94cf2a75c01ebb7cbea74704a18a8109831194). It is not a completed test
receipt, physical-device acceptance, App Store submission, or public approval.

- Version 1.0.0, explicit build 41, bundle com.bilhealth.bodyintelligencelog.
- Final source branch: codex/bil41-android33-release-20261106.
- Only after all ten required workflows and their required jobs succeed on that
  exact SHA, push the same commit to codex/bil41-internal-testflight-20261106.
  The promotion branch does not start the ten QA workflows again. Android33 and
  iOS41 are built from the same commit; neither protected Build38/40 branch moves.
- bil41_internal_build_ci.py reads live GitHub run/job metadata, rejects skipped
  or incomplete required jobs, verifies protected purchase sources/branches,
  and checks the separate recorded deployed Coach source parity receipt before
  signing credentials are used. Old Build40 evidence cannot satisfy these gates.
- BIL41_CLOUD_SOURCE_PARITY_20261106.json records the read-only deployed Coach
  version134 source commit53924198e960edae0a06c8234cb0d216a7f89437. The fifteen
  runtime files and import configuration must match the candidate and that
  cloud-source commit byte for byte. The app commit is identified independently.
  This is not a new model availability, health-data synchronization or Gemini
  response test, and this release workflow does not deploy cloud code.
- The internal-only signing manifest is generated after exact-source CI and
  keeps new physical-artifact acceptance pending. Configuration is not evidence.
- Preserve signing/profile/team/entitlement checks, system native cryptography,
  App Attest, privacy manifests, AdMob consent/configuration, final IPA identity
  and original IPA-byte upload checks. Direct fitness BLE is disabled by the
  audited release policy; Apple Watch data continues through authorized HealthKit.
- An existing Apple build41 blocks duplicate upload. Upload only the signed
  original IPA; require Apple VALID processing and actual readback of every
  existing internal test group's build relationship. Never submit App Review.

Prices, subscription rights, wallet amounts, the protected purchase arrow,
main and the existing iOS38/40 refs are not changed by this workflow.
Raw phone logs, credentials, and personal health data stay outside the repository.
