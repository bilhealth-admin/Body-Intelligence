# BIL Execution Ledger

| Package | Parent HEAD | Team | Frozen scope | Status | Verification |
|---|---|---|---|---|---|
| BIL-COM-001-R1 | `1867640` | Commerce Team | Commerce boundary and canonical offline Free plan. | Closed | Product Owner verified and committed as `fa43ba8ca14c119fb4e316db74a99de648137a8d`. |
| BIL-COM-002 | `fa43ba8ca14c119fb4e316db74a99de648137a8d` | Commerce Team | Paid-plan catalog and entitlement composition. | Closed | Product Owner verified and committed as `4f4f541fa66307fdcabc7ad7e38047130d795371`. |
| BIL-COM-003 | `4f4f541fa66307fdcabc7ad7e38047130d795371` | Commerce Team | Subscription lifecycle, deterministic entitlement resolution, and provider-neutral contracts. | Ready for application | Product Owner must run package verification before commit. |

## BIL-COM-003 closure conditions

- Production files, tests, package governance, and all six living knowledge documents are applied together.
- `scripts/verify.ps1` passes without weakening gates.
- Only package-manifest files are staged and committed.


## BIL-COM-003-R3
- Corrected entitlement resolution for unverified provider records.
- Local fallback now disables purchase restoration.
- Added regression assertions for restore and purchase flags.

| BIL-COM-006 | Referral and Affiliate Attribution | Ready for Product Owner verification | Adds deterministic local attribution, commission state, audit, tests, and sync boundary. |

- BIL-COM-007: Regional Pricing and Country Eligibility — packaged for verification; production models, repository boundary, local resolver, focused tests, regression tests, and living documentation included.

### BIL-COM-008
- Added Apple, Google, Web, and unknown store-provider identities.
- Added purchase and restore boundaries without provider SDK coupling.
- Added receipt-validation contracts and deterministic local validation cache.
- Added focused and regression tests.
- No live billing, receipt networking, secrets, tax engine, or Paywall UI.
