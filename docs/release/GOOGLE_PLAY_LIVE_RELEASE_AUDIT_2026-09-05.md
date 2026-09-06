# Google Play live release audit — 2026-09-05

## Decision

`GOOGLE_PLAY_PRODUCTION_READY=NO`

`GOOGLE_PLAY_ALLOWED_RELEASE_ARTIFACT=BUILD_8_OR_LATER_ONLY`

`GOOGLE_PLAY_BUILD_7_PRODUCTION_PROMOTION=FORBIDDEN`

This is an authenticated Play Console read-back plus a narrow source/public-link
comparison performed on 5 September 2026. The last evidence capture in this
document was at 19:11 EEST / 16:11 UTC. No AAB was built or uploaded, no track
was promoted, no production-access application was submitted, and no
production rollout was started.

The only live mutation in this audit was the owner-authorized price correction
for the active yearly base plan of `bil_premium_ai_coach_annual`. Its US price
was changed from USD 35.99 to USD 49.99. Google Play confirmed that the new
price applies to new subscribers; no existing-price cohort was migrated.

## Live application and track state

| Item | Authenticated live read-back |
| --- | --- |
| Developer account | Personal account |
| App | Body Intelligence Log |
| Package | `com.bilhealth.bodyintelligencelog` |
| Installed audience | 12 |
| Overall state | Closed testing |
| Last Play app update shown | 1 September 2026 |
| Production | Inactive |
| Production access | Eligible to apply, but the application has not been submitted |
| Closed testing / Alpha | Build `7 (1.0.0)`, available to testers, full rollout, 177/177 countries |
| Open testing | Not started |
| Internal testing | Not started |
| Internal app sharing | Not started |
| Uploaded version codes | 1, 2, 3, 4, 5 and 7 |
| Uploaded build 8 | **No** |

The three production-access prerequisites are shown complete: a closed-test
release exists, at least 12 testers opted in, and at least 12 testers remained
opted in for at least 14 days. The application itself still needs owner answers
about tester recruitment difficulty and the expected first-year install range.
Those answers must not be invented by an agent.

Pre-registration is unavailable before production access. The anonymous public
listing URL returned HTTP 404 at the audit time, which is consistent with an
unpublished production listing:

`https://play.google.com/store/apps/details?id=com.bilhealth.bodyintelligencelog`

The existing build 7 is not the repaired candidate and must never be used to
apply for, submit, or roll out production. The repository declares
`version: 1.0.0+8`, but that source declaration is not an uploaded or verified
artifact.

## Existing build 7 bundle evidence

Play reports build 7 as 6.03 MB, covering 12,516 devices and 88 localisations,
with small, normal, large and xlarge layouts; `arm64-v8a` and `x86_64`; minimum
API 26; target SDK 36; and 16 KB page-size support. R8 full mode and resource
shrinking are reported, with 86% optimization. This describes build 7 only and
does not prove the current dirty `+8` source.

No current pre-launch report exists for build 8 because no build 8 has been
uploaded. Play's 16 KB result also carries its usual caveat that some native
libraries may not be detected. The clean signed build 8 workflow must retain
bundletool manifest, native ELF alignment, target SDK, optional-feature and
signature evidence before upload.

## Signing certificate, website association and deep links

Play App Signing is active and Google-managed. The live **app-signing** SHA-256
is:

`DE:CA:D2:7C:36:64:0E:2E:07:54:63:2A:BE:EF:A9:ED:ED:ED:9E:F6:D7:93:D9:50:0A:EB:B4:49:3D:43:08:F4`

The public `https://www.bilhealth.com/.well-known/assetlinks.json` returned HTTP
200 and contains exactly the same package and app-signing fingerprint. Google's
Digital Asset Links API returned one matching statement. The separate Play
upload-certificate fingerprint was checked in Console and is intentionally not
published in `assetlinks.json`.

The account-level **Android developer verification** page shows
`com.bilhealth.bodyintelligencelog` as **Registered**, last updated 18 August
2026, with four package keys and all four marked **Verified**. The verified-key
list includes the same Play app-signing SHA-256 above. This closes the package
registration requirement for this package; no registration action is pending.

The live deep-link inspector for build 7 says **No web links found** and **No
domains found**. It sees only the custom schemes `bil://` and
`bil://auth-callback`, routed to `MainActivity`. Therefore a claim that build 7
already contains verified HTTPS App Links would be false.

Current build-8 source adds two narrow `android:autoVerify="true"` intent
filters for:

- `https://www.bilhealth.com/auth/callback`
- `https://www.bilhealth.com/auth/reset-password`

and keeps `bil://` as a non-verified custom scheme. The Dart allow-list names the
same two credential-bearing HTTPS paths. This source/live difference is
expected until a signed build 8 is uploaded. After upload, the generated bundle
manifest and Play deep-link inspector must both be checked, followed by an
installed-device App Link test.

## Play Integrity and linked Google Cloud project

| Integrity item | Live state |
| --- | --- |
| Protected with Play | High protection |
| Automatic protection | 1/1 active |
| Play Integrity API | 7/7 active |
| Play Store protection | 6/7 active |
| Missing Play Store item | Store listing device checks are off |
| Play Billing protections | 4/4 active |
| Integrity requests, last 30 days | No data / no requests |
| Linked project name | BIL Health |
| Linked project ID | `bil-health` |
| Linked project number | `1041595138122` |
| Daily request limit | 10,000 |
| Cloud API | Google Play Integrity API enabled |

The enabled response fields are app licensing, application integrity, device
integrity, recent device activity, device attributes, Play Protect status and
app access risk. Classic request encryption is Google-managed.

Repository/GitHub read-back shows the signing secrets exist. During this audit,
`BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID` was created and its presence was read
back successfully. Its evidence describes the currently deployed compatibility,
non-enforced integrity backend boundary; its value is intentionally not copied
into this document. A fresh authenticated GitHub REST read-back on 2026-09-05
also confirms that `BIL_PLAY_INTEGRITY_PROJECT_NUMBER` exists and equals the
exact live number `1041595138122`. The Android workflow deliberately fails
closed if either input is removed. These authenticated read-backs, rather than
a source-tree claim or guessed value, are the deployment evidence.

No strict enforcement should be enabled solely from source evidence. First
install the signed Play-delivered build 8, observe genuine integrity requests
and verdicts, verify replay/request binding and rejection paths, and then make a
separate enforcement decision.

## Live subscription and one-time-product read-back

### Ordinary Premium — owner-confirmed four-country catalogue

The owner instructed that the current ordinary Premium four-country catalogue
is correct and must not be changed. The live countries are **EG/NG/PK/TR**, not
the stale EG/IN/PK/TR contract found in older documents.

| Product | Egypt | Nigeria | Pakistan | Türkiye |
| --- | ---: | ---: | ---: | ---: |
| `bil_premium` monthly | EGP 99.99 | NGN 1,859 | PKR 599 | TRY 99.99 |
| `bil_premium_annual` yearly | EGP 599.99 | NGN 11,159 | PKR 3,599 | TRY 599.99 |

Both products/base plans are active. The ordinary Premium catalogue was not
mutated in this audit.

### Premium + AI Coach

`bil_premium_ai_coach` is the active monthly subscription with an active
seven-day trial. It is available in 169 countries and its live US price is USD
5.99. Representative localized prices read back before the annual correction
included GBP 5.49, AUD 8.99, EUR 5.99 in major Euro storefronts, SAR 25.99, AED
22.99 and INR 690.

`bil_premium_ai_coach_annual` has an inactive erroneous sibling base plan named
`annual` with a monthly term. It was not edited. The correct active base plan is
`yearly`, with a one-year term and active seven-day trial.

Before mutation, the subscription report showed zero total subscriptions, zero
new subscriptions, zero cancellations, USD 0.00 gross revenue and zero refunds
through its displayed cutoff of 30 August 2026. Analytics can lag, so this was
not treated as proof that no account can exist. Play's confirmation explicitly
stated that the new price is for new subscribers and existing subscribers retain
their current price until a separate migration. No migration was requested or
performed.

On 5 September 2026, all 172 rows in the correct `yearly` price editor were
selected, USD 49.99 was entered, Play generated localized prices, and the change
was saved. The post-save read-back showed:

| Storefront | New yearly price |
| --- | ---: |
| United States | USD 49.99 |
| United Kingdom | GBP 44.49 |
| Australia | AUD 75.99 |
| Germany / Austria / France | EUR 49.99 |
| Saudi Arabia | SAR 214.99 |
| United Arab Emirates | AED 194.99 |
| India | INR 5,600 |
| Canada | CAD 68.99 |
| Japan | JPY 8,600 |

For the US pair:

`round((5.99 * 12 - 49.99) / (5.99 * 12) * 100) = 30%`

so **Save 30%** is mathematically correct for the US storefront. It is not a
truthful fixed worldwide promise because each localized monthly/annual pair can
round differently. The app source correctly calculates the percentage from
same-kind, same-currency store offers and renders that derived value; it does
not hard-code 30% into the production plan component.

### AI Boost — deliberately unchanged

`bil_ai_boost` has active base plan `standard-2500` in 173 countries. The US
base price is USD 4.99. The active `launch-50` offer is a 50% offer, starts 28
August 2026, runs indefinitely, and has no purchase limit; its live US result is
USD 2.50, not USD 2.49. Representative live values are GBP 2.19 and EGP 145.

The latest task instructions explicitly said not to change Boost. No Boost
price, date, entitlement or offer was edited. Older documents calling USD 2.49
the Google target conflict with live state and the latest instruction and must
not be presented as completed Google evidence.

## Policy declarations and public deletion surfaces

Play policy status shows **No issues found** and App content shows no declaration
needing attention. Ten declarations are actioned, including Advertising ID,
Data safety, Ads, Health apps, Sign-in details, target audience, content rating,
privacy policy, financial features and government apps.

- Ads declaration: contains ads = Yes.
- Advertising ID declaration: No.
- Data in transit: encrypted.
- Account authentication includes username/password and OAuth.
- Account deletion URL: `https://www.bilhealth.com/account-deletion` — HTTP 200.
- Partial data deletion URL: `https://www.bilhealth.com/data-deletion` — HTTP 200.
- Privacy URL: `https://www.bilhealth.com/privacy/` — HTTP 200.
- The app has an in-app **Delete account** route and an authenticated durable
  deletion request flow; the signed build still needs an end-to-end deletion
  test.

The current build-8 workflow sets both `BIL_ADS_ENABLED=false` and
`BIL_AD_PROVIDER_READY=false`, while Play says the app contains ads. Google
requires an accurate ads declaration and may verify it. Before submission,
inspect the final AAB and runtime for ad SDKs, banners, interstitials, native ads
and house ads. If the signed candidate genuinely has none, change Play to **No**;
if it does contain any, keep **Yes** and make the reviewer experience and Data
safety disclosure match. The present source/Console mismatch is not closed by
the actioned badge.

The Health apps declaration covers Activity and fitness, Nutrition and weight,
and Sleep. The detected Health Connect permissions include read steps, active
calories, exercise, sleep, heart rate, resting heart rate, HRV and weight, plus
read/write weight and read/write nutrition. Play shows completed justifications
for activity (3/3), body measurement (1/1), nutrition (1/1), sleep (1/1), and
vitals (3/3).

There is a material build-8 source/Console mismatch: the current Android
manifest also declares `READ_DISTANCE`, `READ_BODY_FAT`,
`READ_LEAN_BODY_MASS`, `READ_HYDRATION`, and `READ_HEALTH_DATA_HISTORY`
(`android/app/src/main/AndroidManifest.xml`, lines 68, 77-79 and 85). These
permissions are not present in the live build-7 permission read-back described
above. After build 8 is uploaded to a non-production track, re-open Health apps
and Data safety and either add truthful, feature-specific justifications for
every permission that survives manifest merging or remove permissions that the
shipping product does not need. An actioned build-7 declaration does not cover
new build-8 permissions.

The Data safety preview says the app shares approximate location, diagnostics,
app interactions and device identifiers for declared purposes including
analytics, fraud/security and advertising, and collects the declared personal,
purchase, health/fitness, message, photo, diagnostic, interaction, UGC and
device-ID categories. Search history is selected in the questionnaire but does
not appear in the preview, consistent only if it is handled ephemerally. The
clean build 8 binary/SDK inventory must be reconciled against this declaration;
the actioned status alone is not proof that it is accurate.

The account-level Android developer-verification identity tab contains the
personal-account legal identity imported from the Play developer account. The
Developer account > Contact details page marks contact email, contact phone and
public developer email **verified**. No account-verification action is surfaced.
The package is registered as described in the signing section above, so the 30
September 2026 package-registration requirement is satisfied for this package.

One separate trust item is still open: Developer account > About you says the
website `https://bilhealth.com/` has not yet been proven through Google Search
Console and offers **Send verification request**. No request was sent in this
audit because it notifies/depends on the external Search Console owner. This is
not shown as a production-access prerequisite, but it should be completed by the
account owner before submission so the public developer identity and website
are consistently verified.
Apple DSA/trader status is a separate Apple blocker and is not satisfied by any
Google Play declaration.

## Reviewer access gate — no credentials reproduced

Play Sign-in details is set to **Yes, the app is restricted**. Exactly one entry
named `Google Play Review Account` exists. The card confirms username/phone,
password and instructions are present, and Google's feedback-device toggle is
enabled. No credential value is recorded in this document.

The existing English instructions say to launch the app, open the standard sign
in screen, choose **Store reviewer access**, enter the supplied reviewer
credentials and sign in. They explicitly state that no OTP, email verification
code, MFA, social login or purchase is required and that Premium access,
including BIL AI Coach, is enabled.

| Reviewer requirement | Gate |
| --- | --- |
| Credentials exist in Play | **TRUE** |
| English instructions exist | **TRUE** |
| Traditional email/password route exists | **TRUE** |
| No OTP/MFA/email-code requirement is documented | **TRUE** |
| No purchase/free trial is required according to the instructions | **TRUE** |
| Premium + AI Coach entitlement is documented | **TRUE** |
| Historical Android emulator evidence reaches Dashboard and AI Coach | **TRUE**, captured 22 Aug 2026; not build-8 proof |
| Production auth identity exists exactly once | **TRUE**, live database boolean read-back; no identity value reproduced |
| Account is confirmed, active and not banned/deleted | **TRUE**, live database boolean read-back |
| Account has successful-login history | **TRUE**, live auth metadata boolean read-back |
| Fresh password sign-in in this audit | **TRUE** — a newly generated strong credential was rotated in Supabase Auth, used for an actual password sign-in, and then saved in both Google Play Sign-in details and App Store Connect App Review Information; no credential value was printed or written to the repository/evidence |
| Active closed-test grant | **TRUE**, live database boolean read-back |
| Effective Premium + AI access | **TRUE** — active `plan:premium` entitlement plus active closed-test AI subscription; source intentionally treats the active closed-test overlay as `premiumAiCoach` |
| At least 2,500 usable AI tokens | **TRUE**, fresh reviewer-JWT call to the app's reserved-aware usage RPC; `credits.total_remaining >= 2500` |
| Current signed build-8 login succeeds | **UNVERIFIED** — no signed/uploaded build 8 exists |
| Reviewer account is reusable for the review window | **TRUE** server-side — identity is active and the closed-test grant was renewed for 12 months; current signed build-8 E2E remains unverified |
| Works worldwide/no geoblock | **UNVERIFIED** — not stated or tested |
| Ads are absent for the reviewer | **UNVERIFIED** — instructions do not say so; build-8 workflow compiles ads off but no signed proof exists |
| Reviewer is not an administrator | **TRUE**, live database boolean read-back |
| Reviewer is not a community moderator | **TRUE**, live database boolean read-back |
| Public account-deletion path exists | **TRUE** |
| In-app deletion route exists in source | **TRUE**; signed end-to-end deletion remains unverified |

A coordinated live credential verification established a fresh reviewer JWT,
called the same `bil_get_ai_usage_status()` RPC used by the app, and performed
owner-scoped RLS reads. The RPC returned
`credits.total_remaining >= 2500`; the active Premium entitlement, active and
unexpired AI closed-test overlay, and 12-month grant were visible only to that
reviewer JWT. Admin and moderator RPC checks both denied those roles. Only
booleans were returned, and no identity, exact token count or credential was
copied into evidence.

The app source exposes Store reviewer access only when cloud configuration is
ready, restricts that form to the dedicated reviewer identity, and then calls
normal Supabase email/password authentication. It does not embed a reviewer
password or grant entitlement client-side. Premium/AI reviewer access is modeled
as a server-authoritative, time-bounded `closed_test` entitlement. Admin access
uses a separate server allow-list/RPC and fails closed. A parallel live account
audit reports exactly one protected owner/admin account with active admin RPC
and moderator state; that account is not the Play reviewer credential. Play
should receive only the reviewer account; the operational owner/admin credential
must remain distinct and must not be placed in Play instructions.

The live account/database test closes identity, confirmation, active-state,
fresh-password-authentication, role-separation, Premium, AI-subscription,
grant-longevity and token-capacity gates. Google Play confirmed the updated
credential card contains username/phone, password and instructions and displayed
`Change saved`; the Publishing-overview prompt was dismissed without sending a
review or release. App Store Connect accepted the same credential in App Review
Information, retained Sign-in required, and returned to a disabled Save state
after save/read-back. Its review note was corrected to describe access for the
review window and at least the next 11 months instead of making a longer expiry
claim. The strong password existed only in volatile session memory during this
coordinated operation; it was not printed, committed or recorded as evidence.

This remains interim server/console evidence, not an app-binary E2E result. The
same credential must be tested again from the signed Play-delivered build 8,
including worldwide routing, absence of a paywall and ads, and text/voice/vision
access. Neither store was submitted for review and no Android release was
published during the credential update.

Before submission, a signed Play-delivered build 8 must prove every remaining
unverified cell. The grant now covers the review window for 12 months; verify
global use with no OTP/2FA/geoblocking and prove that the reviewer sees neither a
paywall nor ads while text, voice and image checks work. Update Play instructions
with those properties only after live testing. Do not place the password in Git
or evidence artifacts.

Suggested final reviewer flow, after live verification:

1. Launch the app and tap **Sign in**.
2. Tap **Store reviewer access**.
3. Use the credentials stored only in Play Console; no OTP or second device.
4. Complete onboarding once and open Dashboard.
5. Open BIL AI Coach and test text, voice and vision without a purchase screen.
6. Open More > Settings > Delete account to inspect the deletion path.

## Store listing, device coverage and localisation

The default store listing is live and was last updated 31 August 2026. It has
only English (United Kingdom), despite the short description claiming 25
languages. Assets shown are icon 1/1, feature graphic 1/1, phone screenshots
8/8, no promo video, no 7-inch tablet screenshots and no 10-inch tablet
screenshots. Custom listings are absent.

The missing tablet screenshots are at minimum a store-quality and large-screen
review gap. Before production, upload verified build-8 tablet captures from both
7-inch and 10-inch classes (not stretched phone shots) and verify adaptive
layout, rotation, window resizing, back navigation and lifecycle restoration.
Add only localized listings whose text and assets have been reviewed; do not
interpret Flutter's 25 runtime languages as 25 localized Play listings.

The listing claims more than 300 workout videos and 1,500 recipes. Those counts,
asset uniqueness, image delivery and runtime availability must be regenerated
from the clean signed candidate before relying on them in production metadata.

## Clean build-8 and Play submission sequence

1. Freeze and review a clean unified commit; the current working tree is highly
   modified and is not a release source of record.
2. Preserve the successful live backend/deployment read-back represented by the
   now-present `BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID`; keep enforcement off
   until a signed Play-delivered canary succeeds.
3. Re-read the now-present project-number variable and backend release-ID secret
   immediately before the workflow; verify the number still equals
   `1041595138122` and never print the backend release-ID secret.
4. Run this audited Android release-candidate workflow with exact build number
   8. It
   requires signing values, runs analysis/tests, builds with production,
   integrity, payments and Facebook-login flags, checks target SDK/optional
   features/16 KB ELF alignment, verifies the signed AAB upload certificate,
   records SHA-256/size/commit/build number, and retains the artifact.
5. On signed physical Android devices, test Supabase Facebook OAuth through the
   browser/custom tab, traditional/reviewer login, verified HTTPS callbacks,
   account deletion, Play Integrity JIT/replay denial, Health Connect, BLE,
   billing, large-screen lifecycle and reviewer entitlements/tokens.
6. Upload only the attested build 8 AAB to a non-production test track first.
7. Run Play pre-launch reports, inspect Android vitals, deep links, device
   catalogue, permissions and Data safety against the uploaded artifact.
8. Re-test the reviewer account from a Play-delivered build and update the
   boolean gate above.
9. Obtain truthful owner answers and submit the production-access application.
10. Only after access is granted and all gates are green, create a separate
    production release for the same audited build 8. Never promote build 7 or
    substitute an unaudited later number.

## Current blockers

`P0` blockers:

- no clean frozen release commit;
- no signed, hashed, uploaded build 8;
- no signed-device integrity request evidence;
- no signed-device Facebook/reviewer/account-deletion/billing proof;
- reviewer global access, no-paywall and no-ads behavior are not confirmed in a
  signed build 8 (fresh sign-in, identity, roles, 12-month grant, Premium/AI and
  >=2,500 tokens are live server-verified and both stores hold the synchronized
  reviewer credential);
- no build-8 pre-launch report;
- production-access application has not been submitted or approved.
- Play's ads declaration and the build-8 ads-disabled flags are not reconciled.
- build-8 Health Connect permissions are broader than the live build-7 Health
  apps declaration and have not been reconciled in Play.

`P1` release-quality gaps:

- build 7 has no detected verified web links;
- no 7-inch or 10-inch tablet screenshots;
- only one Play listing localisation;
- listing quantity claims need clean-candidate regeneration;
- Store listing device checks are off;
- developer website ownership is not yet verified through Search Console.

## Official Google references used for release gates

- [Prepare your app for review](https://support.google.com/googleplay/android-developer/answer/9859455) — accurate declarations and complete access instructions for restricted apps.
- [Production access for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465) — the 12-tester/14-day prerequisite and production-access application.
- [Developer account verification requirements](https://support.google.com/googleplay/android-developer/answer/10841920) — identity, contact and device verification requirements.
- [Register package names for Android developer verification](https://support.google.com/googleplay/android-developer/answer/16984799) — Play package registration and the 30 September 2026 deadline.

## Safe actions versus owner decisions

Safe preparation now: reconcile documents to the live EG/NG/PK/TR Premium set,
preserve and re-read the verified Play project-number variable, prepare reviewed
tablet assets, keep production-access answers as an owner draft, and finish the
clean commit/canary evidence.

Owner/account-holder decisions still required: production-access survey answers,
developer-verification confirmation, whether/when to enable Store listing device
checks, final production-country/listing-localisation scope, and the later
production rollout. None of these should be inferred or submitted automatically.
