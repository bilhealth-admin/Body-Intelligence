# BIL v1 — Epic 15 store assets and visual evidence

This is the concise release evidence index for Epic 15. It does not claim that
Apple App Store Connect or Google Play Console owner actions have occurred.

## Production captures

`test/epic15_store_screenshot_golden_test.dart` renders real production pages,
not marketing mockups, at physical iPhone 6.9-inch and Android phone sizes. The
set covers dashboard, meal logging, progress, plans, connected-health denial,
privacy/settings, RTL Arabic, Light/Dark, and localized French, Spanish, and
Turkish plan states. Missing services remain visibly unavailable; no connected
device, purchase, cloud, or AI success is fabricated.

The generated upload copies are under:

- `store_assets/screenshots/apple/` — 23 opaque 1290×2796 PNG captures,
  grouped by filename locale (10 English, 10 Arabic, one per remaining locale).
- `store_assets/screenshots/google_play/` — 19 opaque 1080×1920 PNG captures
  (eight English, eight Arabic, one per remaining locale).

## Current BIL artwork authority

- The owner-approved app-icon source is
  `assets/branding/bil_app_icon.png`, pinned in the rights ledger with SHA-256
  `f6a183d2fdfb0a27e44c9eedc368cf6437b9e45ca65c4054da75818b092d0b46`.
- The current full wordmark is the code-owned `BilFullWordmark` in
  `lib/shared/widgets/bil_wordmark.dart` (`BODY INTELLIGENCE LOG™`).
- The current Google Play 512 icon is
  `store_assets/graphics/google_play/play_icon_512.png`, pinned with SHA-256
  `7e6e6165b7171a35aed32d11dc196195172acaba067e48eeb3d6dbe2c438970e`.
  Fresh Apple inspection and the latest safe Google read-back match the current
  approved icon derivatives as recorded in
  `BIL_STORE_BRAND_LIVE_READONLY_AUDIT_2026-09-06.md`.
- The owner explicitly confirmed that the current live Apple and Google store
  logos, including the live Google feature graphic, are correct and must not be
  changed. The absence of an exact current 1024×500 source copy in this tree is
  a reproducibility improvement to resolve later, not evidence that the live
  graphic is wrong and not authority to replace it.
- The historical `BIL-Brand-Assets-v1.zip` artwork and its local feature/plan
  derivatives are retired and are not current approved store art. Their
  recoverable provenance is recorded in
  `BIL_REJECTED_BRAND_ASSET_RETIREMENT_2026-09-06.md`; those retired raster
  paths remain absent from the release tree.
- Android adaptive/monochrome launcher resources and the iOS AppIcon set remain
  deterministic current derivatives. The iOS AppIcon contract forbids alpha,
  and the launch wordmark preserves aspect fit.

Provenance and rights are recorded in
`docs/release/BIL_EPIC15_CONTENT_RIGHTS.json`. Hashes, dimensions, locale,
source, pixel format, and generation date are emitted to
`store_assets/evidence/asset_evidence_matrix.{csv,json}`.

## Store copy and owner boundaries

Localized metadata for Arabic, English, French, Spanish, and Turkish is in
`docs/release/BIL_EPIC15_STORE_METADATA.json`. Separate Apple and Google
checklists, public-page copy, health disclaimers, reviewer notes, rating inputs,
and subscription templates are ready.

The public domain, support email, required HTTPS route availability, and exact
deployed/local legal JavaScript match are now pinned by
`BIL_EPIC15_PUBLICATION_VERIFICATION_2026-09-06.json`. This is technical
publication evidence, not owner legal approval. Store product IDs, review
credentials, and finalized store prices remain owner/store-managed inputs; the
project never substitutes fake URLs or credentials. Screenshot and
generated-art human review remains required before upload.
