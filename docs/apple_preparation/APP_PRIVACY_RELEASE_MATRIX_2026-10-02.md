# BIL App Privacy release matrix — 2026-10-02

Source candidate before this documentation commit:
`c77721e756bfbafc29535d498f4bcb2ec30f6baa`.

## App privacy manifest

`ios/Runner/PrivacyInfo.xcprivacy` declares:

- tracking: **false**
- tracking domains: none
- linked, non-tracking data categories for account/product functionality and,
  where applicable, product personalization
- required-reason API: UserDefaults using reason `CA92.1`

The file is byte-identical to the manifest present in the iOS 32 source that
successfully reached App Store Connect validation. The resolved
`pubspec.lock` is also byte-identical to that iOS 32 source. This is useful
supply-chain continuity evidence, but the final iOS 33 signed IPA must still be
checked with Xcode’s aggregate privacy report.

## Current App Store privacy category map

| Category | Linked | Tracking | Purpose |
| --- | --- | --- | --- |
| Name | Yes | No | App functionality; product personalization |
| Email address | Yes | No | App functionality |
| Phone number | Yes | No | App functionality |
| Health | Yes | No | App functionality; product personalization |
| Fitness | Yes | No | App functionality; product personalization |
| User ID | Yes | No | App functionality |
| Device ID | Yes | No | App functionality |
| Other user content | Yes | No | App functionality; product personalization |
| Customer support | Yes | No | App functionality |
| Emails or text messages | Yes | No | App functionality |
| Photos or videos | Yes | No | App functionality |
| Purchase history | Yes | No | App functionality |
| Product interaction | Yes | No | App functionality |
| Search history | Yes | No | App functionality |
| Performance data | Yes | No | App functionality |
| Other diagnostic data | Yes | No | App functionality |
| Other data types | Yes | No | App functionality; product personalization |

Do not add Payment Information unless BIL itself begins collecting card/payment
details. Store operators currently process payment-card information.

Do not claim raw Audio Data collection for the current AI gateway: the app sends
recognized text, not raw microphone audio, to BIL/Gemini. Re-audit this if the
voice pipeline changes.

## Third-party SDK release rule

Apple requires developers to remain responsible for embedded third-party SDKs
and, for listed SDKs, privacy manifests/signatures. Final iOS 33 must generate
and review Xcode’s aggregate privacy report. Any newly introduced SDK version
after this matrix invalidates the continuity evidence.

Current official references:

- https://developer.apple.com/support/third-party-SDK-requirements/
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests

## HealthKit

HealthKit permission is now explicitly user initiated. Passive dashboard
startup restores previously verified local evidence but does not present or
probe the HealthKit authorization sheet.

Official guidance:
https://developer.apple.com/design/human-interface-guidelines/healthkit/

## Account deletion

The app contains an in-app deletion path. The public site exposes
`https://www.bilhealth.com/account-deletion`. Apple-linked deletion has a
server revocation path where revocable Apple credentials exist, and the app
also exposes Apple’s account-access follow-up instructions.

Official references:

- https://developer.apple.com/design/human-interface-guidelines/managing-accounts
- https://developer.apple.com/support/offering-account-deletion-in-your-app/

## Subscriptions

Source contracts include:

- store-derived pricing/period metadata
- explicit Restore Purchases
- no automatic restore at launch
- Terms and Privacy links on the paywall
- server/store entitlement verification
- seven-day free-trial eligibility gates for the intended AI plan

Official references:

- https://developer.apple.com/app-store/subscriptions/
- https://developer.apple.com/documentation/storekit/restoring-purchased-products

## Remaining App Store Connect gates

These must be read back from App Store Connect before submission:

- App Privacy answers exactly match this matrix and the final aggregate privacy report
- subscription names, durations, prices, territories and trial metadata
- age/content rating
- review notes and reviewer account
- Privacy Policy URL
- User Privacy Choices / deletion URL where configured
- export-compliance answer
- final signed IPA validation

Status: **SOURCE MATRIX PREPARED — CONSOLE READBACK REQUIRED**.
