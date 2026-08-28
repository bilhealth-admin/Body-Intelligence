# BIL Android / Google Play health and policy release audit

**Audit date:** 2026-08-24 (Africa/Cairo)  
**Repository:** `G:\BIL_Project\body_intelligence_log`  
**Package:** `com.bilhealth.bodyintelligencelog`  
**Audited app version:** `1.0.0+3`  
**Policy sources:** Google Play Help and Android Developers only  
**Overall result:** `BLOCKER_FOUND` — do not submit the current Data Safety,
Health Apps, or Health Connect answers until the owner decisions and declaration
actions in this document are complete. Real-device
items are separate release-QA gates, not policy violations by themselves.

This was a source, generated-manifest, documentation, and local/emulator audit.
It did **not** change Play Console, publish or upload a build, deploy a backend,
alter production data or users, or perform a production Supabase operation.

## 1. Executive result

The Android implementation is materially closer to policy readiness than the
older release documents imply. It targets API 36, uses Android 16 granular
health permissions, does not request broad photo/video access, has a Health
Connect rationale linked to the public privacy policy, keeps health data out of
ad requests, verifies Play purchases server-side, and now exposes explicit AI
answer and Community-member reporting.

Production submission is not yet safe because several declarations and
operational proofs cannot be inferred from source code:

| Area | Result | Release decision |
|---|---|---|
| Target API 36 | **PASS** | `compileSdk=36`, `targetSdk=36`; recheck the final signed AAB. |
| Android 16 body-sensor migration | **PASS** | Granular `android.permission.health.*` permissions are used; no `BODY_SENSORS*`. |
| Health Connect permission scope | **PASS_WITH_ACTIONS** | Scope matches the native bridge, but grant/partial-denial/read/write/revoke needs a physical device. |
| Health privacy/rationale | **PASS_WITH_ACTIONS** | Rationale and privacy link exist; global non-geofenced reachability and all-language review remain manual. |
| Health/medical claims | **PASS_WITH_ACTIONS** | The owner limited this release to compatible external fitness devices and the product BLE paths now allow only weight, body-composition, and heart-rate profiles. Five listing drafts contain the non-medical and external-fitness-device disclosures. Recheck the final signed AAB and all promotional claims against this boundary. |
| Photo/video permissions | **PASS** | No `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, or legacy storage permission in the merged release manifest. |
| Health data and ads | **PASS_WITH_ACTIONS** | Source is contextual-only and omits health payloads; AdMob/UMP Console setup and the final Data Safety answers remain manual. |
| AI-generated content | **PASS_WITH_ACTIONS** | Every rateable Coach answer now has an in-app unsafe/offensive report action; operational filtering/moderation follow-through is not proved. |
| UGC/Community | **PASS_WITH_ACTIONS** | Policy acceptance, report, block, and moderator primitives exist; operational moderation ownership and live two-account evidence remain. |
| Child Safety Standards | **CONDITIONAL BLOCKER** | If Play treats BIL as a Social app, public CSAE/CSAM standards, child-safety point of contact, and self-certification are missing. |
| Target audience / IARC | **PASS_WITH_ACTIONS** | The owner selected an adult-only 18+ release. Local Privacy/Terms and five store-description drafts now match; publish them, select only 18+ in Console, complete IARC truthfully, and prevent known minors from using the service. |
| Data Safety | **BLOCKER** | The former “no collection / Supabase inactive / no ads” draft contradicted the current build; it is now marked DO NOT SUBMIT. |
| Account deletion | **PASS_WITH_ACTIONS** | In-app request, public URL, and hard-delete worker exist; live end-to-end deletion/retention evidence remains. |
| Play subscriptions | **PASS_WITH_ACTIONS** | Restore, pending, verified acknowledgement, SubscriptionPurchaseV2, and account-hold mapping exist; Play-installed purchase tests remain. |
| Developer verification | **MANUAL ACTION** | Identity/package-registration status is visible only in Play Console. |
| Final device/release evidence | **RELEASE QA GATE** | Health Connect, BLE, OEM notifications, Billing, UMP, camera/mic, and the final AAB need real-device/Play-installed tests. These tests gate release quality and factual claims; their absence alone is not a Google policy violation. |

`BLOCKER_FOUND` does not mean the implementation should be redesigned. It means
the owner must close the declaration, audience, legal/privacy, and operations
gates before policy submission, then close the separate device-evidence gate
before production release.

## 2. Target API 36 and Android 16

Google's current target-API page states that from **31 August 2026**, new apps
and app updates must target Android 16 / API 36. Play Console production history
was not available to this read-only audit. The observed history supplied for BIL
shows closed testing rather than a confirmed existing production publication,
so the safe classification is **treat BIL as a new app unless Play Console proves
otherwise**.

Current source:

- `compileSdk = 36`
- `targetSdk = 36`
- `minSdk = 26`
- Java/Kotlin target 17
- `androidx.health.connect:connect-client:1.1.0`

The current generated release manifest also uses the Android 16 granular health
permissions. It contains neither `BODY_SENSORS` nor
`BODY_SENSORS_BACKGROUND`. No speculative SDK upgrade was made.

Before production, process the **final signed AAB** through Play's pre-launch
report and verify API 36 edge-to-edge, back navigation, permission prompts,
notifications, foreground/background transitions, and 16 KB device support.
Google's current 16 KB page states that apps targeting API 35+ must support
16 KB pages; the Play update-blocking enforcement date is **1 February 2027**.
Treat this as compatibility/release QA now, not an August 2026 submission-policy
blocker.

## 3. Current health-feature inventory

| User-facing capability | Current implementation | Release classification |
|---|---|---|
| Manual food, calories, macros, nutrients, hydration | Local database with optional cloud sync | Implemented; health/nutrition data |
| Weight and body measurements | Manual/local history, profile/body model, optional cloud sync | Implemented; health data |
| Steps, active calories, exercise | Health Connect read | Implemented; physical-device proof pending |
| Sleep | Health Connect read and user-visible sleep/recovery views | Implemented; physical-device proof pending |
| Heart rate, resting heart rate, HRV | Health Connect read | Implemented; physical-device proof pending |
| Oxygen saturation | Health Connect read | Implemented; physical-device proof pending |
| Weight and nutrition Health Connect sync | Read plus explicit write | Implemented; write/duplicate/source proof pending |
| BLE fitness measurements | Standard GATT profiles for weight scale (`181D`), body composition (`181B`), and heart rate (`180D`) only | Implemented in discovery, restore/connect, parser, policy, and display allowlists; no commercial device model is certified by this audit |
| AI Coach | Local routing plus consent-gated remote Gemini through BIL Edge Function | Implemented; generative-AI policy applies |
| Meal photo analysis / voice | Permission- and consent-gated camera/photo/audio flows | Conditional remote processing; Data Safety applies |
| Community feed, posts, images, profiles, friendships, messages | Authenticated Supabase-backed UGC | Implemented; UGC and possibly Social/Child Safety policies apply |
| Connected-health background delivery | Bridge currently reports scheduler availability without an actual background health-read permission/workflow | **Placeholder/partial**; do not claim continuous background health sync |
| Medical records (diagnoses, labs, treatments, clinical history) | No corresponding Health Connect permission or release bridge found | **N/A for this release** |

The BLE store disclosure must remain factual:

> Fitness measurements imported over Bluetooth require a compatible external
> Bluetooth Low Energy fitness device exposing a supported weight-scale,
> body-composition, or heart-rate GATT profile. BIL does not turn the phone into
> a measuring device.

Do not name commercial models as compatible until they pass a physical-device
test matrix.

## 4. Final merged Android permission matrix

The following list came from
`build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml`
after `processReleaseMainManifest`. It is the generated release manifest for the
current workspace, not a substitute for inspecting the final signed AAB.

### 4.1 App/platform permissions

| Permission | Why present | Policy assessment / action |
|---|---|---|
| `INTERNET` | Supabase, AI, remote catalogs/media, ads, commerce | Necessary; disclose remote processing accurately. |
| `ACCESS_NETWORK_STATE` | Connectivity and transitive Google SDK behavior | Low risk; no health data should enter ad/analytics requests. |
| `CAMERA` | Meal camera, barcode/QR scanning, optional profile/community capture | Runtime, just-in-time; camera hardware is optional. |
| `FLASHLIGHT` | Scanner dependency | Transitive scanner capability; verify no unexplained prompt. |
| `RECORD_AUDIO` | Dictation/voice/AI voice features | Runtime, just-in-time; audio Data Safety row required when remote voice is enabled. |
| `POST_NOTIFICATIONS` | User-configured reminders/reports | Runtime on supported Android; denial must not block core app. |
| `RECEIVE_BOOT_COMPLETED` | Restore scheduled local notifications | Verify on physical device across reboot/OEM battery controls. |
| `VIBRATE` | Local-notification presentation | Transitive/local notification use. |
| `WAKE_LOCK` | Transitive media/Google SDK behavior | Confirm with final AAB dependency inventory. |
| `FOREGROUND_SERVICE` | Transitive `androidx.work:work-runtime:2.7.0` pulled by `play-services-ads-api:25.4.0` / Google Mobile Ads | No BIL `WorkManager`, `ForegroundInfo`, expedited-work, or foreground-service call was found. The merged `SystemForegroundService` has no `foregroundServiceType`, and no type-specific FGS permission is present. This is a final-AAB/SDK review action, not a blocker by itself; do not remove the permission/component or upgrade a working SDK solely because it is present. |
| `BLUETOOTH_SCAN` | Discover compatible BLE devices | `neverForLocation`; runtime only when user starts pairing. |
| `BLUETOOTH_CONNECT` | Pair/connect/read compatible BLE devices | Runtime only for connected-device feature. |
| `ACCESS_COARSE_LOCATION` | Legacy BLE scanning, `maxSdkVersion=30` | Not modern device-location collection; still test Android 8–11 prompt and Data Safety behavior. |
| `ACCESS_FINE_LOCATION` | Legacy BLE scanning, `maxSdkVersion=30` | Same as above; never transmit location to ads. |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` | Legacy BLE, `maxSdkVersion=30` | Compatibility only. |
| `com.android.vending.BILLING` | Google Play products/subscriptions | Required for Play Billing. |
| `com.google.android.gms.permission.AD_ID` | Google Mobile Ads identifier | Present through the ads integration, but not inherently required for non-personalized ads. Decide the measurement strategy; if retained, reconcile it in Data Safety/ads disclosures, or use the SDK-supported manifest opt-out and retest. |
| `ACCESS_ADSERVICES_AD_ID` | Google Mobile Ads/Privacy Sandbox surface | Not established as necessary for contextual/NPA serving. Retain only with a documented release purpose and accurate disclosure, or opt out through supported SDK/manifest controls and retest. |
| `ACCESS_ADSERVICES_ATTRIBUTION` | Google Mobile Ads attribution surface | Not established as necessary for contextual/NPA serving. Android's Ad Privacy Sandbox was deprecated on 17 October 2025; decide whether attribution remains an intended production purpose. |
| App-specific `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX protection for dynamic receivers | Internal signature permission; no user prompt. |

The app manifest explicitly removes `ACCESS_ADSERVICES_TOPICS` contributed by
Google Mobile Ads, because BIL's policy is contextual/non-personalized only.
Removing Topics avoids an interest-based signal inconsistent with that promise.
The remaining AD_ID/attribution permissions are merger surfaces, not proof that
they are required for NPA. If retained, their actual collection and purpose must
be disclosed. If the owner does not intend identifier/attribution measurement,
use Google's supported opt-out controls, rebuild the final AAB, and regression-
test ads/UMP rather than deleting permissions blindly.

### 4.2 Permissions proved absent

| Permission family | Result |
|---|---|
| `BODY_SENSORS`, `BODY_SENSORS_BACKGROUND` | Absent; Android 16 granular migration complete. |
| `READ_HEALTH_DATA_IN_BACKGROUND` | Absent; no background Health Connect claim is allowed. |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` | Absent. |
| `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` | Explicitly removed from manifest merge. |
| `ACCESS_ADSERVICES_TOPICS` | Explicitly removed from manifest merge. |
| `ACTIVITY_RECOGNITION` | Absent; activity comes from user entry/Health Connect rather than an Android sensor runtime permission. |

## 5. Health Connect declaration and permission matrix

The app must complete both the **Health Apps declaration** and the **Health
Connect data-type declaration** in Play Console. Request only the types below;
do not select medical-record types.

| Manifest permission | Access | Visible core use / proposed Console justification | Status |
|---|---|---|---|
| `READ_STEPS` | Read | Show user-authorized step totals and trends in Connected Health/dashboard views. | Matches bridge |
| `READ_ACTIVE_CALORIES_BURNED` | Read | Show active-energy totals and evidence-linked activity summaries. | Matches bridge |
| `READ_EXERCISE` | Read | Import user-authorized exercise sessions for workout/activity history. | Matches bridge |
| `READ_SLEEP` | Read | Show user-authorized sleep sessions and sleep/recovery summaries. | Matches bridge |
| `READ_HEART_RATE` | Read | Show user-authorized heart-rate observations and trends. | Matches bridge |
| `READ_RESTING_HEART_RATE` | Read | Show user-authorized resting-heart-rate trends. | Matches bridge |
| `READ_HEART_RATE_VARIABILITY` | Read | Show user-authorized HRV evidence in recovery context. | Matches bridge |
| `READ_OXYGEN_SATURATION` | Read | Show user-authorized oxygen-saturation observations with source labels. | Matches bridge |
| `READ_WEIGHT` | Read | Import weight history selected by the user. | Matches bridge |
| `WRITE_WEIGHT` | Write | Save a weight record to Health Connect only after the user's explicit sync action. | Matches bridge; real write proof pending |
| `READ_NUTRITION` | Read | Import user-authorized nutrition records for daily nutrition history. | Matches bridge |
| `WRITE_NUTRITION` | Write | Save selected nutrition records to Health Connect after explicit sync action. | Matches bridge; real write proof pending |

Recommended Health Apps selections based on the current product, subject to the
exact labels shown in Console:

- Activity and Fitness.
- Nutrition and Weight Management.
- Sleep Management.

Connected-health aggregation and AI wellness coaching are product capabilities
and permission justifications, not category names asserted by this audit. Do not
select Google's medical **Clinical Decision Support** category for the current
wellness Coach.

Do **not** select diagnosis, treatment, Clinical Decision Support, or medical-
record categories without a truthful feature basis. The owner fixed the Android
release boundary at general wellness and compatible external **fitness** devices
only. Product BLE discovery, restore/connect, parsing, policy, and display paths
allow only weight scale (`181D`), body composition (`181B`), and heart rate
(`180D`); blood-pressure, glucose, pulse-oximetry, and thermometer BLE profiles
are excluded. On this audited release boundary, the current evidence supports
**Medical Device Apps: not applicable**. Reopen that decision before submission
if the final AAB, intended devices, markets, claims, or purpose expand beyond the
fitness-only/non-medical boundary.

Health Connect runtime requirements before production:

1. Test clean install and existing-user upgrade on a physical Android device.
2. Test all-granted, all-denied, and individual/partial permission grants.
3. Confirm the feature remains usable with a subset and does not re-prompt-loop.
4. Read known source records and preserve source/provenance/time-zone truth.
5. Write one weight and one nutrition record; verify no duplicate on retry.
6. Revoke access in Health Connect, return to BIL, and verify immediate UI truth.
7. Delete/disable connected-health access and verify the documented behavior.
8. Open the rationale from the Health Connect permission-management surface on
   Android 13 and Android 14+.

## 6. Health privacy and medical-claims matrix

Google's Health Content policy requires a public privacy-policy URL that is
active, publicly accessible, non-geofenced, not a PDF, and not editable by
visitors. The same policy must be available from the Health Connect rationale.

Observed:

- `https://www.bilhealth.com/privacy` returned HTTP 200 through Cloudflare from
  Cairo and is an HTML page.
- The Android rationale links to that exact URL.
- The rationale title, body, and privacy-policy action are present in all 25
  Android locale resource sets. The locale audit also checks that the action is
  not silently copied from English in the 24 translated resources.
- `https://www.bilhealth.com/terms` and `/account-deletion` returned HTTP 200
  and their intended SPA routes render. `/community-guidelines` returns the
  generic SPA shell with HTTP 200, but no matching route exists in
  `public_site/app.js`; after JavaScript loads it renders the site's 404 view.
  It is **not** a functional public policy URL and must not be supplied to Play.
- One-location HTTP success does not prove global non-geofenced availability;
  verify from at least EEA, US, and another target region before submission.

| Claim/surface | Required boundary | Current result |
|---|---|---|
| English store description | “not a medical device and does not diagnose, treat, cure, or prevent any medical condition” plus professional-care direction | Exact requirement added |
| Arabic, French, Spanish, Turkish descriptions | Equivalent non-medical/no diagnosis-treatment-cure-prevention language | Added; native/legal review still required |
| BLE fitness-measurement claim | Compatible external fitness device required; supported BLE imports are weight, body composition, and heart rate; phone alone does not measure | Added to all five listing drafts |
| AI Coach | Wellness education and evidence-linked suggestions, not diagnosis/treatment | Source safety boundary exists; live output regression required |
| Health Connect oxygen-saturation records | User-authorized Health Connect data remains separate from BLE device discovery; BIL does not claim the phone measures oxygen saturation | Keep source labels and non-medical boundary explicit |
| Medical Device Apps classification | Fitness-only BLE profiles, general-wellness purpose, and no diagnosis/treatment or regulated-device representation | Not applicable to the audited release; re-evaluate if final code, devices, purpose, or claims change |
| Pregnancy, clinician-supervised, or highly restrictive pathways | Must defer to clinician and avoid guarantees | Keep clinician gates; review all promotional copy |
| Medical records | No diagnosis/lab/treatment/clinical-history Health Connect types | N/A for this release |

All localized Play listings, screenshots, feature graphics, video captions,
promotional content, and reviewer notes must tell the same truth. Updating the
repository JSON does not update Play Console.

## 7. Photo and video permission policy

Current release behavior uses the camera only after a user initiates capture and
uses system-backed pickers for occasional gallery selection. The merged release
manifest contains no broad `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` access and no
legacy external-storage permission. This satisfies the least-privilege direction
for occasional photo selection.

Before upload, inspect the final AAB manifest and test Android's system Photo
Picker on API 33–36, cancellation, one-item selection, denied camera access, and
Community/meal image upload. A future library must not reintroduce broad media
permissions without a core continuous-access use case and Play declaration.

## 8. Advertising, UMP, and the absolute health-data boundary

Google policy prohibits using health data for personalized or interest-based
advertising. BIL's source policy accepts only entitlement, consent, age/region,
placement, online state, and provider readiness. It explicitly excludes health,
nutrition, weight, profile, location, search, and diagnosis data. Ads are:

- restricted to a verified Free entitlement;
- suppressed for paid users;
- suppressed while age or region is unknown/restricted;
- suppressed for users under 18;
- allowed only at `generalDiscovery`, not Dashboard, Daily Log, food entry,
  progress, weekly reports, Connected Health, profile, settings, or paywall;
- requested with `AdRequest(nonPersonalizedAds: true)`;
- gated by Google UMP `canRequestAds` on Android;
- unable to consume health/profile/search payloads by type/API design.

The repository contains a Google UMP coordinator with fail-closed behavior and
privacy-options form support. This is not proof that the required GDPR message
is configured and published in AdMob for EEA/UK/Switzerland. Required manual
checks:

1. Configure/publish the Google-certified consent message in AdMob.
2. Confirm production app ID, banner IDs, publisher ID, and `app-ads.txt`.
3. Test EEA, UK, Switzerland, US-state, and non-regulated-region behavior using
   Google's test-device/geography tools on a Play-installed build.
4. Verify decline/withdraw/privacy-options/reinstall flows and fail-closed ads.
5. Answer **Yes** to Play's **Contains ads** question while the production
   artifact integrates Google Mobile Ads/banner code. Fail-closed flags or ads
   being conditional do not turn an ad-SDK build into an `ads: none` build.
6. Declare device/advertising identifiers and SDK purposes in Data Safety.
7. Confirm no custom targeting keywords, user IDs, health values, food searches,
   or AI conversation content enter Google Mobile Ads requests/logs.

Google's current GMA SDK 25.4.0 disclosure says the SDK automatically collects
and shares IP address (which may estimate general/approximate location), user
product interactions, diagnostics, and device/account identifiers for
advertising, analytics, and fraud prevention. The current public privacy copy
does not enumerate those GMA data categories with equivalent specificity. That
privacy/Data Safety mismatch must be resolved before production ads operate.
Non-personalized/contextual serving does not erase these SDK disclosures.

## 9. AI-generated content policy

AI Coach is a text/voice chatbot and is in scope for Google Play's AI-generated
content policy.

Implemented safeguards found:

- Remote AI requires explicit remote-AI consent and entitlement/quota gates.
- The server prompt contains medical-safety and red-flag/escalation boundaries.
- Every rateable generated Coach answer now exposes **Report answer** and a
  **Report unsafe or offensive answer** action without leaving the app.
- The report explains that it is for unsafe, offensive, hateful, sexual,
  deceptive, or otherwise harmful content.
- Feedback records the response identifier and safety category, not the user's
  question or full answer text.
- The report title, explanation, action, and confirmation now resolve for all 25
  app locales; an Arabic RTL widget check at 160% text scale passes locally.

Open actions:

- Prove that reports reach an operational queue, have an assigned moderation
  owner/process, and feed filtering/moderation improvements. A database row
  alone is insufficient; Google does not prescribe a numeric SLA here.
- Run adversarial tests for self-harm, eating disorders, minors, sexual content,
  hate, violence, illegal drugs, medical diagnosis/treatment, dangerous weight
  loss, prompt injection, and requests to expose another user's data.
- The Gemini call did not show explicit provider `safetySettings` in this audit;
  document the effective model defaults or add tested explicit thresholds after
  product/safety review rather than guessing.
- Maintain an incident response/appeal process and retain only the minimum report
  data needed for moderation.

Google Play also has a Console declaration for AI-generated assets used in Store
listing, Promotional content, and linked YouTube material. Review **each asset
actually uploaded to Play Console** and label it when the declaration page says
it is in scope. AI-generated images used only inside the app are not
automatically the same Console-asset declaration.

## 10. UGC, Community, and Child Safety Standards

### 10.1 General UGC controls

| Requirement | Evidence | Result |
|---|---|---|
| Accept terms/policy before publishing | Server migration requires active `bil_content_policy_acceptances` before posts/messages | PASS locally |
| Define prohibited content | Terms/community copy prohibits harmful/abusive content and contact exchange | PASS_WITH_ACTIONS; legal review |
| Ongoing moderation | Moderator-only report RPCs and audit actions exist | PASS_WITH_ACTIONS; operational ownership/process not proved |
| Report content | Content/post reporting path exists | PASS locally |
| Report a user | Connections now exposes `Report member` | PASS locally |
| Block a user | Block member flow and server policy exist | PASS locally |
| Restrict direct messaging | Authenticated, connection/privacy based; no anonymous random chat found | PASS locally |

Run a two-account physical-device test for acceptance, posting, report, block,
profile invisibility, friend removal, message denial, moderator resolution, and
repeat-offender action. Confirm report and block remain available on every UGC
surface, including images and direct messages.

### 10.2 Social-app / Child Safety applicability

BIL's primary direction is Health & Fitness, and no anonymous or random chat was
found. It nevertheless contains user profiles, posts, friendships, images, and
direct messages. The owner must answer Play's classification questions using the
actual feature set, not only the chosen store category.

The 26 August 2026 expansion described by Google concerns anonymous or random
chat. BIL was not found to offer anonymous/random chat, so that expansion alone
does not capture the current connection-based Community. The following are a
**production blocker** if Play classifies BIL as a Social app under the policy
that already applies to Social apps, or if BIL later adds anonymous/random chat:

- public standards explicitly prohibiting child sexual abuse and exploitation
  (CSAE) and child sexual abuse material (CSAM);
- a published child-safety point of contact;
- an operational process for CSAM detection/reporting/removal and compliance
  with applicable reporting duties;
- in-app reporting for child-safety concerns;
- Play Console Child Safety Standards self-certification.

The public Terms and Privacy routes are reachable, but `/community-guidelines`
is only an HTTP-200 SPA shell and renders a 404 because the route is absent.
No functional public Community Guidelines/Child Safety page with explicit
CSAE/CSAM standards was proved. Do not give that broken route to Play. If the
conditional policy applies, publish the required standards and operations or
obtain a defensible Console classification before production.

## 11. Target audience, age eligibility, Families, and IARC

The owner resolved the product decision on 24 August 2026: the Google Play
release is **18+ only**. This is no longer an unresolved audience-selection
blocker. The local public-site source now says 18+ in English and Arabic Privacy
and Terms, and all five store-description drafts state adults 18+. This audit did
not deploy the website or change Play Console, so the following remain required
before submission:

- publish the updated Privacy/Terms source and verify the live pages no longer
  say 13+;
- select only the truthful 18-and-over group in Target audience and content;
- complete IARC from the actual AI, UGC, messaging, health, photo, and voice
  functionality rather than inferring a rating from Health & Fitness;
- keep marketing, screenshots, onboarding, support, and Community moderation
  adult-oriented and do not knowingly permit under-18 accounts;
- use Play's Restrict Minor Access controls if applicable to the account/release
  configuration and preserve evidence of the chosen enforcement behavior.

The existing ad gate continues to fail closed unless an adult state is resolved,
but an advertising toggle alone is not account-age enforcement. A neutral age
screen is not universally required for this adult-only route. If the owner later
adds a child or mixed-audience group, reassess Families requirements and use a
neutral age screen where that route requires one; a prompted “I am an adult”
switch is not a neutral date-of-birth screen.

## 12. Account deletion

Observed implementation:

- in-app deletion request is available from account/profile settings and
  requires explicit confirmation;
- the request calls authenticated `bil_request_account_deletion`;
- the private scheduled worker hard-deletes the Supabase Auth user and relies on
  owned-data cascade behavior;
- `https://www.bilhealth.com/account-deletion` is public, names BIL, explains the
  in-app path, offers an email route when the app is unavailable, and describes
  scope, retention, status, and cancellation separately;
- the page and in-app copy distinguish cloud-account deletion from local device
  data and from simply uninstalling the app.

Before declaring PASS in Console:

1. Submit a test-account deletion in a non-production test environment.
2. Prove worker pickup, Auth deletion, row/storage cascade, revocation of active
   sessions/tokens, and inability to sign back in as the old account.
3. Verify transactional/legal retention and backup expiry match the public page.
4. Verify the email/manual route is monitored and works without reinstalling.
5. Confirm the public URL remains reachable without login in all target regions.
6. Enter the exact `/account-deletion` URL in Play Console.

No test user was created or deleted by this audit.

## 13. Subscriptions and Play Billing

Source evidence supports:

- localized prices from `ProductDetails`, not hard-coded checkout prices;
- base-plan/offer token preservation and free-trial offer selection;
- pending/cancelled/error/purchased/restored handling;
- `restorePurchases()`;
- server verification before `completePurchase()` acknowledgement;
- external Google Play Subscription Center management link;
- backend verification via Android Publisher
  `/purchases/subscriptionsv2/tokens/...` (SubscriptionPurchaseV2);
- mapping for trial, active, grace, billing retry, account hold, paused,
  cancelled, expired, refunded, and revoked states.

This is aligned with Google's post-1-December-2025 account-hold guidance, but it
still needs Play-installed live tests:

- monthly/annual purchase, trial conversion copy, tax/localized price;
- pending cash purchase and app restart;
- acknowledgement/retry/idempotency;
- cancellation, grace period, account hold, recovery, expiry, refund/revoke;
- upgrade/downgrade/replacement mode;
- restore after reinstall/device change;
- entitlement removal and immediate ad re-evaluation;
- Subscription Center link and accessibility.

The store page must show the localized price, billing period, trial duration,
post-trial price, automatic renewal, and cancellation terms supplied by Play.
Repository metadata is not proof that configured base plans/offers match.

## 14. Data Safety decision matrix

This matrix is an owner-review input, not a pre-filled Console answer. “Shared?”
depends on Google's service-provider exception and the actual vendor contracts;
the audit intentionally does not guess that legal classification. Under Play's
definition, **collection means transmitting data off the user's device**. Data
accessed and processed only on-device is not collected for the Data Safety form.
If the same field is later sent by sync, AI, an SDK, or another remote feature,
that off-device path is collected and must be declared. Even ephemeral off-
device processing must be included when completing the form.

| Play data type / example | Collected in current capability? | Shared? | Ephemeral? | Purpose | Required or optional | Deletion/retention evidence |
|---|---|---|---|---|---|---|
| Email address, user ID, auth/session data | Yes when an account is used | Usually service-provider processing; owner must verify | No | Account management, authentication, security | Optional for local-only use; required for cloud features | Account deletion worker + public process |
| Display name, avatar, bio | No for local-only editing; yes when profile/Community transmits it | Contract review | No for stored cloud profile | App functionality, user communication | Optional | Profile edit + account deletion |
| Date of birth/age, biological sex, height | No while processed only on-device; yes if account sync/remote personalization transmits it | Contract review; never ads | Depends on endpoint; do not assume | Body model, personalization | Some body-model features require them | Edit/local deletion/account deletion |
| Country, postcode, time zone | No while local-only; yes if profile/account sync transmits it | Contract review; never ads | Depends on endpoint | Localization/profile functionality | Optional | Edit/local deletion/account deletion |
| Device location from Android location APIs | No off-device collection observed; legacy BLE permissions apply only through API 30 | No observed sharing | N/A | Legacy BLE discovery only | Conditional legacy runtime permission | Recheck network capture on API 26–30 |
| IP address / IP-inferred general location | **Yes when GMA 25.4.0 operates**; Google says IP is automatically collected and may estimate general location | **Yes by GMA's current disclosure** | Not claimed ephemeral | Advertising, analytics, fraud prevention | Conditional ad route; automatic within that route | Google/vendor controls; owner must map current privacy/retention terms |
| Weight, waist, neck, body composition and goals | No while local-only; yes if cloud sync or consented AI context transmits them | Contract review; **never ads** | Depends on remote path | Health/app functionality, personalization | Optional/feature-dependent | Local lifecycle + account deletion |
| Nutrition, meals, calories, macros, hydration | No while local-only; yes if cloud sync or consented AI transmits them | Contract review; **never ads** | Depends on remote path | Health/app functionality, AI features | Optional/feature-dependent | Local lifecycle + account deletion |
| Steps, active calories, exercise, sleep, HR, resting HR, HRV, SpO2 | No when Health Connect data stays on-device; yes only if a sync/AI path transmits selected values | Contract review; **never ads** | Depends on remote path | Connected-health functionality and user-visible insights | Optional | Revoke HC; local/account deletion |
| BLE fitness-device identity and weight/body-composition/heart-rate measurements | No while paired/read only on-device; yes if cloud sync/AI transmits identity or measurements | Contract review; **never ads** | Depends on remote path; identity may persist | Connected-fitness-device functionality | Optional | Disconnect/local/account deletion |
| Meal/profile/community photos | No for local-only capture; yes when profile/Community upload or consented meal analysis transmits pixels | Supabase/Gemini/vendor contract review | Depends on feature; Community/profile images persist | App functionality, UGC, AI meal analysis | Optional | Delete content/profile/account; verify storage cascade |
| Voice/audio recording | Yes when remote voice/AI or an app-controlled network recognizer transmits audio; purely on-device recognition is not collection | Gemini/OS provider contract review | Provider retention must be verified before selecting ephemeral | Voice input/AI functionality | Optional | No raw-audio persistence proved in BIL; verify vendor terms/logs |
| AI prompts, minimal body context, and responses | Yes when remote AI consent is enabled | Gemini service-provider classification requires owner review | Request processing may be transient, but usage/feedback records persist | AI Coach functionality, safety, fraud/quota | Optional/consent-gated | Conversation/memory controls + account deletion; verify logs |
| AI safety feedback/report category and response ID | Yes when user reports/rates | Contract review | No | Safety, moderation, product improvement | Optional | Account deletion/retention policy required |
| Community posts, images, messages, friendships, reports/blocks | Yes when Community is used | Other users receive intentionally public/shared UGC; vendor processing requires review | No | Social/app functionality, safety/moderation | Optional | Content controls + account deletion; moderation retention review |
| Contacts | No address-book upload observed; user invokes local/system contact selection for invitation | No observed sharing by BIL | N/A | User-initiated invitation | Optional | Recheck final behavior/network capture |
| Purchase tokens, products, subscription status/history | Yes for commerce | Google Play + backend processing | No | Purchase validation, entitlement, fraud prevention | Required only for purchase | Legal/transaction retention + account deletion disclosure |
| Play Integrity token/device verdict | Yes when integrity check runs | Google Play/backend processing | Token transient; security log retention must be documented | Security, fraud prevention | Conditional | Security retention policy |
| Device/account identifiers and ad ID | **Yes when GMA 25.4.0 operates**; Google lists ad ID, app set ID, and applicable account-related identifiers | **Yes by GMA's current disclosure** | Not claimed ephemeral | Advertising, analytics, fraud prevention | Conditional ad route; automatic unless supported identifier controls disable a subtype | Ad/privacy controls and Google/vendor retention |
| GMA user product interactions | **Yes when GMA 25.4.0 operates**; Google lists app launch, taps, and video views | **Yes by GMA's current disclosure** | Not claimed ephemeral | Advertising, analytics, fraud prevention | Conditional ad route; automatic within that route | Google/vendor controls; privacy disclosure required |
| Other app interactions / in-app search | No while only local; yes when remote search, AI, observability, or another endpoint transmits the event/query | Vendor/endpoint-specific review; never send health/search content to ads | Mixed | App functionality, search, security, quota | Feature-dependent | Local/account deletion; log retention review |
| Diagnostics/app performance | **Yes when GMA 25.4.0 operates** for items such as launch time, hang rate, and energy usage; BIL's own crash sink appears local/disabled | **Yes by GMA's current disclosure** for its SDK diagnostics | Not claimed ephemeral by GMA | Advertising, analytics, fraud prevention; reliability for any separate crash tool | Automatic within active GMA route | Google/vendor controls; do not answer “none” |
| Exported files | Generated locally and handed to OS share sheet | User chooses recipient; BIL does not control destination | User-controlled | User-requested export | Optional | User controls exported copy |

The GMA rows above are not speculative network-test findings: they follow
Google's official 25.4.0 disclosure, which says these categories are collected
and shared automatically. The owner still must complete the app-level form and
decide any applicable service-provider/user-initiated exceptions. The public
privacy policy must be revised to match the final SDK-enabled behavior before
submission; generic references to advertising providers are not enough to cure
an inaccurate Data Safety form.

Required Data Safety procedure:

1. Build/sign the exact production AAB with final environment and SDK IDs.
2. Inventory all resolved Android dependencies and merged permissions.
3. Exercise every account, sync, AI, voice, meal-photo, Community, purchase, ad,
   Health Connect, BLE, export, and deletion path through a TLS-aware network
   test environment that does not bypass certificate security in production.
4. Map observed fields and endpoints to the table above.
5. Review vendor contracts to decide Play's “shared” and “service provider”
   exceptions; do not infer from brand ownership.
6. Verify each allegedly local-only field never crosses an endpoint in the
   corresponding route; local database presence alone is not collection.
7. Ensure privacy policy, in-app disclosures, retention, and deletion match.
8. Have the owner approve the final Console selections and save evidence.

## 15. Third-party SDK and service matrix

| SDK/service | Current role | Potential data | Required release action |
|---|---|---|---|
| Supabase Auth/Database/Storage/Realtime/Edge Functions | Accounts, cloud sync, Community, AI gateway, commerce state | Account, profile, health/nutrition if synced, UGC, files, prompts, tokens | Verify RLS, region, retention, subprocessors, deletion cascade, Data Safety classification |
| Google Gemini through BIL Edge Function | AI Coach and meal/voice analysis | Prompts, minimal context, images/audio when enabled | Verify consent, safety settings/defaults, retention/training contract, report loop, Data Safety |
| Google Mobile Ads Flutter 9.1.0 / native Android SDK 25.4.0 + UMP | Contextual Free-tier banner and consent | Google documents automatic collection/sharing of IP (possibly general location), product interactions, diagnostics, and device/account identifiers | Declare **Contains ads: Yes**, configure CMP, keep health payloads out, reconcile identifier/attribution permissions, update privacy copy, and answer Data Safety from Google's disclosure plus final app behavior |
| Google Play Billing | Products, purchases, restore | Purchase token, account hash, product/status | Live lifecycle test and Data Safety purchase row |
| Google Play Integrity 1.6.0 | Anti-fraud/request integrity | Integrity token/device verdict | Verify binding, retention, false-positive recovery, Data Safety security purpose |
| AndroidX Health Connect 1.1.0 | User-authorized health records | Twelve declared read/write types | Complete HC declaration and physical-device tests |
| Camera/image picker/mobile scanner | Meal/community/profile photos and barcode | Image pixels, barcode, camera state | Just-in-time permission; system picker; remote-upload disclosure |
| Native speech/TTS | Dictation and spoken Coach replies | Audio/transcript; output speech | Test OS/provider behavior by locale; disclose remote audio when used |
| Flutter local notifications | Reminders/reports | Local schedules/content | OEM/reboot/time-zone/lock-screen privacy tests |
| Drift/SQLite/secure storage/preferences | Local-first persistence | Profile, health, meals, consent, tokens/keys | Encryption/key boundary, export/delete, backup-disabled checks |
| Cloudflare-hosted public/media delivery | Policies, recipe/workout/media assets | Normal HTTP delivery metadata | Verify URL uptime, access logs/retention, privacy disclosure where applicable |
| Remote food/catalog lookups | Barcode/search enrichment when configured | Query/barcode/IP | Verify provider, key, logs, Data Safety, and privacy disclosure |
| In-app review | Opens Play review surface | Play-controlled interaction | Test only on Play-installed build; do not gate or incentivize rating |

## 16. Manual Play Console checklist

Do not mark production ready until evidence is stored for each item:

- [ ] Confirm BIL's new/existing production status and that the uploaded AAB
      targets API 36 before 31 August 2026.
- [ ] Complete Health Apps declaration using only truthful current categories.
- [ ] Verify the final signed AAB still exposes only weight-scale (`181D`), body-
      composition (`181B`), and heart-rate (`180D`) fitness BLE profiles; preserve
      that evidence for the **Medical Device Apps: not applicable** answer and
      reopen the classification if intended devices, purpose, or claims change.
- [ ] Complete the Health Connect form for exactly the twelve permissions in
      section 5, with the visible-feature justifications shown there.
- [ ] Set the public privacy URL to `https://www.bilhealth.com/privacy` and verify
      non-geofenced HTML reachability.
- [ ] Set the account-deletion URL to
      `https://www.bilhealth.com/account-deletion`.
- [ ] Replace every old Data Safety answer with the owner-approved result of
      section 14 and the final signed-AAB network/SDK audit.
- [ ] Apply the owner's 18+-only decision in Target audience, publish the local
      Privacy/Terms changes, keep app/listing/marketing consistent, prevent known
      minors, and complete IARC from actual features.
- [ ] Decide Social/Child Safety applicability. If applicable, publish explicit
      CSAE/CSAM standards, point of contact, operational process, in-app report,
      and Console self-certification before production.
- [ ] Declare **Contains ads: Yes** while Google Mobile Ads/banner integration is
      present, and publish/test the AdMob UMP consent message.
- [ ] Reconcile GMA 25.4.0 IP/general-location, product-interaction, diagnostics,
      and device/account-identifier disclosure with Data Safety and the public
      privacy policy.
- [ ] Verify app-access reviewer credentials and exact visible navigation labels.
- [ ] Configure all Play subscription base plans/offers, localized prices,
      trials, grace/account-hold behavior, and RTDN/API credentials.
- [ ] Review each Store listing/Promotional content/YouTube asset under the
      AI-generated-content declaration and label only assets in scope.
- [ ] Confirm Android developer identity verification and package registration;
      Google's rollout references 30 September 2026 for the new requirement.
- [ ] Review every localized store description/creative for non-medical and
      external-fitness-hardware truth; do not claim the phone itself measures.
- [ ] Verify category, content rating, ads, privacy, support email, website,
      developer identity, countries, pricing, and app signing.
- [ ] Run pre-launch report and internal-track tests from the final signed AAB.
- [ ] Verify 16 KB page-size compatibility for the API 36 AAB. Current Google
      guidance makes support mandatory for target 35+ and blocks incompatible
      updates starting 1 February 2027; this is a compatibility/release-QA item
      now, not an August 2026 policy deadline.

## 17. Emulator evidence versus real-device-only gates

### Evidence obtained locally/emulator

- Gradle release/debug manifest processing and debug Kotlin compilation passed.
- The generated release manifest contains 33 unique permissions and omits broad
  media/storage, legacy body-sensor, background-health, and Topics permissions.
- Focused Android integration tests previously reported 52/52 passing.
- A debug APK built and installed with `adb install -r` on API 35 without
  uninstalling or clearing the account.
- API 35 exposed the Health Connect service and launched the rationale activity.
- Emulator BLE feature/adapter presence was observed; no fitness peripheral was
  connected.
- A local high-importance notification with BIL icon/color/BigText and private
  visibility opened the reminder destination.
- Policy-focused Flutter tests for the local fixes passed before final report
  generation; the final command evidence is listed in section 19.

### Must be proved on physical/Play-installed devices

- Health Connect provider install/update, partial grants, real reads/writes,
  revoke, source labels, deletion, and duplicate prevention.
- BLE scan/pair/GATT notification/indication/parser behavior for supported weight-
  scale, body-composition, and heart-rate profiles, including failure/reconnect.
- Camera, system Photo Picker, barcode flash, microphone, speech recognition,
  male TTS voice availability, and audio privacy by representative locales.
- OEM notification delivery, lock-screen privacy, reboot restore, Doze/battery
  optimization, exact alarms if used, time-zone and DST changes.
- Play Billing purchase sheet, pending purchases, restore, account hold, refund,
  acknowledgement, and subscription-management link.
- UMP regulated-region flow and production contextual ads.
- In-app review surface.
- Final AAB API 36 behavior, 16 KB devices, tablets, RTL, and 160% text.

## 18. Minimal local changes made by this audit

The workspace was already heavily modified by other active agents. This audit
did not reset, overwrite, or claim unrelated work. Its scoped changes are:

1. Removed transitive legacy external-storage permissions from manifest merge.
2. Removed `ACCESS_ADSERVICES_TOPICS`; left AD_ID/attribution merger surfaces
   unchanged pending the owner's measurement/opt-out decision and final ad/UMP
   regression test. Their presence is not asserted as required for NPA.
3. Added a public privacy-policy action to the Health Connect rationale.
4. Added an in-app unsafe/offensive reporting action to rateable AI Coach
   answers and persisted the safety reason through the existing feedback RPC.
5. Added `Report member` from Community connections while preserving block.
6. Added exact non-medical and external-fitness-device disclosures to all five
   localized store-description drafts and corrected the language claim to 25.
7. Corrected the store inventory version/language count.
8. Marked the obsolete Data Safety draft **DO NOT SUBMIT** and linked it here.
9. Enforced the owner's fitness-only BLE product boundary in native discovery,
   restore/connect, parsing, policy, and display: only weight scale (`181D`),
   body composition (`181B`), and heart rate (`180D`) remain; blood-pressure,
   glucose, pulse-oximetry, and thermometer BLE profiles were removed.
10. Replaced obsolete medical-device UI/runtime claims with compatible fitness-
    device wording across the 25-language runtime copy while preserving the
    non-medical disclaimer and Health Connect functionality.

No Play Console, AdMob Console, Cloudflare, production Supabase, production
user, or remote-data mutation was performed.

## 19. Verification commands and results

Already completed during this audit chain:

```text
flutter test test/runtime_permission_design_contract_test.dart \
  test/android_launch_readiness/android_launch_contract_test.dart \
  test/intelligence_center_composer_contract_test.dart \
  test/features/community/community_authenticated_interaction_test.dart \
  test/launch_readiness/ai_coach_closed_test_and_consent_contract_test.dart
Result: 38/38 PASS

flutter analyze \
  lib/features/intelligence_center/presentation/intelligence_center_message_widgets.dart \
  lib/features/intelligence_center/presentation/intelligence_center_page.dart \
  lib/features/intelligence_center/services/ai_coach_feedback_service.dart \
  lib/features/community/presentation/community_connections_page.dart
Result: No issues found

flutter test test/features/ads \
  test/launch_readiness/epic16_ad_privacy_contract_test.dart
Result: 35/35 PASS (UMP, adult/region fail-closed gates, contextual-only
placements, paid suppression, privacy options, and layout)

gradlew :app:processDebugMainManifest :app:processReleaseMainManifest \
  :app:processReleaseManifestForPackage :app:compileDebugKotlin
Result: BUILD SUCCESSFUL

gradlew :app:dependencyInsight --configuration releaseRuntimeClasspath \
  --dependency androidx.work:work-runtime
Result: `work-runtime:2.7.0 <- play-services-ads-api:25.4.0 <- google_mobile_ads`

Generated-manifest policy script
Result: 33 unique permissions; forbidden body-sensor/background-health/
broad-media/storage/Topics permissions absent; no `foregroundServiceType` or
type-specific foreground-service permission

Fitness-only BLE source and contract gate
Result: 21/21 PASS; scoped Dart format (23 files, zero changes) and `flutter
analyze --no-pub` PASS; native services are
181D/181B/180D and parsed characteristics are 2A9D/2A9C/2A37; disallowed service
and characteristic UUIDs are absent from product paths

Fitness-only UI/runtime copy gate
Result: `flutter analyze` PASS; 17/17 focused tests PASS; scoped user-facing copy
contains no obsolete medical-device or BP/glucose/oxygen/temperature BLE list

Store metadata/document validation
Result: JSON parse PASS; five titles <=30, short descriptions <=80, full
descriptions <=4000; each full description contains the 25-language and 18+
claims, non-medical disclaimer, and external-fitness-device requirement;
`public_site/app.js` JavaScript syntax PASS

Independent focused Android integration set
Result reported by Android release agent: 52/52 PASS
```

The final verification pass parsed the metadata JSON, enforced Play description
lengths, inspected the generated permission and BLE allowlists, and reran the
focused policy tests after the scoped concurrent changes completed. The signed-
AAB and Play-installed/physical-device checks remain the release-QA gate.

## 20. Official Google sources

- [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Health Content and Services](https://support.google.com/googleplay/android-developer/answer/16679511?hl=en)
- [Health Connect permissions declaration](https://support.google.com/googleplay/android-developer/answer/14738291?hl=en)
- [Publish a Health Connect app](https://developer.android.com/health-and-fitness/health-connect/publish)
- [Get started with Health Connect](https://developer.android.com/health-and-fitness/health-connect/get-started)
- [Android 16 behavior changes](https://developer.android.com/about/versions/16/behavior-changes-16)
- [Health permissions policy](https://support.google.com/googleplay/android-developer/answer/12991134?hl=en)
- [AI-generated content policy](https://support.google.com/googleplay/android-developer/answer/13985936?hl=en)
- [Declaring AI-generated Store content](https://support.google.com/googleplay/android-developer/answer/17262077?hl=en)
- [User-generated content policy](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en)
- [Child Endangerment / Child Safety Standards policy](https://support.google.com/googleplay/android-developer/answer/9878809?hl=en)
- [Child Safety policy updates](https://support.google.com/googleplay/android-developer/answer/14747720?hl=en)
- [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)
- [Data Safety form](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Photo and Video permissions](https://support.google.com/googleplay/android-developer/answer/16935362?hl=en)
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- [Subscriptions policy](https://support.google.com/googleplay/android-developer/answer/9900533?hl=en)
- [Subscription account-hold changes](https://support.google.com/googleplay/android-developer/answer/16631229?hl=en)
- [Medical-record policy update](https://support.google.com/googleplay/android-developer/answer/15931464?hl=en)
- [Target audience and content](https://support.google.com/googleplay/android-developer/answer/9859655?hl=en)
- [Content ratings](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)
- [Families policy](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)
- [Android developer verification](https://support.google.com/googleplay/android-developer/answer/16984799?hl=en)
- [AdMob ad-serving modes](https://developers.google.com/admob/flutter/privacy/ad-serving-modes?hl=en)
- [AdMob UMP for Flutter](https://developers.google.com/admob/flutter/privacy/gdpr?hl=en)
- [Ad Privacy Sandbox controls](https://developers.google.com/admob/android/privacy/sandbox?hl=en)
- [Google Mobile Ads SDK 25.4.0 Play data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure?hl=en)
- [Prepare app for review / Contains ads](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)
- [Android 16 KB page-size compatibility](https://developer.android.com/guide/practices/page-sizes)

## 21. Final release verdict

```text
GOOGLE_PLAY_HEALTH_AUDIT_RESULT: BLOCKER_FOUND
```

The code-level permission and policy boundaries are substantially implemented.
Policy submission remains blocked specifically on publishing and applying the
owner's 18+-only boundary, final Data Safety/Health/Health Connect Console
declarations, the live GMA privacy-disclosure mismatch, and conditional Child
Safety closure. The fitness-only BLE/non-medical boundary removes the earlier
Medical Device Apps classification blocker for this release. Operational AI/UGC
moderation proof is still required where those features operate. Real-device and
Play-track evidence from the final signed AAB is a separate release-QA gate and
supports truthful claims, but its absence is not itself the basis for the policy
`BLOCKER_FOUND` result.
