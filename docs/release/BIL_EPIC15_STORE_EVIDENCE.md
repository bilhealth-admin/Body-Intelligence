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

## Original BIL artwork

- Canonical owner-approved source:
  `BIL-Brand-Assets-v1.zip`, pinned by SHA-256 in the rights ledger and copied
  unchanged under `store_assets/source/` by the gate.
- Google Play feature graphic: 1024×500 opaque PNG.
- Google Play icon: 512×512 PNG.
- Free, Plus, and Pro plan art: three original 1080×1440 opaque PNGs,
  aspect-fit derivatives of the approved three-plan master without stretching.
- Android adaptive and monochrome launcher resources.
- iOS AppIcon set with no forbidden alpha and a responsive launch mark.

Provenance and rights are recorded in
`docs/release/BIL_EPIC15_CONTENT_RIGHTS.json`. Hashes, dimensions, locale,
source, pixel format, and generation date are emitted to
`store_assets/evidence/asset_evidence_matrix.{csv,json}`.

## Store copy and owner boundaries

Localized metadata for Arabic, English, French, Spanish, and Turkish is in
`docs/release/BIL_EPIC15_STORE_METADATA.json`. Separate Apple and Google
checklists, public-page copy, health disclaimers, reviewer notes, rating inputs,
and subscription templates are ready.

The repository contains no verified public domain, support email, store product
IDs, review credentials, or finalized store prices. Those values remain
explicitly marked `OWNER_INPUT_REQUIRED`; the project never substitutes fake
URLs or credentials. Screenshot and generated-art human review remains required
before upload.
