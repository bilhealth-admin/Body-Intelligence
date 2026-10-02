# BIL Google Play Data Safety release matrix — 2026-10-02

This document replaces the obsolete local-only Data Safety draft for current
release preparation. It is **not** a claim that Play Console currently contains
these answers. Console readback remains mandatory.

Source candidate before this documentation commit:
`c77721e756bfbafc29535d498f4bcb2ec30f6baa`.

## Platform baseline

- application ID: `com.bilhealth.bodyintelligencelog`
- compile SDK: 36
- target SDK: 36
- min SDK: 26
- public privacy policy: `https://www.bilhealth.com/privacy`
- public account deletion: `https://www.bilhealth.com/account-deletion`
- adult-only product position: 18+

Google Play requires new apps/updates from 31 August 2026 to target Android 16
(API 36) or higher. BIL meets the source-level target requirement.

## Health Connect release scope

The current manifest requests exactly:

- `android.permission.health.READ_STEPS`
- `android.permission.health.READ_DISTANCE`
- `android.permission.health.READ_ACTIVE_CALORIES_BURNED`

The Console Health Apps / Health Connect declaration must match the final
merged AAB exactly. Do not reuse older documentation that described broader
Health Connect permission sets.

## Data Safety working map

The final Console answer must be based on the exact signed AAB and included
SDKs, not package names alone.

| Data area | Current behavior | Console action |
| --- | --- | --- |
| Account identifiers / email | Supabase authentication and account security | Collected; linked; app functionality/security |
| Phone number | Only registration paths that ask for it | Conditional collection; linked |
| Profile/body attributes | Local-first; selected profile fields can sync | Collected when cloud/AI path is enabled |
| Health/fitness | Local-first; selected values can be sent only by authorized feature paths | Sensitive; disclose only actual remote processing |
| Weight/hydration/profile sync | Selective cloud sync after user enables it | Collected; linked; app functionality |
| AI Coach text/context | Sent through BIL backend to Gemini after explicit consent/request | Collected/processed; linked; app functionality/personalization/safety |
| Meal photo analysis | Selected image sent only after explicit consent/action | User content/photos; app functionality |
| Community profile/posts/images/messages/reports | Uploaded when Community is used | UGC; linked; app functionality/moderation |
| Food remote search | Query/locale can reach trusted gateway/USDA after local miss | Search history; linked conservatively |
| Purchase token/status | Store verification and entitlement | Purchase history; app functionality/fraud prevention |
| Integrity verdict/token | Play Integrity security path | Security/fraud-prevention data |
| Support requests | User-submitted support content | Customer support |
| Device/cloud identifier | Cloud/integrity functionality | Identifier; linked |
| Diagnostics/latency | Operational/security and provider latency records | Diagnostics/app functionality/security |
| Export files | Local generation; destination selected by user | User-directed transfer |

## Google Mobile Ads boundary

The Android dependency graph includes Google Mobile Ads even when BIL’s
runtime ad feature flag is disabled. The final signed AAB must decide the
Console truth:

- if GMA remains packaged/operational, reconcile Google’s current SDK data
  disclosure (including applicable IP/general-location inference, product
  interactions, diagnostics and device/account identifiers) and declare
  **Contains ads: Yes** when policy requires it;
- if a future release removes the SDK from the exact production AAB, update the
  matrix only after binary evidence proves absence.

Never infer “no data collection” merely from contextual/NPA configuration.

## Permissions / minimization

Current source:

- uses system-selected photos instead of broad photo/media permission
- removes legacy external-storage permissions from manifest merge
- camera and microphone are just-in-time feature permissions
- BLE is optional and legacy location is capped to Android <= 11 for discovery
- advertising ID and Privacy Sandbox ad permissions are explicitly removed from
  manifest merge
- Health Connect scope is limited to three read permissions

## Account deletion

Google requires both an in-app deletion path and a web resource for apps that
allow account creation. BIL exposes both. The final Play Console Data deletion
answers must point to the production deletion URL and describe eligible
retention accurately.

Official reference:
https://support.google.com/googleplay/android-developer/answer/13327111

## UGC and AI

Community includes report/block/human moderation flows and published community
guidelines. AI Coach includes an in-app unsafe/offensive answer reporting path.

Google clarified in July 2026 that User Data requirements also apply to
third-party AI integrations; BIL’s Gemini disclosures and consent must remain
consistent with the final Data Safety form and privacy policy.

Official references:

- https://support.google.com/googleplay/android-developer/answer/17134731
- https://support.google.com/googleplay/android-developer/answer/18258653

## Final Play Console readback required

Before production submission, verify and archive evidence for:

- Data Safety
- Data deletion questions + deletion URL
- Health Apps declaration
- Health Connect permissions
- target audience = 18+ as intended
- content rating
- Contains ads
- app access/reviewer credentials
- subscriptions/base plans/offers/pricing
- Play App Signing/upload certificate
- Play Integrity linked Cloud project
- privacy policy/support website
- countries/regions and store listing claims
- pre-launch report

The existing read-only store audit is incomplete until
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` is available to its GitHub job.

Status: **SOURCE MATRIX PREPARED — PLAY CONSOLE READBACK REQUIRED**.
