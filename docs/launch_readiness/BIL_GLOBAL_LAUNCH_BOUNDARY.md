# BIL V1 Global Launch Readiness Boundary

## Authorization

- Phase: `BIL V1 Global Launch Readiness`
- Governing branch: `phase-3-product-excellence`
- Accepted parent HEAD: `9fe26c3ceddf6e1d1de6bcb04344da043f3bb338`
- First package: `BIL-V1-LAUNCH-001`

## Repository audit

The accepted baseline currently establishes these release-relevant facts:

- Flutter version identity is `1.0.0+5`.
- Android namespace and application ID are `com.bilhealth.bodyintelligencelog`.
- Android uses minimum API 26 and target API 36.
- Android release signing reads an optional private `key.properties`; it does
  not fall back to the debug signing key.
- Android disables cleartext traffic and application backup.
- Health Connect and Bluetooth permissions are explicit in the manifest.
- iOS deployment target is 15.0 and bundle identity is `com.bilhealth.bodyintelligencelog`.
- HealthKit and Bluetooth purpose strings are present.
- `PrivacyInfo.xcprivacy` is tracked and included in Runner resources.
- English and Arabic application localizations are declared.

These facts are an audit baseline, not store approval.

## Authorized repository scope

- Release version and platform identity consistency.
- Android permissions, release configuration, AAB production boundary, and
  non-secret signing templates.
- Apple project configuration, entitlements, permission descriptions, and
  privacy-manifest consistency.
- Privacy policy, Data Safety, health-app declaration, store inventory, and
  medical-disclaimer consistency with the enabled product.
- Deterministic analysis, tests, and Android release-candidate builds.
- A final repository closure contract that names every remaining external gate.

## Explicit exclusions

The phase must not create or embed credentials, keystores, passwords,
certificates, provisioning profiles, developer-account identifiers, production
API keys, or hosted-service secrets. It must not submit to Google Play or App
Store Connect, publish a privacy-policy URL, make legal declarations, activate
billing or cloud services, claim physical-device certification, or claim store
approval.

## Acceptance model

Each package is applied by the Product Owner and verified on the authoritative
environment. A package advances only after its results are reviewed, approved,
selectively committed, and confirmed with a clean tracked worktree. External
gates remain visible and do not become hidden repository tasks.
## Release-candidate transition

BIL-V1-LAUNCH-005 owns the deterministic release-candidate gate. After that
gate is accepted, BIL-V1-LAUNCH-006 owns final repository closure and the
explicit handoff to external store, signing, legal, and device-certification
gates. Repository verification must not be represented as store approval.
## Repository closure

Repository launch preparation closure: **complete** only after
`BIL-V1-LAUNCH-006` verification is reviewed, approved, and selectively
committed. External store, signing, legal, device-certification, submission,
review, rollout, monitoring, and rollback gates remain open.
