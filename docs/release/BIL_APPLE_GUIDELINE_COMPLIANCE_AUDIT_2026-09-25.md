# BIL Apple App Review Guidelines compliance audit — 2026-09-25

Candidate source: `01f693780e6f23aff68c0777f61b0571b7547fca`  
Branch: `codex/build28-final-qa`  
Intended candidate: iOS `1.0.0 (28)`  
Official baseline: Apple App Review Guidelines retrieved 2026-09-25.

## Evidence rule

`PASS` means the applicable source/configuration and focused automated checks agree. It does not mean Apple has accepted the binary. `EXTERNAL` means that only App Store Connect readback, a signed archive, TestFlight/physical-device behavior, rights documentation, or an Apple reviewer can close the item. `N/A` means BIL does not offer the regulated feature.

## Complete guideline applicability matrix

| Guideline | Status | BIL evidence | Remaining proof |
| --- | --- | --- | --- |
| 1.1 Objectionable content | PASS / EXTERNAL | BIL does not author prohibited content; Community publishing is policy-gated and moderated. | Live content and moderation operations remain continuous obligations. |
| 1.2 User-generated content | PASS / EXTERNAL | Filtering/publish validation, report flow, block controls, moderation queue, suspension, versioned policy acceptance, and published support/community-guideline routes exist. Focused Community tests passed. | Signed-device report/block journey and evidence that reports receive timely human responses. |
| 1.3 Kids Category | N/A | BIL is not designed or submitted as a Kids Category app; adult eligibility gates advertising. | Confirm age-rating answers do not represent BIL as a kids app. |
| 1.4 Physical harm / health | PASS / EXTERNAL | Non-medical boundary, clinician escalation, urgent-symptom guard, methodology/source pages, and approved health-reference catalog are present. No drug-dose calculator is offered. | Apple may independently assess claims; signed-device review of every health surface is still required. |
| 1.5 Developer information | PASS | Live support and privacy routes return HTTP 200 and publish `support@bilhealth.com`. | Confirm App Store Connect Support URL/contact fields match the live site. |
| 1.6 Data security | PASS / EXTERNAL | Authenticated cloud boundaries, RLS/server gates, secure Apple credential storage, consent gates, integrity controls, and account-deletion ordering have regression coverage. | No source review proves absence of all vulnerabilities; archive/penetration and production monitoring remain external evidence. |
| 1.7 Criminal-activity reporting | N/A | BIL is not a criminal-activity reporting service. | None. |
| 2.1 App completeness | PASS / EXTERNAL | No confirmed placeholder/review-only product path; production URLs are live; focused release contracts pass. | Final signed build must be crash-tested, backend left live, and App Review must receive a working demo account and precise notes. |
| 2.2 Beta testing | PASS | Candidate is a release build, not an in-app beta distribution mechanism. | Do not describe the App Store build as beta/trial software. |
| 2.3 Accurate metadata | NOT CLOSED IN STORE | Eight authentic iPhone and eight authentic iPad screenshots were produced at accepted sizes; the old Android-status-bar assets are not in the replacement package. | Replace every affected asset in **all sizes** in Media Manager, verify description/keywords/age rating/privacy labels/IAP metadata, then read back before submission. |
| 2.4 Hardware compatibility | PASS / EXTERNAL | iPad orientations and responsive/RTL/text-scale test coverage exist; no unrelated background process was found. | Physical iPhone/iPad rotation, multitasking, lifecycle, thermal/battery, and accessibility matrix. |
| 2.5 Software requirements | PASS / EXTERNAL | Public Flutter/iOS integrations, intended background behavior, contextual camera/mic indicators, self-contained application logic, and associated-domain configuration are present. | Signed archive private-API/privacy-manifest validation and IPv6-only/device testing. |
| 3.1.1 In-App Purchase | PASS / EXTERNAL | Digital premium/boost uses StoreKit through `in_app_purchase`; verified entitlement and restore paths exist; no alternate digital unlock mechanism was found. | App Store products must be review-ready and real StoreKit purchase/restore/refund/revocation tested in sandbox/TestFlight. |
| 3.1.2 Subscriptions | PASS / EXTERNAL | Store-derived price/offer truth, lifecycle states, restore, ownership binding, and ongoing AI/premium value are implemented and tested. | Read back localized duration/price/terms, review screenshots, availability, and subscription review state in App Store Connect. |
| 3.2 Other business models | PASS | No prohibited marketplace, loan, charity collection, rank manipulation, forced rating, or predominantly-advertising behavior was found. | Continued operational obligation. |
| 4.1 Copycats | PASS / OWNER | BIL has its own bundle ID, brand, UI and product scope. | Asset/trademark/content ownership ultimately requires owner records; code cannot prove every license. |
| 4.2 Minimum functionality | PASS | Native health, diary, nutrition, analytics, AI, connected-health and Community experiences materially exceed a web wrapper. | Final binary behavior only. |
| 4.3 Spam | PASS | One BIL bundle/product was identified; no duplicate template fleet. | Store-account-wide duplicate-app status is external. |
| 4.4 Extensions | N/A | No user-facing app extension requiring separate review was identified. | Archive readback. |
| 4.5 Apple sites/services | PASS / EXTERNAL | HealthKit, Sign in with Apple, APNs and StoreKit are used for their intended purposes. | Signed-entitlement and physical-device proof. |
| 4.6 Alternate app icons | N/A | No misleading alternate-icon flow was identified. | Archive/store metadata readback. |
| 4.7 Mini apps / remote software | N/A | BIL does not distribute executable mini-apps, games, plug-ins, or downloaded code. | None. |
| 4.8 Login services | PASS / EXTERNAL | Google/Facebook login is accompanied by Sign in with Apple; entitlement, nonce/callback, cancellation and credential-revocation handling are present. | Real Apple hidden-email/new/returning/revoked-account tests on a signed build. |
| 4.9 Apple Pay | N/A | Digital purchases use StoreKit, not Apple Pay. | None. |
| 4.10 Monetizing built-in capabilities | PASS | BIL does not sell access to camera, push, HealthKit or other built-in OS capability itself. | Store presentation readback. |
| 5.1.1 Data collection/storage | PASS / EXTERNAL | In-app and live privacy policy identify categories, collection, uses, processors, retention/deletion and withdrawal. Purpose strings are specific; account deletion is in-app and public. | App Store privacy answers and signed SDK privacy report must be reconciled with the final archive. |
| 5.1.2 Data use/sharing | PASS | AI Coach and meal-photo analysis separately identify Google Gemini, enumerate transmitted data, require versioned explicit consent, fail closed server-side, and support withdrawal. Ads are consent-gated and barred from health/private context targeting. | Production configuration must remain identical through release. |
| 5.1.3 Health data | PASS / EXTERNAL | Health data is used for health/fitness functionality, not advertising; per-type permission and methodology boundaries exist. | Real HealthKit partial/deny/revoke/write tests and App Privacy readback. |
| 5.1.4 Kids privacy | N/A | Not a Kids Category product. | Correct age rating and storefront answers. |
| 5.2 Intellectual property | PASS / OWNER | No confirmed unauthorized third-party brand/content reuse was found in source; provider marks are used descriptively in consent/login contexts. | Owner must retain licenses for every marketing image, font, dataset and trademark. |
| 5.3 Gaming/gambling/lotteries | N/A | No gambling, lottery or real-money gaming functionality. | None. |
| 5.4 VPN | N/A | No VPN service. | None. |
| 5.5 Mobile device management | N/A | No MDM functionality. | None. |
| 5.6 Developer code of conduct | PASS / EXTERNAL | No review manipulation, forced rating, impersonation or deceptive unlock path was found. | Account conduct and reviewer communications remain an owner/store obligation. |

## Verification performed in this audit

- Focused Flutter policy suite: **114 passed, 0 failed**.
- Covered Apple privacy/AI consent, privacy manifest boundaries, account deletion, Community policy/moderation, Sign in with Apple lifecycle/cancellation, subscription lifecycle, Health references, ad consent, permissions and production metadata.
- Live HTTP checks: `/privacy`, `/support`, `/community-guidelines`, `/delete-account`, and `/.well-known/apple-app-site-association` returned **200**; AASA parsed as valid JSON.
- Live privacy JavaScript explicitly identifies Google Gemini, AI Coach data categories, meal-photo transmission, withdrawal, retention and deletion.
- No mobile build and no App Store mutation were performed.

## Release blockers before claiming full compliance

1. Replace and read back every iPhone/iPad screenshot in App Store Connect; source files alone do not close Guideline 2.3.
2. Reconcile App Privacy labels, age rating, description, support/privacy URLs, IAP/subscription metadata and Review Notes against Build 28.
3. Produce the signed archive and inspect embedded privacy manifests, entitlements, prohibited/private API scan and exact commit provenance.
4. Run signed TestFlight/physical-device tests for login providers, HealthKit, StoreKit, APNs, permissions, universal links, IPv6-only networking, VoiceOver/Dynamic Type and iPad multitasking.
5. Provide App Review a live demo account and exact steps for AI consent, meal-photo consent, subscriptions, Community moderation/reporting and account deletion.

## Conclusion

No new confirmed source-code violation was found in the applicable Apple guideline areas inspected. The candidate is **source-policy ready**, but **complete App Review compliance is not yet proven** until the five external gates above are closed. Apple explicitly states its checklist does not guarantee approval, and guidelines/reviewer judgments can change; therefore an unconditional promise that no reviewer will raise another issue would be false.
