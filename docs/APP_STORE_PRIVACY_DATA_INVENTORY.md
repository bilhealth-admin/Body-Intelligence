# BIL privacy and store disclosure inventory

This is the source of truth for App Store Connect, Google Play Data Safety and
the public privacy policy. Update it whenever a connector changes.

Deployment facts below were reconciled on 10 September 2026 against the
[read-only store/domain/backend audit](qa/STORE_READINESS_AUDIT_2026-09-10.md).
Source capability, deployed metadata and end-to-end proof are separate: this
inventory does not certify that every current source change is in build 8/12.

## Product position

- BIL is a health and nutrition logger, not a medical diagnosis product.
- The default experience is local-first; cloud features are opt-in.
- On Android, the Free plan can use the bundled AdMob SDK only for contextual,
  non-personalized or limited ads after the adult, region and Google UMP gates
  pass. Ad requests are restricted to general discovery surfaces; health,
  nutrition, weight, location, profile, search and private-community data are
  not ad-targeting inputs. Paid plans are ad-free. The current iOS release
  configuration does not enable ads or App Tracking Transparency.
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

## App Store Connect data-type map

Every type below is declared as not used for tracking and linked to the user's
account. This map mirrors
`ios/Runner/PrivacyInfo.xcprivacy` and the current cloud paths; it must be
re-audited before enabling any additional iOS SDK.

| App Store data type | Linked | Purposes |
| --- | --- | --- |
| Contact Info — Name | Yes | App Functionality; Product Personalization |
| Contact Info — Email Address | Yes | App Functionality |
| Contact Info — Phone Number | Yes | App Functionality |
| Health & Fitness — Health | Yes | App Functionality; Product Personalization |
| Health & Fitness — Fitness | Yes | App Functionality; Product Personalization |
| Identifiers — User ID | Yes | App Functionality |
| Identifiers — Device ID | Yes | App Functionality |
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

Do not declare Payment Information because Apple and Google process the card
details. Do not declare Contacts, raw Audio Data, precise Location, Crash Data
or Advertising Data unless a later source/SDK audit proves that the iOS
production build collects them. Product analytics is disabled and crash
reporting is local-only. Performance Data is limited to account-linked remote
request latency; Other Diagnostic Data covers authentication/security and
service-operation metadata. The current client submits recognized text, not a
raw microphone recording, to the BIL AI gateway. Other Data Types covers the
age/date-of-birth and sex profile fields used for requested calculations and
optionally included in the encrypted selective profile sync.

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
  account-deletion and data-deletion routes were available. App Store Connect
  still reads back `https://www.bilhealth.com/privacy` as the
  Privacy Policy URL and `https://www.bilhealth.com/account-deletion` as the
  User Privacy Choices URL.
- App Store Connect privacy answers must be reconciled manually against the
  table above; source and manifest changes do not update App Store Connect.
- Validate the final signed archive's aggregate privacy report on macOS/Xcode,
  including every embedded SDK's required-reason API declarations.
- Obtain approval for retention, deletion SLA, moderation and security
  contacts before submission.
- Review final store metadata so it does not imply diagnosis or unavailable
  device/content support.
