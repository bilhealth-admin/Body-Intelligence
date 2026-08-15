# Add Exercise / Workouts read-only inventory

No product source, Dashboard, Profile, or video file was changed during this inventory.

## Canonical routes

- `/wellness/workouts` — workout entry chooser.
- `/wellness/workouts/log?category=Cardio` — measured Cardio manual logger.
- `/wellness/workouts/log?category=Strength` — measured Strength manual logger.
- `/wellness/workouts/routines` — BIL workout routines catalog.

The chooser is implemented in `lib/features/wellness/presentation/workout_entry_chooser_page.dart` and exposes Cardio, Strength, and Workout Routines as separate actions. Router registration is in `lib/app/router/app_router.dart`.

## Preserved assets and licensing gates

- Existing BIL workout covers are referenced from `assets/images/workouts/`, including strength, cardio, mobility, HIIT, kettlebell, and recovery covers.
- Routine media is resolved through the existing verified content-pack pipeline; paid packs require declared paid distribution rights.
- Release workout packs enforce category/item/media deduplication and verified metadata in `wellness_content_pack_manager.dart`.
- No video was generated, copied, removed, renamed, or modified.

## Next implementation QA cohort

Use the existing chooser and canonical routes. Verify Cardio and Strength logging separately from the routines catalog; preserve BIL branding and only link already licensed/verified assets.
