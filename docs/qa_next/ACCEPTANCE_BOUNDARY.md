# Coach / Community next-update test boundary

Frozen application base: `3f0085e6e6686f2e87e9cf14789e9e578ea64159` (iOS 35 / Android 32).
This isolated `qa/coach-community-next-20261005` branch is authorized for code and tests only on standard GitHub-hosted runners. It must never be merged, released, deployed, signed, or used to modify production as a side effect of QA.

No personal images, account exports, health logs, credentials, device push tokens, or fonts may be newly uploaded. Reference images stay in the owner's private working attachments; public QA uses synthetic fixtures and reference fingerprints only.

## Independent acceptance gates
- Correct source and preserved release branches.
- Notification creation -> visible item -> acknowledgement -> authoritative badge refresh -> safe destination and back navigation.
- Atomic publish, approval, reward receipt and separate AI-credit/Gold balances; retry, duplicate, missing-profile and draft recovery cases.
- Community first-entry onboarding: after the existing splash, require display name only, optional remaining profile fields, create/save BIL Code successfully before entry; never fabricate policy acceptance or force public discoverability.
- Real repository-backed Coach actions, food values with provenance, revisions and safe undo.
- Native Flutter visual fidelity to the owner-approved Community and Coach references, including the approved bottom navigation. Passing logic tests does not establish reference fidelity.
- All test failures must remain visible. Mock/host tests are not live model, mobile push, StoreKit/Play or device evidence.

## Current state
Baseline QA setup only. No claim of complete implementation, pixel parity or release readiness. `ready_to_build_updated_store_artifact=false` until all relevant gates have actual evidence.
