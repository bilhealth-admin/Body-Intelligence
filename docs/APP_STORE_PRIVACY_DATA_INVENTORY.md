# BIL privacy and store disclosure inventory

This is the candidate-source disclosure inventory used to reconcile App Store
Connect, Google Play Data Safety and the public privacy policy. It is not a
readback of either store console, a signed-artifact certificate, or proof of
runtime collection. Update it whenever a connector changes.

Historical deployment facts below were reconciled on 10 September 2026 against the
[read-only store/domain/backend audit](qa/STORE_READINESS_AUDIT_2026-09-10.md).
Source capability, deployed metadata and end-to-end proof are separate: this
inventory does not certify that every current source change is in build 8/12.
The 4 October 2026 candidate-source reconciliation below supersedes older
source-only privacy drafts or matrices for the current candidate, not their
dated deployment facts or protected Android 31 / iOS 34 artifact bindings. See
the [current disclosure evidence contract](release/BIL_STORE_DATA_DISCLOSURE_RECONCILIATION_2026-10-04.json)
for separately classified source, SDK, console and unresolved evidence.

## Product position

- BIL is a health and nutrition logger, not a medical diagnosis product.
- The default experience is local-first; cloud features are opt-in.
- In the current Android and iOS candidate source, the Free plan can use AdMob
  only for contextual, non-personalized or limited ads after the adult, region
  and Google UMP gates
  pass. Ad requests are restricted to general discovery surfaces; health,
  nutrition, weight, location, profile, search and private-community data are
  not ad-targeting inputs. Paid plans are ad-free. The current signed iOS
  workflow explicitly enables ads and the provider; this is source
  configuration, not authorization to build or evidence of production serving.
  The older iOS ads-disabled statement described an earlier configuration and
  must not be applied to the 4 October candidate. Non-personalized requests or
  the absence of an ATT prompt do not establish the SDK's runtime tracking
  behavior; that boundary remains unverified below.
- AI suggestions require confirmation and never invent measurements.

## Data handled on device

- Profile, age/date of birth, sex, height, location, time zone, units, goals,
  preferences and user-selected profile/progress images.
- Weight, water, meals, nutrients, activity, sleep/context tags, measurements,
  reminders, notes, plans and decision history.
- Explicitly permitted HealthKit, Health Connect, watch or BLE device readings.
- Installed content packs, local settings, integrity metadata and migrations.

## Optional cloud data

- Supabase Auth handles account identifiers, email, a phone number where the
  chosen registration path asks for one, authentication events, IP address and
  user-agent/security metadata. A phone number is not required by every sign-in
  option.
- The current selective cloud-sync policy uploads only profile/body settings,
  weight records and hydration records after the signed-in user enables sync.
  It does not make the entire local meal diary a general cloud replica.
- Remote AI sends a bounded, ephemeral context only after the user asks the AI
  Coach. That context can include remotely processed dietary preferences,
  recent nutrition/weight/activity/sleep summaries and connected-health
  summaries from a verified source. This AI context is separate from the
  selective cloud-sync dataset.
- HealthKit records remain in HealthKit/on device by default. A relevant value
  can leave the device only through an enabled cloud-sync record or a requested
  AI context; BIL does not delete the source HealthKit record.
- A chosen profile photo can be uploaded to the public `profile-avatars`
  bucket and used as the user's Community avatar. Community profile/avatar,
  biography, relationships, posts and post images, audience, private messages,
  reports, food submissions, peer reviews and label/evidence images are
  uploaded when the user uses those features. Private messages are access
  controlled in Supabase but are not end-to-end encrypted.
- Support form submissions are stored with the signed-in account, subject,
  message, category and limited client context. Email support is also handled
  by the user's and BIL's email providers.
- After local food sources return no match, the trusted food gateway can send
  the search text and locale to USDA. BIL does not persist a dedicated search
  history or use it for advertising, but the gateway requires the user's
  authenticated session. Search History is therefore conservatively declared
  as linked to the user for App Store privacy disclosure.
- Apple/Google handle card data. BIL verifies transaction identifiers and keeps
  entitlement state; it does not collect payment-card details.
- Meal images leave the device only after explicit action and only when the
  configured vision endpoint is available.
- Account-linked AI usage records retain request/capability, token and provider
  fields plus request latency for quota, cost, reliability and abuse controls.
  Supabase service logs can retain IP address, user agent, request/response
  metadata and operational diagnostics under the provider's retention rules.

## Permissions

- Camera: barcode, meal, profile and progress capture.
- Photos: user-selected meal, profile and progress images, Community post
  images, and food-submission or review/evidence images.
- Microphone/speech: explicit voice entry. Apple/platform speech recognition
  may process the initiated audio under its own terms; BIL's AI gateway and
  Gemini receive the recognized transcript, not the raw microphone audio.
- Bluetooth: explicit connection to supported devices.
- HealthKit/Health Connect: only categories selected in the system sheet. The
  current iOS native bridge can read the authorized activity, sleep, body,
  heart, hydration and nutrition categories, and can write body weight only.
- Notifications: reminders scheduled by the user.

## Required controls

- Continue locally without an account and request permissions per feature.
- Export data, remove packs, clear local data and sign out independently.
- Delete account and associated cloud data through a verified backend flow.
  The Storage-first worker removes the user's object prefixes from every BIL-owned
  Storage bucket through the Storage API and verifies them empty before it may
  delete the Supabase Auth user. Storage or Auth failure returns the tracked
  request to `pending`; direct database-only Auth deletion fails closed. The
  production SQL-only worker is disabled. The 10 September read-only check found
  `account-data-deletion` ACTIVE at version 18 and its secret-protected
  `bil-account-data-deletion-storage-first-15m` dispatcher cron active. Required
  secret names were configured; secret values were not read. This confirms
  deployment/scheduling, not the completion of a real user's deletion.
- Warn before deletion that App Store/Google Play billing continues until the
  user cancels it with the store, and provide the platform subscription link.
- Report/block/moderation controls before public community is enabled.

## Current app-owned data-type map

The 18 types below mirror the current candidate's
`ios/Runner/PrivacyInfo.xcprivacy`: each is declared account-linked and not used
for tracking by BIL's app-owned paths. The previous 17-type map omitted
Community relationships. Apple classifies a social graph as Contacts; this is
not a claim that BIL reads the device address book. SDK-owned collection and
purposes are separate and are not limited by this table. This is not a readback
or completeness assertion for App Store Connect.

| App Store data type | Linked | Purposes |
| --- | --- | --- |
| Contact Info — Name | Yes | App Functionality; Product Personalization |
| Contact Info — Email Address | Yes | App Functionality |
| Contact Info — Phone Number | Yes | App Functionality |
| Health & Fitness — Health | Yes | App Functionality; Product Personalization |
| Health & Fitness — Fitness | Yes | App Functionality; Product Personalization |
| Identifiers — User ID | Yes | App Functionality |
| Identifiers — Device ID | Yes | App Functionality |
| Contacts — Community social graph | Yes | App Functionality; Product Personalization |
| User Content — Other User Content | Yes | App Functionality; Product Personalization |
| User Content — Customer Support | Yes | App Functionality |
| User Content — Emails or Text Messages | Yes | App Functionality |
| User Content — Photos or Videos | Yes | App Functionality |
| Purchases — Purchase History | Yes | App Functionality |
| Usage Data — Product Interaction | Yes | App Functionality |
| Usage Data — Search History | Yes | App Functionality |
| Diagnostics — Performance Data | Yes | App Functionality |
| Diagnostics — Other Diagnostic Data | Yes | App Functionality |
| Other Data — Other Data Types | Yes | App Functionality; Product Personalization |

For app-owned paths, do not declare Payment Information merely because Apple
and Google process card details. The current BIL AI client submits recognized
text, not raw microphone recordings; no app-owned raw Audio Data or precise
Location collection is asserted here. BIL's product analytics remains disabled
and its crash reporter local-only. Its app-owned Performance Data declaration
covers account-linked remote-request latency, and Other Diagnostic Data covers
authentication/security and service-operation metadata. These statements do
not exclude the linked advertising SDK's crash, performance, advertising or
location data from aggregate/store disclosures. Other Data Types covers the
age/date-of-birth and sex profile fields used for requested calculations and
optionally included in encrypted selective profile sync.

## 4 October 2026 candidate-source and SDK reconciliation

### Exact current source anchors

- `.github/workflows/bil_ios_signed_release.yml:241-242` enables
  `BIL_ADS_ENABLED` and `BIL_AD_PROVIDER_READY`; its build arguments at
  `:441-442` also set both to `true`. No build was executed for this audit.
- `lib/features/ads/services/admob_contextual_ad_gateway.dart:90` disables
  Google's same-app key before initialization; `:137` requests
  `nonPersonalizedAds: true`. Adult/account/UMP checks gate banner loading.
  These are code-path facts, not live consent or network-observation evidence.
- `lib/features/community/data/community_repository_connections_messaging_mixin.dart:122`
  sends `p_followed_id` to `bil_follow_member`;
  `lib/features/community/data/community_social_repository_mixin.dart:663`
  sends the friend target to
  `bil_social_request_friend_v2`. Canonical authenticated relationship writes
  persist paired UUIDs in `public.bil_follows` and `public.bil_friendships`:
  `supabase/migrations/20260924071037_community_current_build_backend_repairs.sql:492`
  and
  `supabase/migrations/20261003011205_community_profileless_friend_request_e2e_20261003.sql:74`.
- `supabase/migrations/20261003093710_community_feed_modes_v1.sql:61-78`
  ranks For You posts using accepted friendships and followed authors. This
  proves both App Functionality and Product Personalization purposes for the
  app-owned Contacts declaration at `ios/Runner/PrivacyInfo.xcprivacy:91`.
- `test/launch_readiness/apple_privacy_closure_contract_test.dart` now includes
  Contacts in the exact app-owned type set and traces its producer, persistent
  UUID relationship and personalized-feed contracts. Source assertions are not
  proof of Production migrations or native/console behavior.
- Locked Flutter plugin `google_mobile_ads` is `9.1.0`. Its installed podspec
  requires native `Google-Mobile-Ads-SDK ~> 13.7`; its Swift package declares
  GoogleMobileAds `from: 13.7.0`. Neither version range proves the final resolved
  SDK version without the actual archive/package-resolution evidence.

### SDK-owned declarations, not duplicate Runner rows

[Apple's manifest guidance](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
distinguishes an app's own declarations from the linked SDKs' manifests; Xcode
aggregates both. App Store Connect answers must cover both, but Runner does not
need duplicate SDK-owned collected-data rows.

The audit inspected the genuine GoogleMobileAds **13.7.0** binary distribution
in memory, without building BIL. The
[official package definition](https://github.com/googleads/swift-package-manager-google-mobile-ads/blob/13.7.0/Package.swift)
pins archive SHA-256
`E89BA382A6244F5C8D92941015B12D98678689EBE14960EAA4C1D5951784A9C2`, which
matched the downloaded vendor archive. Both its device and simulator
`GoogleMobileAds.framework/PrivacyInfo.xcprivacy` files declare:

| SDK data type | SDK linked flag | SDK tracking flag | SDK purposes |
| --- | --- | --- | --- |
| Coarse Location | Yes | No | Third-Party Advertising; Developer Advertising; Analytics |
| Crash Data | No | No | Analytics |
| Advertising Data | Yes | No | Third-Party Advertising; Developer Advertising; Analytics |
| Device ID | Yes | Yes | Third-Party Advertising; Developer Advertising; Analytics |
| Product Interaction | Yes | No | Third-Party Advertising; Developer Advertising; Analytics |
| Performance Data | No | No | Third-Party Advertising; Developer Advertising; Analytics |
| Other Diagnostic Data | No | No | Third-Party Advertising; Developer Advertising; Analytics |

These are the vendor's declared capabilities, not measurements of which data
BIL collected under a particular consent or runtime configuration. In
particular, the SDK's Device ID tracking declaration cannot be replaced by
Runner's app-owned `false` flag or dismissed because an ad request uses NPA.
[Google's disclosure guide](https://developers.google.com/admob/ios/privacy/data-disclosure)
also describes IP-based general location, crashes, performance, identifiers,
advertising data and interactions, and requires the developer to reconcile the
app's disclosures. No SDK-owned rows or tracking settings were changed here.

### Evidence still required; no privacy certificate

- **PARTIALLY OBSERVED, 4 October 2026:** App Store Connect showed 20 data
  types, selected purposes and expanded linked/unlinked previews. Complete
  per-type handling/tracking reconciliation is still unverified; see
  `docs/release/BIL_STORE_DATA_DISCLOSURE_RECONCILIATION_2026-10-04.json` and
  `docs/release/BIL_STORE_METADATA_DELTA_MAP_2026-10-04.md`. The dated
  10 September checks below are not current evidence, and source/XML changes
  do not update either store console.
- **UNVERIFIED:** the exact BIL archive's resolved SDK inventory, signatures,
  embedded privacy manifests, required-reason API coverage and Xcode aggregate
  privacy report. The inspected vendor 13.7.0 ZIP is not that archive.
- **UNVERIFIED:** actual SDK collection/tracking in BIL on device, including
  identifiers, consent decline, region transitions and lifecycle changes. A
  conservative vendor declaration is neither proof of unauthorized tracking
  nor proof that contextual ads eliminate tracking.
- **UNVERIFIED:** real UMP messages/consent readback and all relevant SDK/ATT
  consent boundaries. Existing source gates and mocked consent tests do not
  prove the deployed CMP configuration or native behavior.
- **UNVERIFIED:** current public-policy deployment parity and final console
  reconciliation across all enabled SDKs and app-owned flows. The historical
  website parity and console URLs below remain dated evidence only.
- **STOP BEFORE BUILD:** no signing, build, upload, console change or protected
  Android 31 / iOS 34 artifact rebinding is authorized or certified by this
  document.

## Submission gate

### Account deletion and Sign in with Apple

- The in-app primary deletion route is `More -> Delete account`; it displays
  the separate-store-billing warning before submission, provides the Apple
  subscription-management link on iOS, and returns a tracked request
  reference/status.
- In the current source, the authenticated Edge Function attempts
  Storage-first deletion immediately. If that call is unavailable, the durable
  request is retried by the secret-protected dispatcher scheduled every 15
  minutes. The live audit found 96 successful cron invocations in its 24-hour
  window, last checked at 9 September 2026 22:15 UTC. A successful dispatcher
  invocation does not prove a successful HTTP response or completed Storage,
  Auth or associated Community-data deletion. A dedicated authorized end-to-end
  deletion test remains required before treating that outcome as verified.
- The current Apple sign-in path forwards the short-lived authorization code
  through authenticated HTTPS for server-side exchange and encrypted token
  custody; it does not store the code or refresh token on the device. The
  `apple-sign-in-token` function was ACTIVE at version 7 in the live audit.
- When a custody record exists, the deletion worker revokes the Apple grant
  before deleting Storage and then Auth. A revocation failure leaves the request
  pending for retry rather than claiming completion. Legacy/non-Apple accounts
  without a custody record return `not_available` from that step and continue
  through Storage-before-Auth deletion; automatic Apple revocation is not
  established for those accounts. Source references:
  `lib/features/auth/supabase_auth_service.dart`,
  `supabase/functions/_shared/apple_sign_in_token_lifecycle.ts`, and
  `supabase/functions/_shared/account_deletion_worker.ts`.
- The manual Apple-account step remains available. After BIL deletion
  completes for a detected Apple-linked user, the app directs the user to
  `Settings > [your name] > Sign in with Apple > BIL > Delete or Stop Using`,
  links to `https://support.apple.com/102571`, and clears the local session.
  Skipping this optional Apple step does not block or undo BIL data deletion.

- The earlier 30 August deployment record (Cloudflare version
  `2aa8c5d3-d2b9-4193-a647-25d045fcde9e`) is historical, not a current-version
  assertion. The 10 September audit verified rendered public policy content
  and exact byte parity between live `www.bilhealth.com/app.js` and the local
  `public_site/app.js`; the audit records its SHA-256. The privacy, terms,
  subscription terms, support, health disclaimer, community guidelines,
  account-deletion and data-deletion routes were available. At that 10 September
  checkpoint, App Store Connect read back `https://www.bilhealth.com/privacy` as the
  Privacy Policy URL and `https://www.bilhealth.com/account-deletion` as the
  User Privacy Choices URL.
- App Store Connect privacy answers must be reconciled manually against both
  the app-owned map and all actual enabled SDK collection/purposes; source and
  manifest changes do not update App Store Connect.
- Validate the final signed archive's aggregate privacy report on macOS/Xcode,
  including every embedded SDK's required-reason API declarations.
- Obtain approval for retention, deletion SLA, moderation and security
  contacts before submission.
- Review final store metadata so it does not imply diagnosis or unavailable
  device/content support.
