# BIL V1 Release Candidate Gate

## Accepted parent

- Branch: `phase-3-product-excellence`
- Parent HEAD: `71bea9c806b08a1dd40df6a342fc46afe6b7d565`
- Package: `BIL-V1-LAUNCH-005`
- Version metadata: `1.0.0+1`

## Repository release-candidate gate

A repository release candidate is accepted only when all of these checks pass
in one package run:

1. The complete Dart source and test tree is already formatted.
2. Full Flutter static analysis reports no issues.
3. The complete Flutter test suite passes.
4. Android release App Bundle generation succeeds.
5. Architecture, Dashboard, Truth, Premium UI, Android, Apple, and store-privacy
   closure or readiness contracts remain present.
6. The generated AAB path, byte size, and SHA-256 are written into package
   evidence.

The verification run must not rewrite accepted source or golden files. Any
format, analyze, test, or build failure requires a focused revision rather than
waiving the gate.

## Artifact boundary

`build/app/outputs/bundle/release/app-release.aab` is repository build evidence.
Without the Product Owner's private upload key and verified Play App Signing
configuration it is not an authorized upload artifact. A later signed artifact
must be generated from an approved commit and re-hashed before Play submission.

## External gates

Apple archive and device validation, private signing assets, store-console
records, legal approvals, public privacy-policy hosting, declarations,
screenshots, review credentials, TestFlight or testing tracks, store review,
and rollout remain external. Passing this gate does not claim public launch.
