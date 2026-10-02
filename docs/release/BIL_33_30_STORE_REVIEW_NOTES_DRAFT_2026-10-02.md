# BIL 33 / 30 store review notes draft — 2026-10-02

> Draft only. Never store reviewer passwords, one-time codes, signing keys,
> service-account JSON, certificate passwords, or recovery codes in this file.

## Product

**Body Intelligence Log (BIL)** is an adults-only (18+) wellness, nutrition,
activity and body-trend logging app. It is not a medical device, diagnostic
service, emergency service, or substitute for professional medical care.

Bundle/application ID:
`com.bilhealth.bodyintelligencelog`

Target release:
- iOS build 33
- Android build 30

## Reviewer access

BIL keeps core local logging available without requiring a cloud account.
Account-based features include cloud functionality, Community and other
authenticated services.

If reviewer credentials are required by the store, configure them only in the
store’s protected reviewer-access field. Do not copy them into GitHub.

Reviewer entry path:
1. Open BIL.
2. Choose the account/login path.
3. Use the visible **Store reviewer access** option when the store-provided
   credentials are required.

## Subscriptions and purchases

Digital premium functionality uses the platform store.

Reviewer paths:
- open Plans / subscription screen;
- product prices, periods, trials and availability are read from the active
  store rather than hard-coded as purchase authority;
- **Restore Purchases** is available as an explicit user action;
- Terms and Privacy are reachable from the purchase surface;
- subscription management uses the applicable Apple/Google account surface.

Do not expect simulator-only builds to return genuine store pricing or complete
purchase lifecycle evidence.

## Account deletion

In-app deletion path:
**More → Help → Delete account**

Public deletion resource:
https://www.bilhealth.com/account-deletion

Privacy contact:
privacy@bilhealth.com

Deleting the BIL account does not itself cancel an App Store / Google Play
subscription. The app warns about this and provides the platform subscription
management path.

## Privacy and legal

Privacy:
https://www.bilhealth.com/privacy

Terms:
https://www.bilhealth.com/terms

Subscription terms:
https://www.bilhealth.com/subscription-terms

Health disclaimer:
https://www.bilhealth.com/health-disclaimer

Community guidelines:
https://www.bilhealth.com/community-guidelines

Support:
https://www.bilhealth.com/support

## Health permissions

Health functionality is optional.

### iOS

Apple Health authorization is requested only after an explicit user action from
Apps & Devices / the connected-health surface. Passive app launch and dashboard
refresh do not present the HealthKit authorization sheet.

Previously authorized, verified local health evidence can still be displayed
from the local cache. HealthKit genuine authorization/read behavior requires a
physical Apple device.

### Android

The current Health Connect manifest scope is limited to:
- Steps
- Distance
- Active calories burned

Health Connect access is optional and permission gated.

## Camera, photos, microphone and Bluetooth

These permissions are feature owned and requested when the user enters the
relevant journey.

- Camera: barcode or meal/profile/progress capture
- Photo selection: user-selected images through platform picker flows
- Microphone/speech: user-initiated voice entry / AI Coach voice
- Bluetooth: explicitly initiated supported fitness-device connection

The app provides alternatives where relevant, such as manual barcode entry.

## AI

Remote AI is optional and consent gated.

- AI Coach sends the user’s question and bounded relevant context through BIL’s
  protected backend to Google Gemini only for the requested feature.
- Meal-photo analysis requires a separate explicit action/consent.
- AI output is wellness guidance, not diagnosis.
- Rateable AI answers include an in-app unsafe/offensive report action.
- AI actions that change user data are confirmation gated.

## Community / UGC

Community is for signed-in adults and includes:

- user reporting
- blocking
- human moderation queue
- removal/rejection controls
- Community Guidelines
- access-controlled private messages

Private health records are not Community profile fields.

## Ads

The current signed-release configuration keeps BIL runtime ads disabled unless
a future owner-approved release explicitly enables/configures them.

Store declarations must still be based on the exact final binary and included
SDKs. Do not infer “no ads/no ad data” from the runtime flag alone if an
advertising SDK remains packaged in the final artifact.

## Security and integrity

The production source includes:
- App Attest client/server path on Apple
- Play Integrity client/server path on Android
- server-side store verification
- account/owner isolation
- replay/idempotency protections
- TLS/secret/log audits
- platform-backed AES-GCM system-crypto bridge

Genuine integrity verdicts require a signed physical/store-installed build.

## Reviewer limitations / expected external gates

The following cannot be genuinely proved by an unsigned simulator/emulator RC:

- App Attest
- Play Integrity
- HealthKit
- Health Connect provider/device behavior
- Apple Watch / fitness BLE hardware
- StoreKit sandbox lifecycle
- Play Billing lifecycle
- production push delivery
- native social authorization on signed device builds

The app must fail closed or expose an unavailable/recovery state when those
external prerequisites are absent.

## Submission checklist

Before these notes are copied to a store:

- replace the source SHA with the final certified 33/30 SHA;
- verify both platforms use that same source SHA;
- confirm final signed artifacts and signing evidence;
- confirm current App Privacy / Data Safety readback;
- confirm subscription products/base plans/offers;
- confirm reviewer credentials in protected Console fields;
- confirm all public legal URLs are reachable;
- remove any statement that does not match the exact final binary.
