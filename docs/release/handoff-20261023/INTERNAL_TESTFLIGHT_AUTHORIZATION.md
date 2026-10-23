# Explicit internal TestFlight38 exception — 23 October 2026

The owner explicitly approved an internal-only iOS38 build and upload using prior application evidence without repeating the full exact-SHA CI lanes. This exception is opt-in (`internal_testflight_existing_evidence: true`); the existing default exact-source CI and accepted-manifest path remains unchanged.

The internal path requires current source/branch/clean-tree/protected-ref identity, ancestry, and byte-identical application/native tests versus 1b23d4d4. It verifies actual successful full-analysis/root and supplemental jobs from run39992878548, and requires reviewed native/build helpers unchanged from6a0ef55b. Runtime changes invalidate reuse. Signing still requires the current native crypto gate, actual codesign/entitlement/profile/artifact/icon/production configuration checks, Apple's validation, one-shot upload, processing and internal availability readback.

Known QA failures40012542464 (baseline-output observer) and40012589309 (ledger after reviewed migration) remain disclosed; they are not changed to PASS. Full new-SHA certification, affected physical-phone behavior and store release are not claimed. Source acceptance manifests remain unaccepted. App Review submission, public release and protected-ref movement remain unauthorized. The receipt explicitly records the internal validation mode and prior evidence source.

Google video credentials were recovered from the existing original reviewer file; normal password authentication and independent identity readback succeeded. The owner separately approved encrypted storage under BIL_GOOGLE_REVIEWER_EMAIL and BIL_GOOGLE_REVIEWER_PASSWORD. No password or entitlement was changed; no credential is included here.
