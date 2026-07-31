# External Launch 001 — Release Artifact Provenance

## Scope

This package binds the authoritative Android release artifact to the accepted
repository closure without publishing, signing, uploading, or submitting it.

## Accepted inputs

- Repository closure HEAD:
  `113ef663f28c0e55f80d07a79cb6fbde52875036`
- Version: `1.0.0+1`
- Artifact path:
  `build/app/outputs/bundle/release/app-release.aab`
- Expected byte size: `74229640`
- Expected SHA-256:
  `0276C0628C9502A9436ACD915D953B5270916B5D883F138A2627E0E4A5821661`

## Evidence rule

The verifier must recompute the artifact size and SHA-256 on the Product Owner
machine. It writes a timestamped JSON record under `.bil-package-evidence/`,
which remains outside Git. The gate is reviewable only when the computed values
match exactly.

## Explicit non-claims

Passing this gate does not prove production signing, Play App Signing custody,
Google Play upload, Apple readiness, legal approval, device certification,
store approval, or production rollout.
