# BIL v1 — Epic 7 content closure

This is the concise closure record for the current 16-Epic plan. It is not a
content claim: only installed, checksum-verified and attributable packs are
shown to users.

## Closed in code

- Ten bilingual nutrition pathways: cutting, lean mass, Mediterranean,
  high-protein, plant-forward, DASH, low-carb, keto, pregnancy and PSMF.
- Pathway selection persists locally and opens an explicit review draft.
  Selecting a pathway never silently changes calorie or macro targets.
- Keto and pregnancy remain clinician-review pathways. PSMF remains locked
  behind medical supervision.
- Recipe and professional-workout libraries read only installed content packs.
- Pack size and SHA-256, payload schema, declared item count and item type are
  verified before installation.
- Every rendered item must be explicitly verified and include publisher,
  HTTPS source and license attribution. Media URLs must use HTTPS.
- Search, recipe instructions, remote workout video playback, visible recovery
  errors, offline installed-pack reading and local activity logging are wired.
- Nutrition values are not accepted from wellness content packs; recipes use
  the separate sourced nutrition calculation pipeline.

## External release inputs

- Licensed recipe/workout publishers must supply the real manifests, media and
  content archives. BIL fails closed when these are absent or invalid.
- Clinical approval and entitlement issuance remain external operational
  boundaries. No placeholder approval, invented nutrition or unlicensed media
  is bundled.

