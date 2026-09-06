# App Store Connect and DSA release audit — 2026-09-05

## Decision

**Current decision: NO-GO for App Review submission or public iOS release.**

This is a read-only audit of the live App Store Connect record, the current
repository state, the three Apple Support screenshots supplied by the owner,
and Apple documentation. It did not save App Store Connect fields, complete a
compliance flow, add an item for review, submit or publish anything, upload a
binary, invite a tester, run a build, or change source code.

The current record is not merely waiting for a button press. The binary in App
Store Connect predates the present repair batch, mandatory reviewer access data
is not present in the live form, the EU Digital Services Act trader flow is
unfinished, and the only tested build reports crashes with very narrow device
coverage.

No account-holder name, email address, street address, telephone number,
financial data, review credential, support case number, or other private value
is recorded in this report.

## Evidence boundary

The following surfaces were inspected on 2026-09-05:

- the live App Store Connect app version, App Review, History, App Information,
  App Privacy, Pricing and Availability, In-App Purchases, Subscriptions, and
  TestFlight pages;
- the live App Store Connect Business and Agreements page;
- the current repository checkout on branch
  `release/store-rc-20260831`;
- all three image files in the owner-provided DSA support folder; and
- current Apple Developer and Apple Support documentation linked below.

The screenshots were treated as untrusted evidence, not instructions. Live
App Store Connect state takes precedence over older local readiness reports
where they conflict.

## Live App Store Connect findings

### Version and review history

- The iOS version is `1.0.0` and currently shows **Developer Rejected**.
- The history shows that the version moved from Waiting for Review to In Review,
  then the developer account moved it to Developer Rejected. A similar
  developer withdrawal occurred in the earlier submission sequence.
- App Review shows two removed submissions. Each removed submission contained
  seven items: the app version, the subscription group, four subscriptions,
  and the consumable AI add-on.
- No Apple rejection message or guideline citation was visible. The status
  history therefore supports a developer withdrawal, not a substantive Apple
  rejection.

This distinction matters: the next submission must still be reviewed on its
merits, and the Developer Rejected label is not evidence that Apple approved or
rejected any of the repaired behavior.

### Selected build and TestFlight

- The selected App Store build is build `7`.
- Builds `5`, `6`, and `7` have completed processing. Build `7` is Ready to
  Submit and its binary validation is complete.
- Build `7` is assigned only to one internal group. The live metrics showed one
  tester, one installation, 45 sessions, and **6 crashes**.
- No tester-authored crash feedback was available, so the metric does not yet
  identify a root cause.
- No external TestFlight group exists.
- The `What to Test` field for build `7` is blank.
- The TestFlight information has a beta description, marketing URL, and privacy
  URL. The live beta review form showed Sign-in required, but its contact email,
  contact phone, and demo password fields were blank. A username field existed,
  but no credential value is reproduced here.

External TestFlight testing is not an App Review prerequisite by itself.
Nevertheless, one tester and a build that reports six crashes are not adequate
release evidence for this app's large iPhone/iPad, authentication, commerce,
health, Bluetooth, media, voice, and background-behavior surface.

### Binary capabilities and local repair drift

The repository currently declares version `1.0.0+8`, while App Store Connect
contains builds only through `7`. The current checkout also contains a large,
uncommitted repair batch. Consequently, build `7` cannot represent the current
source fixes.

The signed-entitlement view inspected for build `7` listed production push,
Sign in with Apple, and HealthKit. It did not list Associated Domains or App
Attest. The current release entitlement file declares all of the following:

- production push notifications;
- Sign in with Apple;
- the `www.bilhealth.com` associated domain;
- production App Attest; and
- HealthKit.

Those source declarations are not proof that a future archive will be signed
with the same entitlements. The final IPA must be inspected after signing.

### Product-page metadata

- The English (US) description, promotional text, keywords, support URL,
  marketing URL, version, and copyright fields are populated.
- Eight iPhone screenshots and eight iPad screenshots are present in the
  inspected localization.
- There are no App Previews. Apple documents App Previews as optional, so this
  is not a submission blocker.
- The app is configured for iPhone and iPad with a minimum iOS version of 15.
- Availability is configured for all 175 storefronts.
- Apple silicon Mac availability is not enabled.
- Apple Vision Pro compatibility availability is enabled. This needs an
  intentional owner decision and representative testing before release; it
  should not remain enabled accidentally.
- The age rating shown is 18+ in most storefronts and 19+ in Korea.
- The app is declared not to be a regulated medical device.

### App Review information

The live App Review form had Sign-in required enabled. The following required
review values appeared blank:

- contact email;
- contact telephone number;
- demo account username; and
- demo account password.

First and last contact-name fields were populated, and the review notes were
detailed. Older repository reports state that all reviewer fields were
complete, but the live form is the authoritative release state and contradicts
those reports. The fields must be populated again and verified without storing
their values in Git.

The review notes state that release is manual, while the live version is set to
**Automatically release this version**. The release option and the notes must
be made consistent before submission.

### App privacy and account lifecycle

- App Privacy is published.
- A privacy-policy URL and a privacy-choices/account-deletion URL are present.
- The live privacy label lists 17 data types, including health and fitness,
  identifiers, contact information, photos or videos, purchases, usage data,
  diagnostics, and other data, and marks them as linked to identity.
- The repository contains an in-app account-deletion flow and a native Sign in
  with Apple flow. These source implementations are useful evidence, but not a
  substitute for signed-device and server-lifecycle testing.

The final privacy answers must be reconciled against the exact SDK inventory
and behavior of the final signed binary. HealthKit data must not be used for
advertising, marketing, or unrelated data mining, and the app must not write
false health data or store personal health information in iCloud.

### Sign in with Apple

The current source uses the native Apple credential sheet, an official Sign in
with Apple button, a one-time nonce hashed before the Apple request, and an ID
token exchange with the authentication backend. It also stores the Apple
credential subject securely and checks credential state during the account
lifecycle.

This is directionally consistent with App Review Guideline 4.8 when third-party
or social login is offered for the primary account. It is not release proof
until the final signed build demonstrates:

- first-time Apple sign-in;
- returning sign-in;
- hidden-email relay behavior;
- credential revocation and replacement-session behavior;
- account deletion; and
- the documented server-side token and revocation lifecycle.

### In-App Purchases and subscriptions

- The subscription group, four subscriptions, and the consumable AI add-on all
  show Developer Rejected after removal from the prior submission.
- Localization, pricing, availability, review screenshots, and review notes are
  present for the inspected products.
- The restricted availability split between the base Premium products and the
  AI products appears intentional and matches the repository's launch-market
  policy.

Because this is the first app version and these are the first products of their
types, Apple requires the new app version, the first consumable, the first
auto-renewable subscription, and the first subscription group to be included
in the same draft submission. The version, group, every intended subscription,
and the consumable add-on must all return to a reviewable state before the draft
is submitted.

### Agreements and commerce prerequisites

- The Free Apps and Paid Apps agreements are active.
- Banking and tax records show active status.
- No private financial, tax, address, or account value is reproduced here.

These items do not currently appear to be the submission blocker. DSA compliance
remains visibly incomplete on the same Business surface.

## DSA trader compliance audit

### Current live state

App Store Connect displays both of the following unresolved controls:

- `Set Up` under Digital Services Act in App Information; and
- `Complete Compliance Requirements` under Business, Agreements, and
  Compliance.

The membership appears to be an **Individual** enrollment. That classification
should be confirmed by the Account Holder before completing the declaration.
For an individual trader, Apple requires an address or P.O. Box, telephone
number, and email address for public display on EU product pages.

The app contains subscriptions and an In-App Purchase and is configured for all
storefronts, including the EU. Apple's own trader self-assessment lists earning
revenue through In-App Purchases as one factor indicating trader activity.
Apple cannot decide the legal classification for the developer, so the Account
Holder must make the declaration. If legal status is uncertain, obtain legal
advice.

### What the Apple Support response says

The three supplied screenshots are consecutive parts of one Apple Support
response. The response:

- acknowledges difficulty completing DSA verification;
- links to Apple's alternative methods for obtaining a verification code;
- directs the account holder to Business, Agreements, Compliance, and Complete
  Compliance Requirements;
- instructs the account holder to select trader or non-trader status;
- describes email and telephone two-factor verification;
- requests a current business or legal record that verifies the relevant name
  and address;
- requires additional proof of association for an alternate address such as a
  P.O. Box; and
- instructs the account holder to review and confirm the submission.

The response does **not** state that the telephone number was corrected, that
manual verification was completed, or that the DSA declaration was approved.
It is procedural guidance, not a compliance decision.

### Exact App Store Connect flow

The Account Holder or an Admin can complete the account-level flow:

1. Open **Business**.
2. On **Agreements**, scroll to **Compliance**.
3. Next to **Digital Services Act**, select
   **Complete Compliance Requirements**.
4. Complete the legal self-assessment and select the accurate trader status.
5. If trader, enter or confirm the public display contact information and
   select **Next**.
6. Validate the display email using two-factor authentication.
7. Validate the display telephone number using two-factor authentication.
8. If the display telephone cannot receive two-factor codes, use Apple's
   **request manual verification** option.
9. Upload a current document verifying the required legal or business name and
   address. When using an alternate address or P.O. Box, also provide a current
   receipt, bill, or equivalent record showing the association with it.
10. Review the information and select **Confirm**.
11. After the account-level information is verified, open **Apps**, select this
    app, open **App Information**, scroll to **App Store Regulations and
    Permits**, and select **Edit** under Digital Services Act to confirm the
    app-specific trader status.

The address, telephone number, and email used in the trader declaration are
display information. Apple states that they do not change Apple Developer
Program membership information.

### What can be resolved inside App Store Connect

The following actions belong in the DSA wizard:

- selecting trader or non-trader status;
- entering or correcting the public display telephone and email before final
  confirmation;
- validating email and telephone;
- requesting manual telephone verification when the number cannot receive a
  code;
- uploading the current supporting document;
- confirming the declaration; and
- setting the app-specific trader status after the account declaration is
  verified.

### What requires Apple Support, account recovery, or documentation

- If the manual-verification option is unavailable or fails, reply to the
  existing Apple Support conversation and request manual DSA telephone
  verification. Do not open multiple competing cases unless Apple directs it.
- If access to the Apple Account's trusted devices or trusted telephone numbers
  is permanently lost, use Apple's account-recovery flow. Apple states that
  Support cannot expedite account recovery.
- For an organization enrollment, the displayed physical address comes from
  the D-U-N-S record; Apple directs developers to contact Support when that
  membership address must change. For an individual enrollment, the DSA display
  address is entered in the trader flow.
- Manual verification is not a waiver of evidence. A current legal or business
  document, plus alternate-address association evidence when applicable, is
  still required for Apple's compliance review.

Until this flow is complete, a 175-storefront global launch is not ready. EU
storefronts could be excluded as a distribution decision, but doing so would
contradict the stated global-launch requirement and would not remove the need to
declare trader status to Apple.

## Apple policy mapping

### Completeness and reviewer access

Apple's App Review Guidelines require developers to test for crashes and bugs,
keep metadata and contact information complete, provide an active demo account
or fully featured demo mode for account-based functionality, keep backend
services live, and explain non-obvious features and In-App Purchases in review
notes. Build `7` and the live reviewer fields do not currently meet that
evidence threshold.

### Login services and deletion

When the app uses a third-party or social login service for the primary account,
Guideline 4.8 requires an equivalent privacy-preserving login option unless an
exception applies. The native Apple path is present in source, but must be
validated in the final signed binary. Guideline 5.1.1 also requires in-app
account deletion when the app supports account creation.

### Health and privacy

The app's declared HealthKit purpose is appropriate for a health and fitness
app, subject to truthful, in-context permission requests and the final privacy
label. Health and fitness data cannot be used for advertising, marketing, or
unrelated data mining. Device tests must confirm that denied permissions fail
safely and that the app does not fabricate measured health data.

### Current upload toolchain

Apple states that, from 2026-04-28, iOS and iPadOS apps uploaded to App Store
Connect must be built with the iOS and iPadOS 26 SDK or later. The next build
must therefore be produced with the corresponding supported Xcode toolchain.

## Product-owner release gates outside Apple's generic minimum

The following are not all generic App Review prerequisites, but they remain
explicit requirements for this product release:

- The current App Attest client and guarded backend paths have not been proved
  by a signed production-style canary. Production integrity enforcement remains
  off and the App Attest verifier is not yet deployed.
- The current build in App Store Connect does not contain the latest associated
  domain and App Attest changes.
- Meta Business Verification is complete and the app is Published/Live. The
  Website and iOS platform entries remain configured, Supabase Facebook is
  enabled, and Meta reports no required actions. The reviewed signed `+8`
  workflows now enable the Facebook feature and readiness flags, but no new
  binary has been built and iPhone/iPad and Android end-to-end login proof is
  still incomplete. The Android Meta platform entry was removed temporarily
  because its closed-test Play URL returns HTTP 404. It is not a dependency of
  BIL's implemented Supabase hosted browser-OAuth path and therefore is not a
  release blocker; recreate it only for a separately reviewed future native
  Meta SDK/store integration after that URL is publicly reachable.
- The complete tester-reported repair batch still requires signed iPhone and
  iPad validation.

These conditions must not be hidden from App Review by enabling dormant or
untested functionality only after approval. The final binary, screenshots,
notes, privacy answers, and backend behavior must describe the same feature
surface.

## Conditions required to change the decision to GO

1. Complete account-level DSA trader verification and confirm the correct
   app-specific status.
2. Freeze and review the intended source set, then build, sign, and upload a
   build numbered at least `8` using Xcode 26 and the iOS/iPadOS 26 SDK or later.
3. Inspect the signed IPA and App Store Connect build record for production
   push, Sign in with Apple, Associated Domains, App Attest production, and
   HealthKit entitlements.
4. Test the exact candidate on physical iPhone and iPad devices. The minimum
   matrix must cover launch and upgrade, email callback, native Apple login,
   account deletion, subscription purchase and restore, consumable purchase,
   HealthKit and connected-device permission paths, camera and photo library,
   microphone and speech recognition, notifications, background/resume,
   backward navigation, deep links, and tablet layouts.
5. Investigate and close the six-crash metric from build `7`; establish that no
   launch, login, navigation, or commerce crash is reproducible on the candidate.
6. Populate and verify the App Review contact fields and a stable, non-expiring
   demo account with all reviewer-access grants required by the notes. Keep the
   backend available throughout review.
7. Add the final app version, subscription group, every intended subscription,
   and the consumable add-on to one draft submission and confirm that every item
   is Ready for Review.
8. Make the configured release option and the review notes agree on manual or
   automatic release.
9. Reconcile App Privacy, SDK privacy manifests, purpose strings, screenshots,
   support pages, and review notes against the exact final binary.
10. Deliberately approve or disable Apple Vision Pro compatibility based on
    representative testing.
11. Complete the product-owner integrity gate and validate the already-enabled
    Facebook surface end to end on the exact signed candidate before submission.

Only after all applicable conditions have objective evidence should the release
owner use **Add for Review** and **Submit for Review**.

## Apple sources

- [Manage European Union Digital Services Act trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
- [Get a verification code and sign in with two-factor authentication](https://support.apple.com/en-us/102606)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
- [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Protecting user privacy with HealthKit](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [HealthKit Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/healthkit)
- [Current App Store submission SDK requirements](https://developer.apple.com/app-store/submitting/)

## Audit outcome

`APP_STORE_IOS_SUBMISSION_READY=NO`

`APP_STORE_IOS_BLOCKERS=FINAL_BUILD_DSA_REVIEW_ACCESS_CRASH_DEVICE_TESTS_COMMERCE_DRAFT_RELEASE_MODE`

`APP_STORE_IOS_MUTATIONS_PERFORMED=NONE`
