# BIL: exact store metadata deltas, 4 October 2026

Use this as the field-level editing map, not as a release certificate. Its
authored source snapshot is `codex/prebuild-hardening-20261004` at base parent
`ec40c6d` plus the preserved candidate changes, not the eventual clean commit.
Console values below are attributed actual 4 October readbacks. This map has
not applied the proposed Privacy/Data Safety edits. The root auditor separately
applied and read back the App Store advertising and age declarations; those
changes do not close these privacy mismatches. **No build, native purchase or
Production migration is established by this map.**

The complete provenance and uncertainty ledger is
[the disclosure contract](BIL_STORE_DATA_DISCLOSURE_RECONCILIATION_2026-10-04.json).
This map does not replace its consent, SDK-resolution or processing-term gaps.

## Google Play: apply these confirmed deltas

These rows concern **AdMob's technical advertising flows**, not users' health,
AI questions, private messages or photos. The current Android release workflow
enables ads at `.github/workflows/bil_android_release_candidate.yml:118-119` and
`:213-214`. Actual banner requests are non-personalized, use no BIL health
payload, and are adult/account/UMP-gated in
`lib/features/ads/services/admob_contextual_ad_gateway.dart:109-137`.
Non-personalized ads still have the SDK's disclosed collection/sharing.

| Console field | Observed current answer | Required source/provider baseline | Classification |
| --- | --- | --- | --- |
| Approximate location | Location selected `0/2` | Add **Approximate location**, collected and shared, for IP-derived AdMob location; do not add Precise location from this evidence | CONFIRMED MISMATCH |
| App interactions | No Advertising purpose | Collected and shared; add **Advertising or marketing**; retain **Analytics** and **Fraud prevention, security, and compliance** | CONFIRMED MISMATCH |
| Diagnostics | No Advertising purpose | Collected and shared; add **Advertising or marketing**; retain **Analytics** and **Fraud prevention, security, and compliance** | CONFIRMED MISMATCH |
| Device or other IDs | No Advertising or Analytics purpose | Collected and shared; add **Advertising or marketing** and **Analytics**; retain **Fraud prevention, security, and compliance** and separately supported BIL purposes | CONFIRMED MISMATCH |
| Overall third-party sharing | `No data shared with third parties` | Reconcile to the AdMob sharing rows above; Supabase's possible processor exception does not exempt AdMob automatically | CONFIRMED MISMATCH |

For the new Approximate location row, the SDK purposes are **Advertising or
marketing; Analytics; Fraud prevention, security, and compliance**. Do not add
Personalisation solely because advertising is enabled. Do not select
**ephemeral** for any SDK row without real-time-only processing evidence.

Source of that baseline:
[Google Mobile Ads Android disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure)
and [Play's Data Safety definitions](https://support.google.com/googleplay/android-developer/answer/10787469).
The locked plugin is `google_mobile_ads 9.1.0`; its Android dependency is
`play-services-ads 25.4.0`. The current disclosure guide describes `25.5.0`:
this supports the disclosed SDK baseline, **not** exact final-artifact or native
traffic certification.

The live Console CSV exported at 11:01:10 UTC contains 782 response rows and
confirms 18 selected types. The reconciliation JSON records 26 individually
validated proposed SDK deltas; all target rows are uniquely present and blank.
No CSV has been imported and these are not saved Console answers.

**Do not guess the remaining radio buttons.** The current four SDK groups are
marked Optional, but a truthful final Optional answer requires the choice to
exist for all relevant users/devices/regions and distributed versions. Dart
request gates alone do not prove native startup collection or every region's
opt-out. The fresh export proves Crash logs and Other app performance are
unselected. The inspected Android guide specifies Diagnostics; it does not
establish that either additional subtype should be selected. Leave them unchanged
until their actual producer and resolved native SDK are verified; do not import
iOS-only Crash declarations into Android. New Approximate location optionality
is unresolved, so the 26-row map is not a complete import/save contract.

## App Store Connect: apply these confirmed deltas

Actual App Privacy readback contained **20** types. Contacts and Advertising
Data were absent. Coarse Location was present; do not report it missing.
The source-owned manifest now contains **18** app-owned types, including
Community Contacts at `ios/Runner/PrivacyInfo.xcprivacy:91`.

| Console data type | Observed current answer | Required current producer reconciliation | Classification |
| --- | --- | --- | --- |
| Contacts | Absent | Add **Contacts**, linked to user, **App Functionality + Product Personalization**, not tracking for BIL's social graph | CONFIRMED MISMATCH |
| Advertising Data | Absent | Add SDK **Advertising Data**, linked to user; **Third-Party Advertising + Analytics** for the AdMob flow; review Developer Advertising separately | CONFIRMED MISMATCH |
| Coarse Location | Linked; App Functionality only | Add **Third-Party Advertising + Analytics** for AdMob; preserve separately supported existing purposes | CONFIRMED MISMATCH |
| Product Interaction | Linked; App Functionality only | Add **Third-Party Advertising + Analytics** for AdMob; retain BIL App Functionality | CONFIRMED MISMATCH |
| Performance Data | Linked; App Functionality only | Add **Third-Party Advertising + Analytics** for SDK flow; retain linked BIL remote-latency producer and its App Functionality | CONFIRMED MISMATCH |
| Other Diagnostic Data | Linked; App Functionality only | Add **Third-Party Advertising + Analytics** for SDK flow; retain linked BIL security/service producer and its App Functionality | CONFIRMED MISMATCH |
| Device ID | Linked; App Functionality + Analytics | Add **Third-Party Advertising**; retain existing supported purposes; Tracking choice needs the separate verification below | CONFIRMED PURPOSE MISMATCH; TRACKING UNKNOWN |
| Crash Data | Unlinked in actual expanded preview; App Functionality only | Add SDK **Analytics**; do not add SDK Third-Party Advertising from the inspected Crash row | CONFIRMED PURPOSE MISMATCH |

Community follows/friendships store paired account UUIDs and personalize the
feed. Contacts here means that **social graph**, not device address-book
permission. Exact producers are
`community_repository_connections_messaging_mixin.dart:122`,
`community_social_repository_mixin.dart:663`, and
`20261003093710_community_feed_modes_v1.sql:61-78`.

The genuine vendor **GoogleMobileAds 13.7.0** archive, checked against the
[official package checksum](https://github.com/googleads/swift-package-manager-google-mobile-ads/blob/13.7.0/Package.swift),
declares these seven rows in both device and simulator manifests:

| SDK row | Linked | SDK tracking declaration | SDK purposes |
| --- | --- | --- | --- |
| Coarse Location / Advertising Data / Product Interaction | Yes | No | Third-Party Advertising; Developer Advertising; Analytics |
| Device ID | Yes | Yes | Third-Party Advertising; Developer Advertising; Analytics |
| Performance Data / Other Diagnostic Data | No | No | Third-Party Advertising; Developer Advertising; Analytics |
| Crash Data | No | No | Analytics |

The vendor manifest is real evidence of SDK declarations, **not proof of every
optional use actually occurring in BIL** or the exact final resolved archive.
Third-Party Advertising is the AdMob flow in candidate source. Whether
Developer Advertising applies to actual configured use remains UNKNOWN; do
not silently erase the vendor declaration or claim BIL runs first-party
marketing. Device ID `tracking=true` cannot be dismissed by BIL's own
`tracking=false`, NPA requests or disabled same-app key. Conversely it does not
prove BIL tracks without permission. **Do not finalize Tracking=false or
Tracking=true from this map**: verify actual SDK/partner configuration and ATT
behavior; if tracking occurs, a metadata-only edit cannot repair consent.

Linked/unlinked are per producer: app-owned latency/security records are
linked, while these SDK diagnostic rows are unlinked. Preserve the union
without changing all diagnostics to unlinked. The actual Console preview also
showed linked/unlinked duplicates for some identifier/Other Data flows; this
is not authority to delete one producer. Do not remove existing purposes or
types until older distributed artifacts and remaining producers are checked.

Use [Apple's privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
and [manifest aggregation guidance](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests).
SDK-owned data does not require duplicate Runner rows merely to match Console.

## Keep these boundaries separate when entering answers

| Flow | Truthful category/purpose boundary | Current decision boundary |
| --- | --- | --- |
| Supabase Auth / selective sync / push / verified commerce | Account/health/fitness/identifiers/purchase data for requested App Functionality, Account Management, or actual Personalisation; linked owner data | Collection must be disclosed; sharing exception requires on-behalf processing conditions, not RLS or encryption alone |
| Gemini via BIL Edge | Questions/context and selected meal photo; Health/Fitness where actual context includes it; App Functionality/Personalisation plus actual safety/usage metadata | Paid `bil-health` key and actual Vertex Express base `https://aiplatform.googleapis.com/v1beta1/publishers/google` proved by full-digest comparisons; public model overrides verified. Signed processor terms, logging/retention and provider runtime remain unverified; do not invent zero retention or a no-sharing exemption |
| AdMob | Technical IP/coarse location, interactions, diagnostics, IDs and iOS advertising data for ad-serving uses above | Never apply SDK advertising purposes or sharing to BIL health/context/photos just because they coexist in the app |
| Speech recognition | BIL sends recognized transcript; device/service recognition may have separate off-device audio processing | Do not automatically declare BIL raw Audio Data from Apple-only Speech framework collection; actual Android recognition-service behavior remains a distinct UNKNOWN |
| Search | Remote authenticated search exists | Existing Play ephemeral selection is not proof of no retained provider/Edge logs; verify retention before preserving that checkbox |

This is a **partial ready-to-apply map of confirmed mismatches**. Optionality,
tracking, exact subtype union, provider terms and unexpanded console answers
remain UNKNOWN until their own evidence is read. The existing age/disclaimer
changes are not altered by this map. Stop before build.
