# BIL Smart Plan — Apple / Google compliance and health safety gates (2026-10-22)

Official sources verified on 2026-10-22:
1. https://developer.apple.com/app-store/review/guidelines/
2. https://developer.apple.com/design/human-interface-guidelines/healthkit/
3. https://developer.apple.com/design/human-interface-guidelines/design-principles
4. https://support.google.com/googleplay/android-developer/answer/16679511?hl=en
5. https://support.google.com/googleplay/android-developer/answer/14738291?hl=en
6. https://support.google.com/googleplay/android-developer/answer/13985936?hl=en-GB
7. https://support.google.com/googleplay/android-developer/answer/16353813?hl=en

## Review-relevant principles

### Apple 1.4.1 — physical harm
- Health and medical advice may face additional scrutiny. Do not claim diagnosis, therapy, or accurate individual health measurements without validating clinical methodology and appropriate regulatory review.
- Include consult-a-professional reminder before medical decisions; redirect for red flags rather than building an unsafe plan.
- Display evidence and limitations where source catalog supports them; don't launder generic AI claims as evidence.
- Never auto-prescribe calories or exercises without individual contraindication checks.

### Apple 5.1.1 + 5.1.2 + 5.1.3 — privacy, consent, third-party AI and HealthKit
- Explain categories of health data, precise purpose, recipients, retention, deletion, and consent revocation in product and public privacy policy.
- Explicit consent required before sending selected sensitive user data to Gemini. Separate local plan usage from remote AI processing, so declining cloud AI consent does not remove valid offline planning.
- HealthKit or other collected health data must not be sold, shared with ad networks, used to target ads, or used for marketing profiling. Audit AdMob isolation in native and Flutter layers.
- Do not fabricate or automatically export proposed workouts/food to HealthKit. Only user-approved, completed factual entries may be eligible and only within HealthKit permissions.
- No health information in iCloud. Owner scope and encryption/backup handling require verification.
- Give explicit, easy data export and deletion routes, including plan data and logs.
- Explain subscriptions clearly and don't gate unrelated privacy permissions behind payment.

### Apple 3.1.1 — in-app purchases
- Reuse existing server-verified PremiumRouteGlassGate personalPlan entitlement.
- No custom external paywall for unlocking native app Smart Plan and AI modules. Keep existing approved StoreKit purchase/restore paths.
- Review notes must specify which features are included in Premium vs AI Coach and what happens when credit runs out.

### Apple review quality / HIG
- Real reviewer/demo journey to create and activate a safe 7-day sample plan, show verified training contents, and test sign-out.
- VoiceOver, Dynamic Type, contrast, minimum target sizes, visible back navigation, native feel.
- No copycat of unrelated commercial interface. Use BIL pearl/glass tokens, consistent semantic colors and localization.

### Google Health Content and Services
- Complete Health apps declaration in Play Console, including closed test tracks; refresh category if Smart Plan features expand.
- Public accessible non-geofenced privacy policy in app and Play listing, covering collection, processing, sharing and retention.
- Avoid misleading health content; advise consulting a licensed professional for medical guidance.
- Request only essential permissions; Health Connect access is feature-scoped and opt-in; no health data for advertising.

### Google AI-generated content
- In-app report/flag action for generated plan advice must be accessible without exiting the app. Reuse existing AI Coach report flow, with plan proposal ID and provenance; verify actual working submission.
- Safety input/output filters, abuse red-team tests, appeals/reports moderation flow; no dangerous or deceptive output.
- Do not label generated training content as certified or reviewed when not reviewed.
- Ensure AI actions are proposals until explicit client receipt; user can edit or reject them.

### Google Play Billing / Data safety
- Server-verified subscription entitlement and Play Billing for digital features; preserve restore and pricing on visible paths.
- Declare collection/sharing truthfully: users' physical measurements, goals, nutrition, workout progress, and AI data recipients, with appropriate conditional distinctions.
- Account deletion and retention pathways must cover local + cloud plans and events after cloud migration.

## Safe product boundaries

- Training, meals and bodyweight metrics are wellness support, not medical devices.
- Evaluate contraindications and risk of low energy availability or rapid loss. Avoid attaching precise aggressive targets without validated sources and professional review.
- A missed day is not a failure or a reason to punish the user with more exercise or calorie restrictions.
- Show source reference and when the plan was reviewed; do not imply an LLM produced clinically validated medical guidance.
- Minors, pregnancy and other higher-risk contexts require their own assessment rules before generating individualized training/nutrition.
- Include timezone/DST, allergies and dietary cultural requirements, offline persistence, account change and accessibility in QA.
- An AI outage must not destroy or rewrite an approved schedule.

## Gate checklist (all must be verified)

[ ] Remote data notice has granular and revocable consent before each new category or recipient.
[ ] HealthKit/Health Connect plan proposals never written as completed facts.
[ ] Ads and attribution SDK cannot receive health plan, meal, weight or workout attributes.
[ ] Approved media and recipe source identities validated; no fabricated video.
[ ] Generated AI advice has working report button and moderation operation.
[ ] No custom bypass to StoreKit or Play Billing.
[ ] Subscription states include fresh, loading, expired, boost-only, trial, and signed-out.
[ ] Offline mode can view last approved plan, not last logged-in user's private plan.
[ ] User can delete/export all plan data, and remote deletion follows policy.
[ ] Reviewer walkthrough and policy declarations match the exact release binary.
[ ] Consult-professional and escalation cases tested end to end.
[ ] Final policy counsel checks regional legal/medical requirements; these guidelines are not legal clearance.

## Reviewer note example (EN — adapt only after features pass tests)

BIL Smart Plan is a wellness schedule builder, not a diagnostic or treatment product. It creates a reviewable 7-day, 1-month, 3-month or 6-month plan using verified in-app exercise references and recipe selections compatible with the member's recorded dietary restrictions. Draft meals are not food records and draft sessions are not completed workouts. Users must explicitly approve a plan and confirm actual workout completion. No new access to HealthKit or Health Connect is requested by this feature. AI personalization beyond the on-device proposal follows the app's separate, explicit Gemini consent flow. The feature uses the existing server-verified Premium entitlement and native in-app purchase flow. Provide reviewer demo account and visible navigation once verified.
