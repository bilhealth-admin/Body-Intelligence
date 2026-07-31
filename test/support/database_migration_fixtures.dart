import 'package:sqlite3/sqlite3.dart';

/// A historical database snapshot used to prove that an in-place Drift
/// migration preserves user-owned data.
final class DatabaseMigrationFixture {
  const DatabaseMigrationFixture({
    required this.schemaVersion,
    required this.install,
  });

  final int schemaVersion;
  final void Function(Database database) install;
}

final DatabaseMigrationFixture schemaV12Fixture = DatabaseMigrationFixture(
  schemaVersion: 12,
  install: (database) {
    _createSchemaV12(database);
    _seedHistoricalData(database);
    database.execute('PRAGMA user_version = 12');
  },
);

final DatabaseMigrationFixture schemaV15Fixture = DatabaseMigrationFixture(
  schemaVersion: 15,
  install: (database) {
    _createSchemaV12(database);
    _seedHistoricalData(database);
    _upgradeFixtureToV15(database);
    database.execute('PRAGMA user_version = 15');
  },
);

void _createSchemaV12(Database database) {
  for (final statement in _schemaV12Statements) {
    database.execute(statement);
  }
}

void _upgradeFixtureToV15(Database database) {
  for (final statement in _v13ToV15Statements) {
    database.execute(statement);
  }
}

void _seedHistoricalData(Database database) {
  for (final statement in _historicalSeedStatements) {
    database.execute(statement);
  }
}

const _schemaV12Statements = <String>[
  '''
  CREATE TABLE user_profile (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    gender TEXT NOT NULL,
    age INTEGER NOT NULL,
    height REAL NOT NULL,
    current_weight REAL NOT NULL,
    target_weight REAL NOT NULL,
    activity_level TEXT NOT NULL,
    exercises INTEGER NOT NULL,
    medical_conditions TEXT,
    waist REAL,
    neck REAL,
    chest REAL,
    arm REAL,
    thigh REAL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE weight_entries (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    date INTEGER NOT NULL,
    day_key TEXT,
    weight REAL NOT NULL,
    note TEXT,
    measurement_context TEXT NOT NULL DEFAULT 'differentConditions',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE daily_logs (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    date INTEGER NOT NULL,
    day_key TEXT NOT NULL UNIQUE,
    weight REAL,
    calories INTEGER,
    protein INTEGER,
    carbs INTEGER,
    fats INTEGER,
    water INTEGER,
    notes TEXT,
    sleep_hours REAL,
    steps INTEGER,
    exercise_notes TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE foods (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    arabic_name TEXT,
    category TEXT,
    keywords TEXT NOT NULL DEFAULT '',
    barcode TEXT,
    serving_size REAL NOT NULL DEFAULT 100,
    serving_unit TEXT NOT NULL DEFAULT 'g',
    calories REAL NOT NULL,
    protein REAL NOT NULL,
    carbs REAL NOT NULL,
    fats REAL NOT NULL,
    fiber REAL NOT NULL DEFAULT 0,
    sugar REAL NOT NULL DEFAULT 0,
    potassium REAL NOT NULL DEFAULT 0,
    sodium REAL NOT NULL DEFAULT 0,
    calcium REAL NOT NULL DEFAULT 0,
    iron REAL NOT NULL DEFAULT 0,
    magnesium REAL NOT NULL DEFAULT 0,
    vitamin_c REAL NOT NULL DEFAULT 0,
    verified INTEGER NOT NULL DEFAULT 0,
    is_custom INTEGER NOT NULL DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'local',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE meals (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    date INTEGER NOT NULL,
    day_key TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT 'Meal',
    type TEXT NOT NULL DEFAULT 'other',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE meal_items (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    meal_id INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
    food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE RESTRICT,
    quantity REAL NOT NULL DEFAULT 100,
    calories REAL NOT NULL DEFAULT 0,
    protein REAL NOT NULL DEFAULT 0,
    carbs REAL NOT NULL DEFAULT 0,
    fats REAL NOT NULL DEFAULT 0,
    fiber REAL NOT NULL DEFAULT 0,
    sodium REAL NOT NULL DEFAULT 0,
    potassium REAL NOT NULL DEFAULT 0,
    calcium REAL NOT NULL DEFAULT 0,
    magnesium REAL NOT NULL DEFAULT 0,
    sugar REAL NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
  )
  ''',
  '''
  CREATE TABLE favorites (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    food_id INTEGER NOT NULL UNIQUE
      REFERENCES foods(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE recent_foods (
    food_id INTEGER NOT NULL PRIMARY KEY
      REFERENCES foods(id) ON DELETE CASCADE,
    last_used_at INTEGER NOT NULL,
    use_count INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE goals (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    profile_uuid TEXT NOT NULL
      REFERENCES user_profile(uuid) ON DELETE CASCADE,
    type TEXT NOT NULL,
    target_weight REAL NOT NULL,
    target_date INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE water_entries (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    occurred_at INTEGER NOT NULL,
    day_key TEXT NOT NULL,
    amount_ml INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE preferences (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE life_context_entries (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    occurred_at INTEGER NOT NULL,
    day_key TEXT NOT NULL,
    type TEXT NOT NULL,
    details TEXT,
    use_in_insights INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE decision_memories (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    day_key TEXT NOT NULL,
    recommendation_key TEXT NOT NULL,
    title TEXT NOT NULL,
    reason TEXT NOT NULL,
    evidence_json TEXT NOT NULL DEFAULT '[]',
    confidence TEXT NOT NULL DEFAULT 'low',
    response TEXT NOT NULL DEFAULT 'pending',
    outcome TEXT,
    helpfulness INTEGER,
    surfaced_at INTEGER NOT NULL,
    responded_at INTEGER,
    evaluated_at INTEGER,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local',
    UNIQUE(day_key, recommendation_key)
  )
  ''',
  '''
  CREATE TABLE plan_settings (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    profile_uuid TEXT NOT NULL UNIQUE
      REFERENCES user_profile(uuid) ON DELETE CASCADE,
    recommended_calories INTEGER NOT NULL,
    recommended_protein INTEGER NOT NULL,
    recommended_carbs INTEGER NOT NULL,
    recommended_fats INTEGER NOT NULL,
    recommended_fiber INTEGER NOT NULL,
    recommended_water INTEGER NOT NULL,
    override_calories INTEGER,
    override_protein INTEGER,
    override_carbs INTEGER,
    override_fats INTEGER,
    override_fiber INTEGER,
    override_water INTEGER,
    assumptions_version TEXT NOT NULL DEFAULT 'deterministic-v1',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE personal_experiments (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    hypothesis TEXT NOT NULL,
    changed_variable TEXT NOT NULL,
    controlled_factors TEXT NOT NULL DEFAULT '',
    required_data TEXT NOT NULL DEFAULT '',
    started_at INTEGER NOT NULL,
    ends_at INTEGER NOT NULL,
    adherence REAL,
    result TEXT,
    confidence TEXT NOT NULL DEFAULT 'insufficient',
    limitations TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'active',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  '''
  CREATE TABLE challenges (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    audience TEXT NOT NULL DEFAULT 'private',
    target_days INTEGER NOT NULL,
    started_at INTEGER NOT NULL,
    ends_at INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    completed_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
  ''',
  'CREATE UNIQUE INDEX user_profile_uuid_uq ON user_profile(uuid)',
  'CREATE UNIQUE INDEX weight_entries_uuid_uq ON weight_entries(uuid)',
  'CREATE INDEX weight_entries_date_idx ON weight_entries(date)',
  'CREATE UNIQUE INDEX daily_logs_day_key_uq ON daily_logs(day_key)',
  'CREATE UNIQUE INDEX foods_uuid_uq ON foods(uuid)',
  'CREATE INDEX foods_name_idx ON foods(name)',
  'CREATE INDEX foods_arabic_name_idx ON foods(arabic_name)',
  'CREATE INDEX foods_barcode_idx ON foods(barcode)',
  'CREATE UNIQUE INDEX favorites_food_id_uq ON favorites(food_id)',
  'CREATE INDEX meals_day_key_idx ON meals(day_key)',
  'CREATE INDEX meal_items_meal_id_idx ON meal_items(meal_id)',
  'CREATE INDEX water_entries_day_key_idx ON water_entries(day_key)',
  '''
  CREATE UNIQUE INDEX weight_entries_active_day_uq
  ON weight_entries(day_key)
  WHERE deleted_at IS NULL AND day_key IS NOT NULL
  ''',
  'CREATE INDEX life_context_day_idx ON life_context_entries(day_key)',
  'CREATE INDEX decision_memory_day_idx ON decision_memories(day_key)',
  '''
  CREATE INDEX meals_active_day_type_idx
  ON meals(day_key, type) WHERE deleted_at IS NULL
  ''',
  '''
  CREATE INDEX meal_items_active_meal_idx
  ON meal_items(meal_id) WHERE deleted_at IS NULL
  ''',
  '''
  CREATE INDEX water_entries_active_day_idx
  ON water_entries(day_key) WHERE deleted_at IS NULL
  ''',
  '''
  CREATE INDEX life_context_active_day_idx
  ON life_context_entries(day_key) WHERE deleted_at IS NULL
  ''',
  '''
  CREATE INDEX recent_foods_last_used_idx
  ON recent_foods(last_used_at DESC)
  ''',
  '''
  CREATE INDEX challenges_active_started_idx
  ON challenges(started_at DESC) WHERE deleted_at IS NULL
  ''',
  '''
  CREATE INDEX experiments_active_started_idx
  ON personal_experiments(started_at DESC) WHERE deleted_at IS NULL
  ''',
];

const _v13ToV15Statements = <String>[
  'ALTER TABLE meal_items ADD COLUMN revision INTEGER NOT NULL DEFAULT 1',
  '''
  ALTER TABLE meal_items
  ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'local'
  ''',
  'ALTER TABLE meal_items ADD COLUMN position INTEGER NOT NULL DEFAULT 0',
  'UPDATE meal_items SET position = id',
  '''
  ALTER TABLE foods
  ADD COLUMN nutrient_evidence_mask INTEGER NOT NULL DEFAULT 0
  ''',
  '''
  ALTER TABLE meal_items
  ADD COLUMN nutrient_evidence_mask INTEGER NOT NULL DEFAULT 0
  ''',
  '''
  UPDATE foods SET nutrient_evidence_mask =
    (CASE WHEN fiber != 0 THEN 1 ELSE 0 END) |
    (CASE WHEN sodium != 0 THEN 2 ELSE 0 END) |
    (CASE WHEN potassium != 0 THEN 4 ELSE 0 END) |
    (CASE WHEN calcium != 0 THEN 8 ELSE 0 END) |
    (CASE WHEN magnesium != 0 THEN 16 ELSE 0 END) |
    (CASE WHEN sugar != 0 THEN 32 ELSE 0 END)
  ''',
  '''
  UPDATE meal_items SET nutrient_evidence_mask =
    (CASE WHEN fiber != 0 THEN 1 ELSE 0 END) |
    (CASE WHEN sodium != 0 THEN 2 ELSE 0 END) |
    (CASE WHEN potassium != 0 THEN 4 ELSE 0 END) |
    (CASE WHEN calcium != 0 THEN 8 ELSE 0 END) |
    (CASE WHEN magnesium != 0 THEN 16 ELSE 0 END) |
    (CASE WHEN sugar != 0 THEN 32 ELSE 0 END)
  ''',
];

const _historicalSeedStatements = <String>[
  '''
  INSERT INTO user_profile (
    id, uuid, gender, age, height, current_weight, target_weight,
    activity_level, exercises, medical_conditions, waist, neck,
    created_at, updated_at, revision, sync_status
  ) VALUES (
    1, 'profile-fixture-0001', 'male', 36, 181, 93.4, 85,
    'moderate', 1, 'fixture-condition', 102, 42.5,
    1704067200, 1704067200, 3, 'local'
  )
  ''',
  '''
  INSERT INTO weight_entries (
    id, uuid, date, day_key, weight, note, measurement_context,
    created_at, updated_at, revision, sync_status
  ) VALUES (
    1, 'weight-fixture-0001', 1704067200, '2024-01-01', 93.4,
    'preserve weight', 'morningFasted', 1704067200, 1704067200, 2, 'local'
  )
  ''',
  '''
  INSERT INTO daily_logs (
    id, uuid, date, day_key, weight, calories, protein, carbs, fats,
    water, notes, sleep_hours, steps, exercise_notes, created_at, updated_at
  ) VALUES (
    1, 'log-fixture-0001', 1704067200, '2024-01-01', 93.4,
    1800, 150, 120, 70, 2300, 'preserve daily log', 7.5, 8500,
    'preserve exercise', 1704067200, 1704067200
  )
  ''',
  '''
  INSERT INTO foods (
    id, uuid, name, arabic_name, category, keywords, barcode,
    serving_size, serving_unit, calories, protein, carbs, fats,
    fiber, sugar, potassium, sodium, calcium, iron, magnesium, vitamin_c,
    verified, is_custom, source, created_at, updated_at, revision, sync_status
  ) VALUES (
    1, 'food-fixture-0001', 'Fixture oats', 'شوفان الاختبار',
    'grains', 'oats fixture', 'fixture-barcode', 100, 'g',
    389, 16.9, 66.3, 6.9, 8.4, 1.2, 429, 2, 54, 4.7, 177, 0,
    1, 1, 'user', 1704067200, 1704067200, 4, 'local'
  )
  ''',
  '''
  INSERT INTO meals (
    id, uuid, date, day_key, name, type, created_at, updated_at,
    revision, sync_status
  ) VALUES (
    1, 'meal-fixture-0001', 1704067200, '2024-01-01', 'Breakfast',
    'breakfast', 1704067200, 1704067200, 2, 'local'
  )
  ''',
  '''
  INSERT INTO meal_items (
    id, uuid, meal_id, food_id, quantity, calories, protein, carbs, fats,
    fiber, sodium, potassium, calcium, magnesium, sugar, created_at, updated_at
  ) VALUES (
    1, 'item-fixture-0001', 1, 1, 50, 194.5, 8.45, 33.15, 3.45,
    4.2, 1, 214.5, 27, 88.5, 0.6, 1704067200, 1704067200
  )
  ''',
  '''
  INSERT INTO favorites (id, food_id, created_at)
  VALUES (1, 1, 1704067200)
  ''',
  '''
  INSERT INTO recent_foods (food_id, last_used_at, use_count)
  VALUES (1, 1704067200, 7)
  ''',
  '''
  INSERT INTO goals (
    id, uuid, profile_uuid, type, target_weight, target_date,
    created_at, updated_at, revision, sync_status
  ) VALUES (
    1, 'goal-fixture-0001', 'profile-fixture-0001', 'weight', 85,
    1735689600, 1704067200, 1704067200, 2, 'local'
  )
  ''',
  '''
  INSERT INTO water_entries (
    id, uuid, occurred_at, day_key, amount_ml, created_at, updated_at,
    revision, sync_status
  ) VALUES (
    1, 'water-fixture-0001', 1704067200, '2024-01-01', 500,
    1704067200, 1704067200, 2, 'local'
  )
  ''',
  '''
  INSERT INTO preferences (key, value, updated_at)
  VALUES ('locale', 'ar', 1704067200)
  ''',
  '''
  INSERT INTO life_context_entries (
    id, uuid, occurred_at, day_key, type, details, use_in_insights,
    created_at, updated_at, revision, sync_status
  ) VALUES (
    1, 'context-fixture-0001', 1704067200, '2024-01-01', 'sleep',
    'preserve context', 1, 1704067200, 1704067200, 2, 'local'
  )
  ''',
  '''
  INSERT INTO decision_memories (
    id, uuid, day_key, recommendation_key, title, reason, evidence_json,
    confidence, response, outcome, helpfulness, surfaced_at, responded_at,
    evaluated_at, revision, sync_status
  ) VALUES (
    1, 'decision-fixture-0001', '2024-01-01', 'hydrate',
    'Hydrate', 'preserve reason', '["water"]', 'high', 'accepted',
    'helped', 5, 1704067200, 1704067300, 1704153600, 2, 'local'
  )
  ''',
  '''
  INSERT INTO plan_settings (
    id, uuid, profile_uuid, recommended_calories, recommended_protein,
    recommended_carbs, recommended_fats, recommended_fiber,
    recommended_water, assumptions_version, created_at, updated_at,
    revision, sync_status
  ) VALUES (
    1, 'plan-fixture-0001', 'profile-fixture-0001', 2100, 160, 180,
    70, 30, 3000, 'fixture-v1', 1704067200, 1704067200, 2, 'local'
  )
  ''',
  '''
  INSERT INTO personal_experiments (
    id, uuid, hypothesis, changed_variable, controlled_factors, required_data,
    started_at, ends_at, adherence, result, confidence, limitations, status,
    created_at, updated_at, revision, sync_status
  ) VALUES (
    1, 'experiment-fixture-0001', 'Earlier sleep helps', 'bedtime',
    'calories', 'sleep,weight', 1704067200, 1704672000, 0.8,
    'preserve result', 'medium', 'fixture', 'completed',
    1704067200, 1704067200, 2, 'local'
  )
  ''',
  '''
  INSERT INTO challenges (
    id, uuid, type, title, audience, target_days, started_at, ends_at,
    status, completed_at, created_at, updated_at, revision, sync_status
  ) VALUES (
    1, 'challenge-fixture-0001', 'hydration', 'Hydration fixture',
    'private', 7, 1704067200, 1704672000, 'completed', 1704672000,
    1704067200, 1704067200, 2, 'local'
  )
  ''',
];
