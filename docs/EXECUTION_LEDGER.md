# BIL Execution Ledger

| Package | Parent HEAD | Team | Frozen scope | Status | Verification |
|---|---|---|---|---|---|
| BIL-COM-001-R1 | `1867640` | Commerce Team | Commerce boundary and canonical offline Free plan. | Closed | Product Owner verified and committed as `fa43ba8ca14c119fb4e316db74a99de648137a8d`. |
| BIL-COM-002 | `fa43ba8ca14c119fb4e316db74a99de648137a8d` | Commerce Team | Paid-plan catalog and entitlement composition. | Closed | Product Owner verified and committed as `4f4f541fa66307fdcabc7ad7e38047130d795371`. |
| BIL-COM-003 | `4f4f541fa66307fdcabc7ad7e38047130d795371` | Commerce Team | Subscription lifecycle, deterministic entitlement resolution, and provider-neutral contracts. | Closed | Product Owner verified and committed as `74f0660`. |

## BIL-COM-003 closure conditions

- Production files, tests, package governance, and all six living knowledge documents are applied together.
- `scripts/verify.ps1` passes without weakening gates.
- Only package-manifest files are staged and committed.


## BIL-COM-003-R3
- Corrected entitlement resolution for unverified provider records.
- Local fallback now disables purchase restoration.
- Added regression assertions for restore and purchase flags.

## BIL-COM-004 — Closed by package application pending Product Owner verification

- Added `SubscriptionSnapshot` for verified cache metadata.
- Added configurable `SubscriptionRecoveryPolicy`.
- Added deterministic `SubscriptionRecoveryEngine` and explicit recovery actions.
- Added serialized `LocalSubscriptionRecordRepository` behind `CommerceKeyValueStore`.
- Added focused persistence/recovery tests and commerce regression coverage.
- Preserved `EntitlementResolver` as the only access-authority resolver.


## BIL-COM-005 — Ready for Product Owner verification

- Parent HEAD contract: `7f8ed95bbcc00ecb9be46a928e2449f23fbd87e3`.
- Added deterministic coupon/promotion definitions and evaluation.
- Added local usage ledger and future synchronization contract.
- Added creator attribution and commission metadata without payout execution.
- Added focused and regression protection.
- Updated all living knowledge documents.
