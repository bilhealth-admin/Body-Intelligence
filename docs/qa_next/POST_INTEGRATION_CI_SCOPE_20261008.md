# BIL-00 — QA-only post-integration verification

Source under test: `c653fb55485369da62915953ccc0c721dd4cc9ed`  
Permitted branch: `qa/coach-community-next-20261005`

This documentation-only commit requests a fresh independent GitHub Actions QA run for the
integrated BIL-01…08 source. No application behavior or visuals are modified by this file.

This is **not** a release approval. The QA must independently verify:
- Flutter 3.44.6 lockfile, formatting, analyzer and architecture guard.
- Coach, Community and daily-log regression, including all existing tests.
- Four portable regression shards and isolated SQL contracts.
- Actual Flutter visual evidence, not generated image substitutes.
- Frozen Dashboard layout, unchanged payment/Trial/build numbers.

Explicitly out of scope: `main`, production, Supabase deployment, app-store builds,
universal-link deployment, pricing/payment changes, iOS 35/Android 32 changes.

A GitHub Actions pass does not by itself prove device E2E or pixel parity.
