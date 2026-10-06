import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'schema 16 preserves decisions and adds an empty transition store',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
            CREATE TABLE weight_entries (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
            )
          ''');
            raw.execute('''
            CREATE TABLE foods (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              source TEXT NOT NULL DEFAULT 'local',
              verified INTEGER NOT NULL DEFAULT 0,
              serving_size REAL NOT NULL DEFAULT 100,
              serving_unit TEXT NOT NULL DEFAULT 'g'
            )
          ''');
            raw.execute('''
            CREATE TABLE meal_items (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              food_id INTEGER NULL
            )
          ''');
            raw.execute(
              "INSERT INTO foods "
              "(id, source, verified, serving_size, serving_unit) "
              "VALUES (7, 'usda', 1, 30, 'g')",
            );
            raw.execute("INSERT INTO meal_items (id, food_id) VALUES (11, 7)");
            raw.execute('''
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
              outcome TEXT NULL,
              helpfulness INTEGER NULL,
              surfaced_at INTEGER NOT NULL,
              responded_at INTEGER NULL,
              evaluated_at INTEGER NULL,
              deleted_at INTEGER NULL,
              revision INTEGER NOT NULL DEFAULT 1,
              sync_status TEXT NOT NULL DEFAULT 'local',
              UNIQUE(day_key, recommendation_key)
            )
          ''');
            raw.execute(
              "INSERT INTO decision_memories "
              "(uuid, day_key, recommendation_key, title, reason, outcome, surfaced_at) "
              "VALUES ('legacy-decision', '2026-07-30', 'hydrate', "
              "'Hydrate', 'Local evidence', 'helped', 1785405600)",
            );
            raw.execute('PRAGMA user_version = 16');
          },
        ),
      );
      addTearDown(database.close);

      expect(database.schemaVersion, 22);
      final decision = await database
          .select(database.decisionMemories)
          .getSingle();
      expect(decision.uuid, 'legacy-decision');
      expect(decision.outcome, 'helped');
      expect(
        await database.select(database.decisionOutcomeTransitions).get(),
        isEmpty,
      );

      final migratedMealItem = await database.customSelect('''
            SELECT
              food_source_snapshot,
              food_verified_snapshot,
              serving_size_snapshot,
              serving_unit_snapshot,
              food_evidence_json
            FROM meal_items
            WHERE id = 11
            ''').getSingle();
      expect(migratedMealItem.read<String>('food_source_snapshot'), 'usda');
      expect(migratedMealItem.read<int>('food_verified_snapshot'), 1);
      expect(migratedMealItem.read<double>('serving_size_snapshot'), 30);
      expect(migratedMealItem.read<String>('serving_unit_snapshot'), 'g');
      expect(
        migratedMealItem.readNullable<String>('food_evidence_json'),
        isNull,
      );
      final migratedFood = await database
          .customSelect('SELECT food_evidence_json FROM foods WHERE id = 7')
          .getSingle();
      expect(migratedFood.readNullable<String>('food_evidence_json'), isNull);

      final foreignKeys = await database
          .customSelect('PRAGMA foreign_key_check')
          .get();
      expect(foreignKeys, isEmpty);
      final integrity = await database
          .customSelect('PRAGMA integrity_check')
          .get();
      expect(integrity.single.read<String>('integrity_check'), 'ok');
      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        contains('decision_outcome_transitions_memory_time_idx'),
      );
    },
  );
}
