# Changelog

## Foundation v2 — current local development

- Protected the verified offline baseline with `v1.0.0-mvp-offline`.
- Added explicit Drift migrations through schema v11 with durable UUID,
  revision, timestamp, sync-state, and tombstone metadata where applicable.
- Added once-only bilingual onboarding, canonical metric storage, metric and
  imperial boundaries, synchronized wheel/text entry, and daily check-in.
- Added live English/Arabic food search, starter foods, provenance, custom
  foods, favorites, recents, barcode fallback, meals, nutrients, and water.
- Added deterministic BMR, TDEE, targets, hydration, BIL Score, Body Twin,
  What Changed, One Best Action, Data Honesty, Recovery, and Weekly Review.
- Added Life Context, Decision Memory, editable plan overrides, adaptive usual
  meals, personal experiments, private challenges, and privacy-safe PNG share
  cards.
- Added persisted theme, locale, unit, high-contrast, and reduce-motion
  preferences, local export/reset, responsive navigation, and honest disabled
  external capability states.

This file records implemented behavior only. Authentication, cloud sync, AI,
payments, coach/community sharing, and remote updates are not listed as shipped
because no verified production adapters or credentials are present.
