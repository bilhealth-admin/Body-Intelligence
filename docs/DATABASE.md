# Database and migration policy

BIL uses one Drift database as its local source of truth. The current schema
version is 13. Every version increase has an explicit additive migration in
`AppDatabase.migration`; no migration drops user tables or rewrites historical
nutrition. Foreign keys are enabled on every connection.

## Tables

- `user_profile`, `goals`, `plan_settings`
- `weight_entries`, `daily_logs`, `water_entries`
- `foods`, `favorites`, `recent_foods`
- `meals`, `meal_items`
- `life_context_entries`, `decision_memories`
- `personal_experiments`, `challenges`
- `preferences`

User-originated sync candidates use durable UUIDs and appropriate created,
updated, deleted, revision, and sync-status fields. Foreign keys prevent orphan
records and cascade only where ownership is unambiguous. Soft-deleted records
are excluded from active repository queries so future sync can preserve
tombstones without resurrecting deleted data.

Meal-item nutrient snapshots are the nutrition source of truth for historical
logs. A portion is calculated from the selected food and serving quantity when
it is added or edited. Legacy totals in old `daily_logs` schemas are retained
only for compatible upgrades and are not written by current repositories.

Schema v12 adds partial/composite indexes for active daily meals and items,
water, context, recents, experiments, and challenges. Daily meal observation
uses the canonical `day_key` rather than a timestamp-range scan.
Schema v13 adds monotonic revision and sync-status metadata to existing meal
items without changing their UUIDs, quantities, nutrient snapshots, or
tombstones.

## Migration verification

Repository tests use an in-memory native database. Migration tests verify
foreign-key activation, fresh schema tables, and preservation of version-4
profile, food, and daily-log data while upgrading. Before release, test both a
fresh install and an upgrade from a production database copy on every supported
platform. Never edit generated `app_database.g.dart` manually; regenerate it
with:

```sh
dart run build_runner build
```
