# External Launch 004 — Apple Cloud Build Readiness

## Decision

BIL uses a GitHub-hosted macOS runner to prove that the accepted Flutter source
can compile as an unsigned iOS Release application without requiring the Product
Owner to own a Mac.

## What the workflow proves

- Execution occurred on macOS.
- Flutter stable and iOS dependencies resolved.
- Static analysis passed.
- `flutter build ios --release --no-codesign` completed.
- `Runner.app` was archived with its source HEAD, size, and SHA-256 evidence.

## What it does not prove

The uploaded ZIP is not a distributable IPA. It is not signed, notarized,
provisioned, installable through App Store distribution, uploaded to App Store
Connect, or approved by Apple.

Signed IPA work remains blocked until Apple Developer membership, Team ID,
distribution certificate, provisioning profile, App Store Connect authority,
and agreement acceptance are evidenced. Those materials must be stored only as
protected secrets, never committed to Git or printed in logs.

## Execution boundary

The workflow is manual (`workflow_dispatch`) and read-only. A successful remote
run and downloaded artifact evidence are required before this cloud-build gate
can be marked complete.
