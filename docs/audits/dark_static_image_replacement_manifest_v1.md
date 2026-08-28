# Dark static image replacement audit

Date: 2026-08-24  
Scope: user-facing static images only; photoreal daytime replacements for the approved P1 dark/blue synthetic assets.

## Verified replacements

| Asset | Active usage | Replacement scene | Final size | SHA-256 | Verification |
| --- | --- | --- | --- | --- | --- |
| `assets/images/brand/generated/bil_dashboard_body_twin_hero_v1.png` | `dashboard_reference_phone_components.dart` | Real athletic woman checking phone and watch after a morning workout; bright home and clean left copy space | 1672×941 | `e24a31dcd7a39da4d4600c71b37cad0147b54456f8549ceb7fc48b41c05ccb3f` | Crop and composition visually verified |
| `assets/images/dashboard/bio_intelligence_v1.png` | Dashboard and dashboard reference sections | Real athletic man reviewing phone and watch by a daylight window | 1536×1024 | `dae3a12a9b702c8f92757a7a4c84ea7314eb16687fbabfa72d070ec8dedc1f77` | Crop and composition visually verified |
| `assets/images/brand/generated/sleep_hero_photoreal_v1.png` | `sleep_tracker_experience.dart` | Real woman waking refreshed and checking her watch in a bright bedroom | 1536×1024 | `98b96f97ddc66e6ca1d4b2c618470d1c3e094a7855c43e39914d882be3076a90` | Crop and composition visually verified |
| `assets/images/ai_coach/bil_male_smart_coach_v1.png` | Dashboard, intelligence center, AI Coach settings, shared avatar | Approachable real male fitness coach in a bright neutral studio | 384×384 | `3d579645064251201bff7ded491a3d7a9277f76d6b98ff995a6ae6e826efd167` | Square and circular-safe crop visually verified |
| `assets/images/connected_health/bil_medical_hub.png` | Connected Health component and dashboard shortcut | Real woman checking a smartwatch beside a phone and home blood-pressure monitor | 1536×1024 | `bc034e70997e35c1d7d30b6b206d0f934ff46f4d306760f4dc67029fdac9a98c` | Crop and subject placement visually verified |
| `assets/images/daily_context/fasting_v1.png` | Daily context: fasting | Real man ending a planned fast with water, dates, a healthy bowl, and an analog clock | 768×512 | `5bcf48ccd7ad100dfed3aa4a0eeb9abca660995b3f33249e0eb3b8d466e05246` | Visually verified |
| `assets/images/daily_context/hard_workout_v1.png` | Daily context: hard workout | Real sweaty athlete recovering on a bright gym bench with towel and bottle | 768×512 | `0ef3eaae78b511300eb9255c86d8cfce33fe3391e314edde5a2d308843908b99` | Visually verified |
| `assets/images/daily_context/medication_v1.png` | Daily context: medication | Real woman holding one tablet beside water and a pill organizer at a bright table | 768×512 | `bd8ac3cda8e0bd6bf086b1c2f5cf1d97691f64a6e56af6a147706e7877959510` | Visually verified |
| `assets/images/daily_context/less_water_v1.png` | Daily context: less water | Real man after a sunny walk inspecting a nearly empty clear water bottle | 768×512 | `7dcf59a21ca1ee6f28a956deacf31c878b7c94291b6aa06367e1b20cb0434cdd` | Visually verified |
| `assets/images/daily_context/other_v1.png` | Daily context: other | Bright real desk with a hand writing in a blank notebook, water, phone, and plant | 768×512 | `c1d0b32ebd86263ad252247c40fe3b7d6ce4491df457d3e56771411cd06b3a63` | Visually verified |

All replacements contain no embedded text, logos, UI overlays, or dark/night-blue treatment. The generated masters were center-cropped with aspect-ratio preservation to the exact pre-existing runtime dimensions.

## Image generation provenance

Built-in `imagegen` output directory: `C:/Users/HP 1040 G8/.codex/generated_images/01a0334a-fbf7-7b41-a1bb-fbd5b9c728c1/`

| Runtime asset | Generated master |
| --- | --- |
| Dashboard body twin | `exec-9a4832dd-c3fe-47f5-9c04-2391db9d344b.png` |
| Bio intelligence | `exec-94b046fb-2919-4140-82fa-29bfd8d77c13.png` |
| Sleep hero | `exec-e4a7ccf2-ebc6-4890-9b6d-ed841287ed2c.png` |
| AI Coach portrait | `exec-0ab7a631-b041-4811-a426-40f4d72272de.png` |
| Connected Health | `exec-2ca61895-d9ac-4e41-9a18-f1f57b9082f9.png` |
| Fasting | `exec-917c2e24-cfba-4441-abe0-48f256e83cbd.png` |
| Hard workout | `exec-070fc73f-599c-4050-9c0b-b961edaf3781.png` |
| Medication | `exec-d8dc06cc-d674-4017-a528-f87528c0b448.png` |
| Less water | `exec-7519a44e-44be-495c-9cc6-e7f323507fe2.png` |
| Other | `exec-1f1ed334-8264-4965-ab42-af52211a68dc.png` |

Final generation prompt set:

1. **Dashboard body twin:** Photoreal premium wellness editorial photo of a real fit woman after a morning walk, checking her smartwatch while holding a phone in a bright modern home; subject on the right, calm clean negative space on the left; warm daylight, natural skin and fabric detail; no holograms, UI, text, logos, night scene, navy wash, illustration, or 3D render.
2. **Bio intelligence:** Photoreal premium lifestyle photo of a real active man reviewing his smartwatch and phone beside a sunlit apartment window with healthy greenery; subject weighted to the right and open bright space on the left; authentic candid expression; no overlays, text, logos, dark blue lighting, illustration, or CGI.
3. **Sleep hero:** Photoreal premium morning wellness photo of a real woman waking refreshed on a neatly made bed and checking her smartwatch; airy sunlit bedroom, warm neutral palette, clean left-side copy space; no night scene, blue tint, text, logos, illustration, or synthetic glow.
4. **AI Coach portrait:** Square photoreal studio portrait of an approachable real male fitness coach, friendly confident expression, light blue athletic shirt, bright neutral gym studio, centered head and shoulders with safe circular crop; no headset, text, logos, neon, black background, illustration, or CGI.
5. **Connected Health:** Photoreal premium health-tech lifestyle photo of a real woman at a bright home table checking her smartwatch, with a phone and home blood-pressure monitor nearby; calm trustworthy daylight; no medical alarm, screen text, logos, overlays, illustration, or render.
6. **Fasting:** Photoreal daylight lifestyle photo of a real man calmly ending a planned fast at a bright dining table with water, dates, a healthy bowl, and a small analog clock; authentic food and skin texture; no text, logos, darkness, illustration, or CGI.
7. **Hard workout:** Photoreal daylight gym photo of a real athletic woman resting after a demanding workout on a bench with towel and water bottle; genuine sweat and recovery, bright windows, natural body proportions; no text, logos, dark cinematic lighting, illustration, or CGI.
8. **Medication:** Photoreal daylight home-health photo of a real woman holding one tablet beside a glass of water and weekly pill organizer at a bright kitchen table; blank unbranded bottle, calm responsible mood; no readable labels, text, logos, dark lighting, illustration, or CGI.
9. **Less water:** Photoreal daylight park photo of a real man tired after a sunny walk, seated and inspecting a nearly empty clear water bottle; green lively setting and natural expression; no medical distress, text, logos, darkness, illustration, or CGI.
10. **Other context:** Photoreal bright desk scene with a real hand writing in a completely blank notebook, phone face down, glass of water, and green plant; natural window light and quiet reflective mood; no readable writing, text overlays, logos, darkness, illustration, or CGI.

## Sleep insight reference migration

All remaining runtime references to `assets/images/flagship/bil_sleep_insights_v1.png` were migrated to `bil_sleep_insights_v2.png`; the explicit v1 bundle entry was removed from `pubspec.yaml`. No positive v1 runtime or bundle reference remains. One contract test intentionally retains the filename only inside a negative `isNot(contains(...))` assertion.

## Explicit exclusions

- Six workout collection covers already handled by the parent task
- All workout posters, 302 workout videos, workout manifests, and recipe assets
- `meal_discovery_v1`, `today_summary`, intermittent-meal imagery, and every bright/colorful image
- Notification, AI runtime, Supabase, and policy-audit files
