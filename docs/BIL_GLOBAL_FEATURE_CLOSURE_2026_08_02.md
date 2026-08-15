# BIL Global Feature Closure — 2026-08-02

This is the release truth for the MyFitnessPal-class capability pass. It
measures equivalent product capability, never copied branding, artwork, or
copyrighted content.

## Code-complete foundations

1. **Global recipes and professional workouts:** removable, checksum-verified
   packs; search, images, metadata, remote video; publishing rejects content
   without an HTTPS asset, rights holder, and license.
2. **Community:** authenticated profiles, posts, friendship requests,
   messages, food submissions, peer review, moderator-only final verification,
   and row-level security.
3. **Daily notifications:** user-selected weight, meal, water, and weekly
   review schedules in device timezone with private five-language copy.
4. **Weekly report:** measured seven-day tracked days, meals, water, calories,
   protein, sodium, and latest weight. Missing days are never estimated.
5. **Voice logging:** real device speech recognition flows into meal entry and
   fails honestly when permission or platform support is absent.
6. **Meal image analysis:** authenticated server gateway, strict schema,
   visible-food candidates and confidence only; no invented nutrition or
   diagnosis; fails closed without a configured provider.
7. **Commerce:** Free, Plus, Pro, Coach, Clinic, and Enterprise; monthly and
   annual purchase/restore surfaces; server entitlements and fail-closed store
   verification boundary.
8. **Arabic/Gulf community foods:** source and nutrition snapshots, peer review
   separated from final moderator verification.
9. **Five-language infrastructure:** Arabic, English, French, Spanish, and
   Turkish. New global modules ship five-language copy; the audit reports every
   legacy hard-coded UI string and blocks key-parity regressions.

## External activation gates

These cannot be completed safely by source generation alone:

- Upload licensed recipe images/workout videos and their verified manifest.
- Configure the production vision provider and gateway secret.
- Create matching App Store Connect/Google Play products and official signed
  verification; pass purchase, renewal, cancellation, and restore on devices.
- Apply Supabase migrations and deploy both Edge Functions; test RLS with two
  real users and a moderator.
- Native review of every legacy string reported by `tool/localization_audit.py`.
- Physical-device validation of notifications, camera, microphone, video,
  account links, offline packs, and timezone changes.

## Non-negotiable release gates

- No competitor or unlicensed asset enters the repository or CDN.
- No nutrition, device reading, AI result, social state, entitlement, or
  payment state is fabricated.
- No paid feature unlocks from a client-only boolean.
- Community votes never grant final verified status.
- A screen alone is not completion: persistence, denial, error/offline,
  privacy, and restore behavior must pass.
- Release requires clean analysis/tests, localization audit, RLS checks, and
  signed-device smoke tests.

## Final execution order

1. Run consolidated static/unit verification.
2. Apply migrations and deploy `analyze-meal` and `verify-store-purchase`.
3. Upload licensed wellness packs and set their manifest URL.
4. Configure vision and store products/secrets.
5. Perform Android/iOS end-to-end checks.
6. Resolve the localization audit with native review, then sign releases.

Until steps 2–6 are evidenced, BIL is **code-ready for integration**, not a
fully activated global production service.
