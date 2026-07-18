import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fresh schema enables foreign keys and creates supporting tables',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(foreignKeys.read<int>('foreign_keys'), 1);

      final tables = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((row) => row.read<String>('name')).toSet();
      expect(
        names,
        containsAll(<String>[
          'user_profile',
          'goals',
          'weight_entries',
          'daily_logs',
          'foods',
          'favorites',
          'recent_foods',
          'meals',
          'meal_items',
          'water_entries',
          'preferences',
          'life_context_entries',
          'decision_memories',
          'plan_settings',
          'personal_experiments',
          'challenges',
        ]),
      );

      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final indexNames = indexes.map((row) => row.read<String>('name')).toSet();
      expect(
        indexNames,
        containsAll(<String>[
          'meals_active_day_type_idx',
          'meal_items_active_meal_idx',
          'water_entries_active_day_idx',
          'life_context_active_day_idx',
          'recent_foods_last_used_idx',
          'challenges_active_started_idx',
          'experiments_active_started_idx',
        ]),
      );
    },
  );

  test('version 4 data upgrades in place to version 5', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('PRAGMA user_version = 4');
        raw.execute('''CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT, gender TEXT NOT NULL, age INTEGER NOT NULL,
        height REAL NOT NULL, current_weight REAL NOT NULL, target_weight REAL NOT NULL,
        activity_level TEXT NOT NULL, exercises INTEGER NOT NULL,
        medical_conditions TEXT, waist REAL, neck REAL, chest REAL, arm REAL, thigh REAL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      )''');
        raw.execute('''CREATE TABLE weight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT, date INTEGER NOT NULL,
        weight REAL NOT NULL, note TEXT
      )''');
        raw.execute('''CREATE TABLE daily_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT, date INTEGER NOT NULL, weight REAL,
        calories INTEGER, protein INTEGER, carbs INTEGER, fats INTEGER, water INTEGER,
        notes TEXT
      )''');
        raw.execute('''CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, arabic_name TEXT,
        category TEXT, barcode TEXT, serving_size REAL NOT NULL DEFAULT 100,
        serving_unit TEXT NOT NULL DEFAULT 'g', calories REAL NOT NULL,
        protein REAL NOT NULL, carbs REAL NOT NULL, fats REAL NOT NULL,
        fiber REAL NOT NULL DEFAULT 0, sugar REAL NOT NULL DEFAULT 0,
        potassium REAL NOT NULL DEFAULT 0, sodium REAL NOT NULL DEFAULT 0,
        calcium REAL NOT NULL DEFAULT 0, iron REAL NOT NULL DEFAULT 0,
        magnesium REAL NOT NULL DEFAULT 0, vitamin_c REAL NOT NULL DEFAULT 0,
        verified INTEGER NOT NULL DEFAULT 0
      )''');
        raw.execute('''CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT, date INTEGER NOT NULL,
        name TEXT NOT NULL DEFAULT 'Meal', type TEXT NOT NULL DEFAULT 'other'
      )''');
        raw.execute('''CREATE TABLE meal_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT, meal_id INTEGER NOT NULL,
        food_id INTEGER NOT NULL, quantity REAL NOT NULL DEFAULT 100,
        calories REAL NOT NULL DEFAULT 0, protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0, fats REAL NOT NULL DEFAULT 0
      )''');
        raw.execute('''CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT, food_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      )''');
        raw.execute(
          "INSERT INTO foods (name, calories, protein, carbs, fats) VALUES ('Oats',389,16.9,66.3,6.9)",
        );
        raw.execute(
          "INSERT INTO daily_logs (date, notes) VALUES (1704067200,'preserve me')",
        );
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    final food = await database.select(database.foods).getSingle();
    final log = await database.select(database.dailyLogs).getSingle();
    expect(food.name, 'Oats');
    expect(food.uuid, isNotEmpty);
    expect(log.notes, 'preserve me');
    expect(log.dayKey, '2024-01-01');
    expect(await database.select(database.preferences).get(), isEmpty);
    final weightColumns = await database
        .customSelect('PRAGMA table_info(weight_entries)')
        .get();
    final columnNames = weightColumns
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(columnNames, containsAll(['day_key', 'measurement_context']));
    final mealItemColumns = await database
        .customSelect('PRAGMA table_info(meal_items)')
        .get();
    expect(
      mealItemColumns.map((row) => row.read<String>('name')),
      containsAll(['calcium', 'magnesium', 'sugar']),
    );
  });
}
