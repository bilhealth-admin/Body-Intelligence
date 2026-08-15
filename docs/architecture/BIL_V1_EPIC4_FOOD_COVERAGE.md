# BIL v1 — Epic 4 food coverage

This is the short, current coverage ledger for the 16-Epic release plan.

| Area | Status | Evidence / boundary |
| --- | --- | --- |
| Local search, large downloadable catalogs, offline lookup | Complete | Runtime search authority, mobile catalog repository, signed/hash-checked catalog packs and indexed SQLite search. |
| Quick log, repeat meal, favorites, adaptive recents | Complete | Daily meal entry and repository flows persist locally and require explicit confirmation. |
| Serving and quantity editing | Complete | Validated quantities recalculate deterministic nutrients; serving choices remain explicit. |
| Deletion and history safety | Complete | Soft deletion plus immutable meal nutrition/source/verification/serving snapshots. |
| Macro, mineral and evidence visibility | Complete | Calories, macros, fiber, sodium, potassium, calcium, magnesium and sugar expose unknown values as `—`, not fabricated zeroes. |
| Barcode journey and non-food classification | Complete | Camera/manual scanning uses the runtime authority; tobacco, medicine, supplements and other non-food products are not logged as food. Unknown/degraded results never invent nutrition. |
| Voice entry | Complete on supported devices | Uses the operating-system speech recognizer; permission/unavailable paths remain explicit. |
| Meal-image analysis | Externally activated | Real strict-schema gateway is wired. It is honestly unavailable until `BIL_MEAL_VISION_ENDPOINT`, credentials and provider infrastructure are configured. |
| Arabic/Gulf community catalog expansion | External content operation | The verified seed/download system exists; broader moderated product coverage needs curation, rights and review operations rather than fabricated app data. |
| Physical camera/microphone/provider validation | External release evidence | Requires signed mobile builds, real devices, permissions and production secrets. |

No active Epic 4 route intentionally uses mock nutrition, mock recognition, or automatic unconfirmed meal saving.
