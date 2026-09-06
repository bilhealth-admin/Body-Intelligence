# BIL store branding live read-only audit — 2026-09-06

Status: **READ-ONLY EVIDENCE COMPLETE / SCREENSHOT RECENCY OPEN**

Audit time: `2026-09-06T05:16:39Z`

This audit used GET-only inspection. It did not create or commit a Google Play
edit, upload or replace media, submit a release, change a store record, or print
credentials. The owner's latest explicit decision is authoritative: the logos
currently shown in Apple and Google are correct and must not be changed.

## Identity authority

- Current app-icon master:
  `assets/branding/bil_app_icon.png`
  - SHA-256:
    `f6a183d2fdfb0a27e44c9eedc368cf6437b9e45ca65c4054da75818b092d0b46`
- Current iOS 1024 derivative:
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
  - SHA-256:
    `7e9a64e33b371873cc77f60361322a5f2884ef61ec21328390ab8d257c3e6484`
- Current Google Play 512 derivative:
  `store_assets/graphics/google_play/play_icon_512.png`
  - SHA-256:
    `7e6e6165b7171a35aed32d11dc196195172acaba067e48eeb3d6dbe2c438970e`
- Current full wordmark remains the code-owned `BilFullWordmark` in
  `lib/shared/widgets/bil_wordmark.dart`.

## Apple: fresh authenticated GET evidence

App Store Connect app `6805349703`, version `1.0.0`, was inspected without
mutation.

- Version state: `DEVELOPER_REJECTED`.
- Attached build: build `7`, ID
  `43c31a3c-42bb-4444-8ea5-117c74397132`, processing state `VALID`, uploaded
  `2026-09-01T04:55:08-07:00`, not expired.
- The build-icons relationship returned two `APP_STORE` 1024x1024 assets
  (masked and unmasked).
- The unmasked 1024x1024 asset was fetched in memory through its Apple asset
  template URL. After decoding and normalizing it with the current iOS 1024
  derivative, all sampled RGBA channels were identical:
  - MSE: `0`
  - PSNR: infinite
  - identical channel values: `100%`
- Therefore the Apple build's live unmasked app icon is a pixel match for the
  current approved iOS derivative. Byte hashes differ only because the PNG
  encodings differ.

The version also has:

- 8/8 COMPLETE iPhone 6.7-inch screenshots at 1290x2796;
- 8/8 COMPLETE iPad Pro 12.9-inch screenshots at 2048x2732;
- complete subscription and in-app-purchase review screenshots.

Every live Apple product-page screenshot ID, name, byte count, and source MD5
matches `G:/BIL_Temp/apple-from-play-required-20260901/manifest.json`. These
are the exact Play-derived assets uploaded on 2026-09-01, not newly captured
evidence for the post-2026-09-06 UI changes.

## Google: latest authenticated cached evidence and safe boundary

The latest authenticated listing-media reads are:

- `G:/BIL_Temp/store-preflight-20260905/google/release-surface-c1.json`
- `G:/BIL_Temp/store-preflight-20260905/google/release-surface-c2.json`

Both independent reads are stable and report:

- locale `en-GB`;
- one icon with SHA-256
  `7e6e6165b7171a35aed32d11dc196195172acaba067e48eeb3d6dbe2c438970e`;
- one feature graphic with SHA-256
  `b596d68e27472140bcb6e6d09f01b4cd9739e67180276eb1f8b3027ef39ede83`;
- 8 phone screenshots with the same ordered hashes as the exact 2026-09-01
  downloaded set in
  `G:/BIL_Temp/play-exact-screenshots-20260901/manifest.json`.

The live icon hash is byte-identical to the current local Google Play 512
derivative. An in-memory comparison against the approved 1024 master after a
Lanczos 512 resize measured PSNR `50.89 dB` and MSE `0.53`, consistent with a
deterministic resized derivative.

No fresh 2026-09-06 Google image read was attempted. Google Play listing-image
reads require an edit ID. The existing tools insert and later delete a
transient edit, which is a mutation. Google documents that inserting a new edit
invalidates another active edit for the same app and API user, while a commit
can submit all valid changes already in the edit. With no known current edit ID
and no exclusive edit-ownership window, creating one would violate this
audit's read-only boundary and introduce avoidable console concurrency risk.

Official reference:
<https://developers.google.com/android-publisher/concurrency-considerations>

The owner's explicit confirmation governs the current store artwork: these
live store logos are approved and are not a release blocker. Separately, there
is no current 1024x500 PNG under `assets/` or `store_assets/`; retaining a
current-tree source copy for the owner-approved live feature graphic remains a
reproducibility/provenance improvement, not evidence that the live graphic is
wrong.

The same historical path still exists in Git `HEAD` only (it is deleted from
the working tree):

- `HEAD`: `21f16767fad82d625ced9b6da2146b66b4b27953`
- Git blob: `cc524b89f6e7f01c29c3823b82584ed52dcc8cc6`
- blob byte count: `765431`
- blob SHA-256:
  `c79b06d7aa7262b10a625da5df46d6d900276ab64ca8637c65f3fac375e4defe`

That SHA-256 is **not** byte-for-byte equal to the cached live Google feature
graphic SHA-256 `b596d68e...`. The difference may be store-side encoding, but
hash evidence alone cannot prove pixel identity. Therefore the historical blob
must not be restored as an assumed exact live source without a separately
verified pixel comparison and owner approval.

## Public legal pages: fresh GET evidence

Fresh GET requests returned HTTP 200 without redirect for:

- `https://www.bilhealth.com/privacy`
- `https://www.bilhealth.com/terms`
- `https://www.bilhealth.com/support`
- `https://www.bilhealth.com/account-deletion`
- `https://www.bilhealth.com/app.js`

The remote `app.js` SHA-256 is
`11088baa1d341ebf29dbc284d3986735d2e82e9ee88d0dea39c1e3124e04acb2`,
byte-identical to `public_site/app.js`. The deployed script routes the requested
pathname and contains the current English and Arabic privacy and terms text,
including the 18-or-older requirement and the prohibition on use by people
under 18. Thus the public deployment now contains the local 18+ legal update.

`docs/release/BIL_EPIC15_STORE_METADATA.json` previously carried the older
`DOMAIN_LIVE_LOCAL_18_PLUS_PRIVACY_AND_TERMS_UPDATE_NOT_DEPLOYED_2026_08_24`
status. It now pins
`BIL_EPIC15_PUBLICATION_VERIFICATION_2026-09-06.json` and describes only the
observed HTTP/content-match state. Both records explicitly keep legal approval
as `NOT_CLAIMED`.

## Honest remaining boundary

- Store logos: owner-confirmed correct, with exact Apple and Google icon
  evidence above.
- Apple screenshot presence/integrity: freshly confirmed.
- Google screenshot presence/integrity: last authenticated evidence is
  2026-09-05 because a safe fresh GET was not possible without an existing edit
  ID.
- Screenshot representation of the current app: open. Both stores use the
  exact 2026-09-01 screenshot set, which predates the current UI and branding
  cleanup. A new post-fix capture-and-review cycle is needed before claiming
  the screenshots prove the current release candidate.
