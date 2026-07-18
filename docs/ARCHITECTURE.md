# Architecture

BIL uses a practical feature-first Flutter structure:

- `lib/app`: router, localization, environment, persisted app settings, themes.
- `lib/data/database`: Drift schema, explicit migrations, seed catalog.
- `lib/data/repositories`: local persistence operations and reactive queries.
- `lib/engine`: pure Dart health calculations and explainable intelligence.
- `lib/features`: Riverpod providers and screens grouped by user capability.
- `lib/shared`: reusable presentation components.

Drift/SQLite is the only active source of truth. Meal-item nutrient snapshots
produce daily nutrition totals, and individual water entries produce hydration
totals. Legacy daily total columns are retained only so schema-v4 databases can
upgrade without losing data; current repositories do not write them.

User-originated records carry UUIDs, timestamps, revisions, tombstones where
useful, and a sync-status marker. These fields prepare a later synchronization
boundary without pretending that cloud sync exists today.

The engine imports no Flutter, Riverpod, Drift, or Supabase packages. Insights
are deterministic objects containing explanation, evidence, suggested action,
priority, and confidence. Plateau and possible water-retention indications are
gated by data sufficiency and are never diagnoses.

Supabase is disabled by default. Missing credentials leave the complete local
experience available and cloud controls visibly disabled.
