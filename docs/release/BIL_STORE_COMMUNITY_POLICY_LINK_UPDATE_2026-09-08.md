# BIL Store Community Policy Link Update — 2026-09-08

Status: **HISTORICAL UPDATE EVIDENCE; CURRENT APPLE AUTH UNAVAILABLE; NO RELEASE**

## Current read-only boundary

The before/after records below remain the retained evidence from the guarded
metadata operation. They are not a claim of current Apple state. The latest
read-only console attempt reached the App Store Connect sign-in boundary with
`authResult=FAILED`; authentication was not attempted, so current Apple build,
review, subscription and exact validation state are unverified and no metadata
was changed from that screen.

The latest Google Play read-only console audit shows the `en-GB` description
change as the single change ready to publish. Managed publishing is on,
Production is inactive and its production-access application is under review.
The change was deliberately not published and no artifact/track/release action
was taken.

## Scope

Publish this production Community Guidelines URL in the existing BIL store
metadata without changing privacy/support URLs, reviewer credentials, release
mode, builds, artifacts, or release tracks:

`https://www.bilhealth.com/community-guidelines`

No credential value, access token, reviewer credential, or private key was
written to this report or to the generated evidence.

## Public document verification

- Cloudflare Worker production version:
  `f8023569-4367-4a8a-9f4a-3ce8efbf77e0`.
- The production route returned HTTP `200` with `text/html`.
- The site is a client-rendered SPA. The raw route response is intentionally the
  shared HTML shell; production `app.js` contains `community-policy-v1`, the
  English and Arabic Community Guidelines titles, and the effective date
  `8 September 2026`.
- A real browser verification confirmed the complete English and Arabic policy
  views and all policy sections before the store mutations.
- A final read-only check extracted the exact URL from both live store
  descriptions, fetched it successfully (`HTTP 200`, no redirect), and verified
  that the production `app.js` still contains the v1 English and Arabic policy.
- Browser verification here covers the public web document only; it is not
  evidence of the in-app acceptance or publishing flow on iOS or Android.

## Field selection

Neither App Store Connect's version-localization resource nor Android
Publisher's store-listing resource exposes a dedicated Community Guidelines URL
attribute. The narrow, semantically correct fields were therefore:

- Apple `appStoreVersionLocalization.description` for locale `en-US`.
- Google Play `listing.fullDescription` for locale `en-GB`.

The following purpose-specific fields were deliberately preserved rather than
repurposed:

- Apple `privacyPolicyUrl`, `privacyChoicesUrl`, `supportUrl`, and
  `marketingUrl`.
- Google Play `contactWebsite`, title, short description, and video.

The exact appended line on both stores is:

`Community Guidelines: https://www.bilhealth.com/community-guidelines`

## App Store Connect result

- App: `6805349703`.
- Version: `1.0.0`.
- Version localization: `3866ba6c-b637-4f70-9c53-d6274c37bc62` (`en-US`).
- Before: link absent; description length `1179`.
- After: link present; description length `1249`.
- App Store state remained `DEVELOPER_REJECTED`.
- Release type remained `MANUAL`.
- Support URL remained `https://www.bilhealth.com/support`.
- Marketing URL remained `https://www.bilhealth.com/`.
- Reviewer contact, demo-account, password, and notes presence flags matched
  before and after. Their values were never emitted.
- The API call PATCHed only `description`. It did not select a build, create a
  version submission, submit for review, or release the version.
- Independent readback and a second idempotency run passed. The second run
  reported `MUTATION_PERFORMED=false`.

## Google Play result

- Package: `com.bilhealth.bodyintelligencelog`.
- Listing locale: `en-GB`.
- Before: link absent; full description length `2187`.
- After: link present; full description length `2257`.
- Title remained `Body Intelligence Log`.
- Contact website remained `https://www.bilhealth.com`.
- Short description, video, and app details matched before and after.
- The production track payload matched before and after.
- The API edit updated only `listing.fullDescription`; no AAB/APK was uploaded
  and no track or release endpoint was mutated.
- The metadata edit was committed so the listing change could persist. No
  explicit release or submission endpoint was called; Google retains its
  existing review/managed-publishing behavior.
- Independent readback used a fresh transient edit, then deleted it. A second
  idempotency run passed with `MUTATION_PERFORMED=false`.

## Safe console results

```text
node --check Apple updater: PASS
node --check Google updater: PASS

APPLE_COMMUNITY_GUIDELINES_LINK=https://www.bilhealth.com/community-guidelines
MUTATION_PERFORMED=true
REVIEW_CREDENTIAL_PRESENCE_PRESERVED=true
RELEASE_TYPE=MANUAL
SUBMIT_OR_RELEASE_PERFORMED=false

GOOGLE_PLAY_COMMUNITY_GUIDELINES_LINK=https://www.bilhealth.com/community-guidelines
MUTATION_PERFORMED=true
PRODUCTION_TRACK_PRESERVED=true
SUBMIT_OR_RELEASE_PERFORMED=false

Apple independent readback: targetPresent=true, descriptionLength=1249
Google independent readback: targetPresent=true, descriptionLength=2257
Apple idempotency: MUTATION_PERFORMED=false
Google idempotency: MUTATION_PERFORMED=false
Store-extracted link check: Apple=true, Google=true, HTTP=200, v1 EN/AR=true
```

## Reproducible tooling and evidence

Narrow guarded tools:

- `tool/apple_store_connect/asc_community_guidelines_link_update.mjs`
- `tool/google_play/google_play_community_guidelines_link_update.mjs`

Local sanitized evidence directory (intentionally ignored by Git):

- `artifacts/release/store-community-policy-2026-09-08/apple-before.json`
- `artifacts/release/store-community-policy-2026-09-08/apple-update.json`
- `artifacts/release/store-community-policy-2026-09-08/apple-after.json`
- `artifacts/release/store-community-policy-2026-09-08/apple-idempotency.json`
- `artifacts/release/store-community-policy-2026-09-08/google-before.json`
- `artifacts/release/store-community-policy-2026-09-08/google-update.json`
- `artifacts/release/store-community-policy-2026-09-08/google-after.json`
- `artifacts/release/store-community-policy-2026-09-08/google-idempotency.json`

The full before/after audits were generated with the repository's existing
read-only audit tools. Google transient readback edits were deleted; Apple
readback used GET requests only.
