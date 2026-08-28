# BIL v1 Global Launch Repository Closure

## Decision

Repository-owned preparation for BIL v1 is complete only when the verification
contract in `BIL-V1-LAUNCH-006` passes on the authoritative Product Owner
environment and the resulting selective diff is approved and committed.

This decision is a repository closure. It is not Google Play approval, Apple
App Store approval, legal approval, or production release authorization.

## Accepted repository sequence

- `BIL-V1-LAUNCH-001` — global launch boundary and authorized scope.
- `BIL-V1-LAUNCH-002` — Android release preparation.
- `BIL-V1-LAUNCH-003` — Apple repository readiness.
- `BIL-V1-LAUNCH-004` — store privacy and health-declaration evidence.
- `BIL-V1-LAUNCH-005` — deterministic release-candidate gate.
- `BIL-V1-LAUNCH-006` — final repository closure and external handoff.

## Repository-owned gates

- Application version identity is `1.0.0+3`.
- Flutter formatting and static analysis pass.
- The complete automated test suite passes.
- Android release App Bundle production completes.
- The produced AAB size and SHA-256 digest are captured from the authoritative
  environment.
- Android, Apple, privacy, health-declaration, and release-candidate evidence
  remain explicit and internally consistent.

## External gates — open until independently completed

The following items are deliberately **not complete** through repository work:

- Google Play Console account access and final declarations.
- App Store Connect account access and final declarations.
- Production Android keystore custody, credentials, and signing authorization.
- Apple distribution certificates, provisioning profiles, and signing
  authorization.
- Public hosting and final legal approval of the privacy-policy URL.
- Final medical, privacy, and consumer-law review for launch territories.
- Store listing assets, ratings, pricing, availability, and submission actions.
- Physical testing on a representative Android and Apple device matrix.
- Store review, approval, staged rollout, monitoring, and rollback decisions.

No credential, certificate, password, private key, account identifier, or
hosted-service secret belongs in this repository closure.

## Product truth

BIL remains a privacy-first and offline-first health intelligence product built
around Truth Engine, Body Twin, One Best Action, and explainable intelligence.
The application must not present repository verification as clinical
certification or store approval.

## Handoff rule

After this package is accepted and committed, the next work is operational
launch execution against the external gates above. Any future code change must
start from the accepted closure HEAD and pass the non-regression gates again.
