# BIL advertising, privacy, and consent boundary

BIL remains a free download. Eligible registered adult Free users may see
contextual, non-personalized advertising only when Google's UMP state permits
an ad request and a reviewed production provider plus real store identifiers
are configured. Premium subscribers are ad-free and Guests are excluded.

The shipped default is fail-closed: advertising, provider readiness, and unit
identifiers are disabled or empty. No demo IDs, test ads, fallback provider, or
fabricated fill is shipped. No ad request is made when UMP cannot authorize it,
the account entitlement or adult gate is unresolved, the device is offline,
the provider is unavailable, or the placement is sensitive. BIL does not
provide a separate product-level switch that permanently converts the Free
plan into an ad-free plan.

Advertising must never use health records, nutrition entries, food searches,
weight, body measurements, device readings, location-health inferences,
profile attributes, community private content, or AI meal results for targeting
or measurement. Ads are excluded from Dashboard, Daily Log, food entry,
Progress, reports, connected health, profile, settings, and purchase screens.
Only explicitly classified general discovery or wellness-library placements may
request a contextual ad.

ATT is not requested because the current architecture does not track users or
link data across companies. If a future provider changes that fact, release is
blocked until the consent design, Apple privacy declaration, Android Data
Safety declaration, privacy policy, and ATT behavior are reviewed together.

Public legal content is prepared for `https://bilhealth.com`, but domain
ownership is not proof that any page is published. Publishing and verifying the
privacy, terms, support, contact, deletion, subscription-terms, and health
disclaimer pages is an owner external action.
