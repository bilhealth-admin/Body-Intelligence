# BIL store promo — fal.ai / LongCat production brief

Status: production-ready brief; no paid generation or publication was run.

## Verified production boundary

- The existing paid workout-video pipeline uses **fal.ai — LongCat Video Distilled**, endpoint `fal-ai/longcat-video/distilled/image-to-video/720p`. It is not HeyGen.
- The approved BIL coach reference is `assets/images/commerce/bil_ai_boost_coach_icon_512.png`.
- Real application frames must come from the checked-in Flutter goldens listed below. Generated or reconstructed UI is forbidden.
- `FAL_KEY` is supplied privately by the owner through the environment only. It must never be pasted into a prompt, command argument, log, report, or committed file.
- The repository currently blocks bulk paid execution until live price and billing-duration calibration are re-verified. A promo render must use the same fail-closed preflight and receive a separate owner review before any paid request.

## Deliverables

1. **Store-safe master:** 30 seconds, 9:16, 1080 × 1920, 30 fps, H.264, English captions burned in, app UI dominant.
2. **Advertising cut:** derived from the approved master, 30 seconds, 9:16, same claims and footage.
3. **Landscape adaptation:** 30 seconds, 16:9, crop/reframe only after the 9:16 master is approved.

The store-safe master must never imply diagnosis, treatment, medical-device support, guaranteed outcomes, or personalised medical advice.

## Story spine

Outcome: BIL turns daily food, activity, body and recovery signals into one clear next step.

Audience tension: fitness apps scatter logging, workouts and progress across disconnected screens.

Proof: show real BIL UI, not abstract claims — dashboard, focused meal logging, verified food search, more than 300 workout videos, 1,500 recipes, progress analytics and the AI Coach conversation.

Call to action: **Build your body intelligence.**

## 30-second storyboard

| Time | Picture and motion | On-screen copy | Voice-over | Frozen source |
|---|---|---|---|---|
| 0:00–0:03 | Tight, photoreal coach portrait. Subtle natural breath and a restrained camera push; face, clothing and identity stay exact. Clean white-to-blue BIL light sweep, no invented gym. | `One clear next step.` | “Your goals are personal. Your guidance should be too.” | `assets/images/commerce/bil_ai_boost_coach_icon_512.png` |
| 0:03–0:07 | Real Dashboard screen enters as a crisp phone capture. Cards move only through local pan/scale; never regenerate text. | `Your day, understood.` | “BIL brings your day into one intelligent view.” | `test/visual_closure/goldens/visual_closure_dashboard_phone.png` |
| 0:07–0:11 | Focused meal entry, then verified food result. Use a clean match cut through the search field. | `Log food with confidence.` | “Log meals quickly, with verified search and clear nutrition.” | `test/visual_closure/goldens/visual_closure_daily_log_meal_entry_phone.png`; `test/visual_closure/goldens/visual_closure_food_catalog_verified_result_phone.png` |
| 0:11–0:15 | Recipe and workout libraries slide side by side, each held long enough to read. | `1,500 recipes` / `300+ workout videos` | “Explore fifteen hundred recipes and more than three hundred workout videos.” | `test/goldens/epic15_evidence_en_recipe_library.png`; `test/goldens/epic15_evidence_en_workout_library.png` |
| 0:15–0:20 | Progress analytics animate through a masked reveal using the real chart pixels. No fabricated values. | `See what is changing.` | “Turn real records into progress you can understand.” | `test/visual_closure/goldens/visual_closure_analytics_progress_phone.png`; `test/visual_closure/goldens/visual_closure_analytics_seven_days_phone.png` |
| 0:20–0:25 | AI Coach conversation takes centre frame; the approved coach portrait appears beside it. Use gentle parallax only. | `Ask. Understand. Act.` | “Then ask your AI Coach for a practical next step, in your language.” | `test/visual_closure/goldens/visual_closure_ai_coach_conversation_phone.png`; approved coach reference |
| 0:25–0:30 | Real app screens collapse into the BIL lockup. CTA resolves on a clean blue field. | `Build your body intelligence.` / `Start with BIL` | “Body Intelligence Log. Build your body intelligence.” | current approved BIL brand assets and real UI frames only |

## LongCat image-to-video prompt

Use this only for the coach shot. UI shots are composited locally from exact screenshots and must not be sent through a generative model.

> Photorealistic premium fitness-coach portrait animation using the supplied BIL coach image as the exact identity and wardrobe reference. Preserve the same adult male face, hairstyle, skin tone, proportions, light-blue athletic shirt, framing and bright clean studio. He makes one natural breath, a small confident eye movement and a restrained welcoming half-smile while the camera performs a very slow three-percent push-in. Soft daylight, realistic skin and fabric, stable background, commercial wellness tone, no speaking mouth shapes, no exaggerated gesture, no camera shake. The result must begin and end on stable frames suitable for a clean edit.

Negative prompt:

> identity drift, face change, age change, body transformation, extra people, duplicated body, deformed hands, lip-sync, talking mouth, dark blue synthetic scene, medical device, hospital, diagnostic display, invented UI, generated text, captions, misspelled logo, altered BIL mark, watermark, floating logo, oversaturated skin, flicker, jump cut, fast zoom, camera shake

## Voice direction

- Adult male voice matching the established calm, intelligent coach personality; warm, assured, not theatrical.
- 145–155 words per minute, short pauses after each proof point.
- Record voice-over separately from the video model. The current LongCat pipeline is image-to-video and is not the authority for BIL voice identity.
- Music: restrained modern pulse at low level; duck at least 8 dB beneath speech. No medical-monitor beeps.
- Captions must be created from the approved script, not automated paraphrases.

## Local edit rules

- Animate screenshots with deterministic pan, crop, masks and perspective only. All UI text and values remain pixel-identical to the source capture.
- Use one visual focus per beat; avoid glass stacks, fake notifications and illegible multi-screen mosaics.
- Keep key text inside mobile store safe areas. Minimum hold on any readable screen: 1.5 seconds.
- The coach reference may introduce the AI Coach, but must not be presented as a real clinician or as a live human.
- Claims stay limited to features proven in current source. “More than 300 workout videos” is the approved public phrasing; do not hard-code a larger count.

## Owner-only final step

After the current app screenshots and script are approved, the owner privately configures `FAL_KEY`. Before a paid render, run the existing live-price preflight, confirm the account-specific duration/cost, authorize exactly one coach-shot request, review identity/rights/brand safety, and only then assemble the local store-safe master. No account password is required by this brief.
