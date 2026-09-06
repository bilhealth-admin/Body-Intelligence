# BIL advertising, privacy, and consent boundary

BIL remains a free download. Eligible registered adult Free users may see
contextual, non-personalized advertising only when Google's UMP state permits
an ad request and a reviewed production provider plus real store identifiers
are configured. Premium subscribers are ad-free and Guests are excluded.

Development defaults are fail-closed: advertising, provider readiness, and unit
identifiers are disabled or empty. The owner's latest explicit upload instruction
defers AdMob: signed +8 compiles both ad switches false, supplies no ad IDs, and
verifies absent native ad configuration. Android's eager MobileAdsInitProvider
is removed at manifest merge; iOS omits GADApplicationIdentifier. The retained
Free-ad implementation is for a later configured update, not active +8 serving.
No demo IDs, test ads, fallback provider, or fabricated fill may ship.
When advertising is enabled in a future configured release, no ad request is made when
UMP cannot authorize it on either Android or iOS,
the account entitlement or adult gate is unresolved, the device is offline,
the provider is unavailable, or the placement is sensitive. BIL does not
provide a separate product-level switch that permanently converts the Free
plan into an ad-free plan.

Advertising must never use health records, nutrition entries, food searches,
weight, body measurements, device readings, location-health inferences,
profile attributes, community private content, or AI meal results for targeting
or measurement. The current UI has isolated generic banner anchors in Dashboard,
Daily Log, Progress, More and the wellness discovery library. Their screen names
are local layout identifiers, never request parameters: each sends the same
generic placement with no surrounding content, keywords or URLs. Earlier wording
that ads were physically absent from all these screens was incorrect and is
superseded here. Direct health/food/profile/report/purchase placements remain
rejected by the policy and the final provider boundary.

Premium and Premium + AI Coach are ad-free through ordinary server-verified
subscription policy. This also applies to the owner and provided reviewer
accounts when their effective subscription is verified; there is no separate
reviewer-detection or concealment switch. Live account verification and native
SDK test evidence must be recorded separately from mocked policy tests.

Current external readiness (2026-09-06): the BIL Google account opens AdMob signup;
no real publisher/app/banner IDs or CI AdMob variables were found. The public
app-ads.txt is still a placeholder. Production advertising is NOT ready and its
readiness variable must not be set. This does not block the owner-authorized
ad-disabled +8 build/upload. A later ad-enabled update requires real IDs,
consent configuration and truthful store disclosures. AdMob's app-readiness
review requires a published/listed app and is not a prerequisite to this first
ad-disabled upload. Debug test banners do not prove production fill or consent.

ATT is not requested by the current contextual-only path. iOS publisher
first-party ID is explicitly disabled before SDK initialization; UMP still
controls ad consent. The SKAdNetwork list follows Google's iOS quick-start.
If a provider enables IDFA or cross-company tracking, release is
blocked until the consent design, Apple privacy declaration, Android Data
Safety declaration, privacy policy, and ATT behavior are reviewed together.

Primary references checked on 2026-09-06:

- [Google Flutter UMP lifecycle](https://developers.google.com/admob/flutter/privacy)
- [Google iOS setup and SKAdNetwork](https://developers.google.com/admob/ios/quick-start)
- [Google official test banners](https://developers.google.com/admob/flutter/test-ads)
- [Apple tracking and privacy disclosure](https://developer.apple.com/app-store/user-privacy-and-data-use/)

Public legal content is prepared for `https://bilhealth.com`, but domain
ownership is not proof that any page is published. Publishing and verifying the
privacy, terms, support, contact, deletion, subscription-terms, and health
disclaimer pages is an owner external action.
