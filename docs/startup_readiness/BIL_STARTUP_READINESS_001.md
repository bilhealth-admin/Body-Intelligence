# BIL-STARTUP-READINESS-001

## Baseline

`70fad7afe968604cbe25b5e046b8faf0045df76f`

## Purpose

Close internal startup blockers before external onboarding with Google, Apple, cloud providers, payments, subscriptions, or health-data approval programs.

## Changes

- Run the primary GitHub verification workflow on `phase-3-product-excellence` instead of the retired `foundation-v2` branch.
- Remove Android release signing with the debug key.
- Support an optional, private `android/key.properties` file and produce unsigned release output until real credentials are supplied.
- Add a non-secret `android/key.properties.example` template.
- Consolidate Android native Health Connect and BLE bridge classes under the canonical `com.bilhealth.bodyintelligencelog` package.
- Normalize iOS HealthKit and Bluetooth usage descriptions to one top-level entry per key.
- Add a repeatable startup-readiness verifier.

## Deliberately deferred

- Google Play Console and upload-key creation.
- Apple Developer, App Store Connect, certificates, provisioning, and final macOS identifiers.
- Cloud-provider activation.
- StoreKit, Google Play Billing, receipt validation, and subscriptions.
- Web compatibility work.
- Application version and build-number policy.

These are external activation decisions, not defects in this package.
