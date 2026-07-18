import 'package:drift/drift.dart';

import 'daily_logs.dart';
import 'decision_memories.dart';
import 'database_ids.dart';
import 'favorites.dart';
import 'foods.dart';
import 'goals.dart';
import 'meal_items.dart';
import 'meals.dart';
import 'life_context_entries.dart';
import 'preferences.dart';
import 'recent_foods.dart';
import 'user_profile.dart';
import 'water_entries.dart';
import 'weight_entries.dart';
import 'connection/database_connection.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    DailyLogs,
    UserProfile,
    WeightEntries,
    Foods,
    Meals,
    MealItems,
    Favorites,
    RecentFoods,
    Goals,
    WaterEntries,
    Preferences,
    LifeContextEntries,
    DecisionMemories,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDatabaseConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
      await _createWeightDayIndex();
      await _createV7Indexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(userProfile);
      }

      if (from < 3) {
        await migrator.createTable(weightEntries);
      }

      if (from < 4) {
        await migrator.createTable(foods);
        await migrator.createTable(meals);
        await migrator.createTable(mealItems);
        await migrator.createTable(favorites);
      }

      if (from < 5) {
        await _upgradeToV5(migrator);
      }
      if (from < 6) {
        await _upgradeToV6();
      }
      if (from < 7) {
        await migrator.createTable(lifeContextEntries);
        await migrator.createTable(decisionMemories);
        await _createV7Indexes();
      }
      if (from < 8) {
        await _addColumns('meal_items', <String>[
          'calcium REAL NOT NULL DEFAULT 0',
          'magnesium REAL NOT NULL DEFAULT 0',
          'sugar REAL NOT NULL DEFAULT 0',
        ]);
      }
    },
  );

  Future<void> _upgradeToV5(Migrator migrator) async {
    await migrator.createTable(goals);
    await migrator.createTable(recentFoods);
    await migrator.createTable(waterEntries);
    await migrator.createTable(preferences);

    await _addColumns('user_profile', <String>[
      'uuid TEXT',
      'updated_at INTEGER',
      'deleted_at INTEGER',
      'revision INTEGER NOT NULL DEFAULT 1',
      "sync_status TEXT NOT NULL DEFAULT 'local'",
    ]);
    await _addColumns('weight_entries', <String>[
      'uuid TEXT',
      'created_at INTEGER',
      'updated_at INTEGER',
      'deleted_at INTEGER',
      'revision INTEGER NOT NULL DEFAULT 1',
      "sync_status TEXT NOT NULL DEFAULT 'local'",
    ]);
    await _addColumns('daily_logs', <String>[
      'uuid TEXT',
      'day_key TEXT',
      'sleep_hours REAL',
      'steps INTEGER',
      'exercise_notes TEXT',
      'created_at INTEGER',
      'updated_at INTEGER',
    ]);
    await _addColumns('foods', <String>[
      'uuid TEXT',
      "keywords TEXT NOT NULL DEFAULT ''",
      'is_custom INTEGER NOT NULL DEFAULT 0',
      "source TEXT NOT NULL DEFAULT 'local'",
      'created_at INTEGER',
      'updated_at INTEGER',
      'deleted_at INTEGER',
      'revision INTEGER NOT NULL DEFAULT 1',
      "sync_status TEXT NOT NULL DEFAULT 'local'",
    ]);
    await _addColumns('meals', <String>[
      'uuid TEXT',
      'day_key TEXT',
      'created_at INTEGER',
      'updated_at INTEGER',
      'deleted_at INTEGER',
      'revision INTEGER NOT NULL DEFAULT 1',
      "sync_status TEXT NOT NULL DEFAULT 'local'",
    ]);
    await _addColumns('meal_items', <String>[
      'uuid TEXT',
      'fiber REAL NOT NULL DEFAULT 0',
      'sodium REAL NOT NULL DEFAULT 0',
      'potassium REAL NOT NULL DEFAULT 0',
      'created_at INTEGER',
      'updated_at INTEGER',
      'deleted_at INTEGER',
    ]);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final table in <String>[
      'user_profile',
      'weight_entries',
      'daily_logs',
      'foods',
      'meals',
      'meal_items',
    ]) {
      await customStatement(
        "UPDATE $table SET uuid = lower(hex(randomblob(4))) || '-' || "
        "lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || "
        "'-a' || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))) "
        'WHERE uuid IS NULL',
      );
    }
    await customStatement(
      'UPDATE user_profile SET updated_at = COALESCE(updated_at, created_at, $now)',
    );
    for (final table in <String>[
      'weight_entries',
      'foods',
      'meals',
      'meal_items',
    ]) {
      await customStatement(
        'UPDATE $table SET created_at = COALESCE(created_at, $now), '
        'updated_at = COALESCE(updated_at, $now)',
      );
    }
    await customStatement(
      "UPDATE daily_logs SET day_key = printf('%04d-%02d-%02d', "
      "CAST(strftime('%Y', date, 'unixepoch') AS INTEGER), "
      "CAST(strftime('%m', date, 'unixepoch') AS INTEGER), "
      "CAST(strftime('%d', date, 'unixepoch') AS INTEGER)), "
      'created_at = COALESCE(created_at, $now), updated_at = COALESCE(updated_at, $now)',
    );
    await customStatement(
      "UPDATE meals SET day_key = printf('%04d-%02d-%02d', "
      "CAST(strftime('%Y', date, 'unixepoch') AS INTEGER), "
      "CAST(strftime('%m', date, 'unixepoch') AS INTEGER), "
      "CAST(strftime('%d', date, 'unixepoch') AS INTEGER))",
    );
    await customStatement('''
      UPDATE daily_logs AS current SET
        weight = COALESCE(weight, (SELECT weight FROM daily_logs AS candidate
          WHERE candidate.day_key = current.day_key AND candidate.weight IS NOT NULL
          ORDER BY candidate.id DESC LIMIT 1)),
        calories = COALESCE(calories, (SELECT calories FROM daily_logs AS candidate
          WHERE candidate.day_key = current.day_key AND candidate.calories IS NOT NULL
          ORDER BY candidate.id DESC LIMIT 1)),
        protein = COALESCE(protein, (SELECT protein FROM daily_logs AS candidate
          WHERE candidate.day_key = current.day_key AND candidate.protein IS NOT NULL
          ORDER BY candidate.id DESC LIMIT 1)),
        carbs = COALESCE(carbs, (SELECT carbs FROM daily_logs AS candidate
          WHERE candidate.day_key = current.day_key AND candidate.carbs IS NOT NULL
          ORDER BY candidate.id DESC LIMIT 1)),
        fats = COALESCE(fats, (SELECT fats FROM daily_logs AS candidate
          WHERE candidate.day_key = current.day_key AND candidate.fats IS NOT NULL
          ORDER BY candidate.id DESC LIMIT 1)),
        water = COALESCE(water, (SELECT water FROM daily_logs AS candidate
          WHERE candidate.day_key = current.day_key AND candidate.water IS NOT NULL
          ORDER BY candidate.id DESC LIMIT 1)),
        notes = COALESCE(notes, (SELECT notes FROM daily_logs AS candidate
          WHERE candidate.day_key = current.day_key AND candidate.notes IS NOT NULL
          ORDER BY candidate.id DESC LIMIT 1))
      WHERE id IN (SELECT MAX(id) FROM daily_logs GROUP BY day_key)
    ''');
    await customStatement('''
      DELETE FROM daily_logs
      WHERE id NOT IN (SELECT MAX(id) FROM daily_logs GROUP BY day_key)
    ''');
    await customStatement('''
      DELETE FROM favorites
      WHERE id NOT IN (SELECT MIN(id) FROM favorites GROUP BY food_id)
    ''');
    await customStatement('''
      INSERT INTO water_entries
        (uuid, occurred_at, day_key, amount_ml, created_at, updated_at, revision, sync_status)
      SELECT lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' ||
        substr(lower(hex(randomblob(2))), 2) || '-a' ||
        substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))),
        date, day_key, water, created_at, updated_at, 1, 'local'
      FROM daily_logs WHERE water IS NOT NULL AND water > 0
    ''');
    await _createIndexes();
  }

  Future<void> _addColumns(String table, List<String> definitions) async {
    for (final definition in definitions) {
      await customStatement('ALTER TABLE $table ADD COLUMN $definition');
    }
  }

  Future<void> _upgradeToV6() async {
    await _addColumns('weight_entries', <String>[
      'day_key TEXT',
      "measurement_context TEXT NOT NULL DEFAULT 'differentConditions'",
    ]);
    await customStatement('''
      UPDATE weight_entries SET day_key = printf('%04d-%02d-%02d',
        CAST(strftime('%Y', date, 'unixepoch', 'localtime') AS INTEGER),
        CAST(strftime('%m', date, 'unixepoch', 'localtime') AS INTEGER),
        CAST(strftime('%d', date, 'unixepoch', 'localtime') AS INTEGER))
      WHERE day_key IS NULL
    ''');
    await customStatement('''
      UPDATE weight_entries SET deleted_at = COALESCE(deleted_at, updated_at, created_at)
      WHERE deleted_at IS NULL AND id NOT IN (
        SELECT MAX(id) FROM weight_entries WHERE deleted_at IS NULL GROUP BY day_key
      )
    ''');
    await _createIndexes();
    await _createWeightDayIndex();
  }

  Future<void> _createIndexes() async {
    const statements = <String>[
      'CREATE UNIQUE INDEX IF NOT EXISTS user_profile_uuid_uq ON user_profile(uuid)',
      'CREATE UNIQUE INDEX IF NOT EXISTS weight_entries_uuid_uq ON weight_entries(uuid)',
      'CREATE INDEX IF NOT EXISTS weight_entries_date_idx ON weight_entries(date)',
      'CREATE UNIQUE INDEX IF NOT EXISTS daily_logs_day_key_uq ON daily_logs(day_key)',
      'CREATE UNIQUE INDEX IF NOT EXISTS foods_uuid_uq ON foods(uuid)',
      'CREATE INDEX IF NOT EXISTS foods_name_idx ON foods(name)',
      'CREATE INDEX IF NOT EXISTS foods_arabic_name_idx ON foods(arabic_name)',
      'CREATE INDEX IF NOT EXISTS foods_barcode_idx ON foods(barcode)',
      'CREATE UNIQUE INDEX IF NOT EXISTS favorites_food_id_uq ON favorites(food_id)',
      'CREATE INDEX IF NOT EXISTS meals_day_key_idx ON meals(day_key)',
      'CREATE INDEX IF NOT EXISTS meal_items_meal_id_idx ON meal_items(meal_id)',
      'CREATE INDEX IF NOT EXISTS water_entries_day_key_idx ON water_entries(day_key)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> _createWeightDayIndex() => customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS weight_entries_active_day_uq '
    'ON weight_entries(day_key) '
    'WHERE deleted_at IS NULL AND day_key IS NOT NULL',
  );

  Future<void> _createV7Indexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS life_context_day_idx '
      'ON life_context_entries(day_key)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS decision_memory_day_idx '
      'ON decision_memories(day_key)',
    );
  }
}
