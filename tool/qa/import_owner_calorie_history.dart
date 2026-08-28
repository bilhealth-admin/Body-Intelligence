import 'dart:io';

import 'package:body_intelligence_log/data/database/database_ids.dart';
import 'package:sqlite3/sqlite3.dart';

const _foodSource = 'user-history-import-v1';
const _mealName = 'Imported daily total';
const _foodName = 'Recorded daily calories';
const _calorieEvidenceMask = 1 << 7;

void main(List<String> arguments) {
  final databasePath = _argument(arguments, '--database');
  final inputPath = _argument(arguments, '--input');
  final apply = arguments.contains('--apply');
  if (databasePath == null || inputPath == null) {
    stderr.writeln(
      'Usage: dart run tool/qa/import_owner_calorie_history.dart '
      '--database <sqlite> --input <tsv> [--apply]',
    );
    exitCode = 64;
    return;
  }

  final entries = _parse(File(inputPath).readAsLinesSync());
  final database = sqlite3.open(databasePath);
  try {
    final quickCheck = database.select('pragma quick_check').first.values.first;
    if (quickCheck != 'ok') {
      throw StateError('SQLite quick_check failed: $quickCheck');
    }
    _requireColumns(database, 'foods', {
      'id',
      'uuid',
      'name',
      'calories',
      'protein',
      'carbs',
      'fats',
      'nutrient_evidence_mask',
      'source',
      'sync_status',
    });
    _requireColumns(database, 'meals', {
      'id',
      'uuid',
      'date',
      'day_key',
      'name',
      'type',
      'revision',
      'sync_status',
    });
    _requireColumns(database, 'meal_items', {
      'uuid',
      'meal_id',
      'food_id',
      'calories',
      'protein',
      'carbs',
      'fats',
      'nutrient_evidence_mask',
      'revision',
      'sync_status',
    });

    final existingMeals = database.select(
      'select count(*) as count from meals '
      'where name = ? and deleted_at is null',
      [_mealName],
    ).single['count'];
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.calories);
    stdout.writeln(
      'Validated ${entries.length} calorie-only days; '
      'range ${entries.first.dayKey} ${entries.first.calories} kcal -> '
      '${entries.last.dayKey} ${entries.last.calories} kcal; '
      'mean ${(total / entries.length).toStringAsFixed(1)} kcal; '
      'existing imported days: $existingMeals.',
    );
    if (!apply) {
      stdout.writeln('Dry run only. Re-run with --apply to mutate the copy.');
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    var inserted = 0;
    var updated = 0;
    database.execute('begin immediate');
    try {
      final foodId = _ensureHistoricalFood(database, now);
      for (final entry in entries) {
        final measuredAt =
            DateTime.utc(
              entry.date.year,
              entry.date.month,
              entry.date.day,
              12,
            ).millisecondsSinceEpoch ~/
            1000;
        final matches = database.select(
          'select m.id as meal_id, m.revision as meal_revision, '
          'i.id as item_id, i.revision as item_revision '
          'from meals m left join meal_items i on i.meal_id = m.id '
          'and i.deleted_at is null '
          'where m.day_key = ? and m.name = ? and m.deleted_at is null',
          [entry.dayKey, _mealName],
        );
        if (matches.length > 1) {
          throw StateError('Duplicate imported meals for ${entry.dayKey}.');
        }
        if (matches.isEmpty) {
          database.execute(
            'insert into meals('
            'uuid,date,day_key,name,type,created_at,updated_at,revision,sync_status'
            ') values(?,?,?,?,?,?,?,?,?)',
            [
              newDatabaseId(),
              measuredAt,
              entry.dayKey,
              _mealName,
              'snack',
              measuredAt,
              now,
              1,
              'local',
            ],
          );
          final mealId = database.lastInsertRowId;
          _insertItem(
            database,
            mealId,
            foodId,
            entry.calories,
            measuredAt,
            now,
          );
          inserted++;
          continue;
        }
        final row = matches.single;
        final itemId = row['item_id'];
        if (itemId == null) {
          _insertItem(
            database,
            row['meal_id'] as int,
            foodId,
            entry.calories,
            measuredAt,
            now,
          );
        } else {
          database.execute(
            'update meal_items set calories=?, nutrient_evidence_mask=?, '
            'food_source_snapshot=?, updated_at=?, revision=?, '
            "sync_status='local' where id=?",
            [
              entry.calories.toDouble(),
              _calorieEvidenceMask,
              _foodSource,
              now,
              (row['item_revision'] as int) + 1,
              itemId,
            ],
          );
        }
        database.execute(
          'update meals set date=?, updated_at=?, revision=?, '
          "sync_status='local' where id=?",
          [measuredAt, now, (row['meal_revision'] as int) + 1, row['meal_id']],
        );
        updated++;
      }
      database.execute('commit');
    } catch (_) {
      database.execute('rollback');
      rethrow;
    }

    final audit = database.select(
      'select count(distinct m.day_key) as days, '
      'round(sum(i.calories), 1) as calories, '
      'sum(case when i.protein != 0 or i.carbs != 0 or i.fats != 0 '
      'then 1 else 0 end) as invented_macros, '
      'sum(case when i.nutrient_evidence_mask != ? then 1 else 0 end) '
      'as invalid_evidence '
      'from meals m join meal_items i on i.meal_id = m.id '
      'where m.name = ? and m.deleted_at is null and i.deleted_at is null',
      [_calorieEvidenceMask, _mealName],
    ).single;
    if (audit['days'] != entries.length ||
        audit['invented_macros'] != 0 ||
        audit['invalid_evidence'] != 0) {
      throw StateError('Post-import nutrition audit failed: $audit');
    }
    final finalCheck = database.select('pragma quick_check').first.values.first;
    if (finalCheck != 'ok') {
      throw StateError('SQLite quick_check failed after import: $finalCheck');
    }
    stdout.writeln(
      'Applied: inserted=$inserted updated=$updated; '
      'days=${audit['days']}; total=${audit['calories']} kcal; '
      'invented macros=${audit['invented_macros']}; '
      'invalid evidence=${audit['invalid_evidence']}.',
    );
  } finally {
    database.close();
  }
}

int _ensureHistoricalFood(Database database, int now) {
  final matches = database.select(
    'select id from foods where source = ? and name = ? limit 1',
    [_foodSource, _foodName],
  );
  if (matches.isNotEmpty) {
    final id = matches.single['id'] as int;
    database.execute(
      'update foods set nutrient_evidence_mask=?, updated_at=?, '
      "sync_status='local' where id=?",
      [_calorieEvidenceMask, now, id],
    );
    return id;
  }
  database.execute(
    'insert into foods('
    'uuid,name,category,keywords,serving_size,serving_unit,'
    'calories,protein,carbs,fats,nutrient_evidence_mask,'
    'verified,is_custom,source,created_at,updated_at,revision,sync_status'
    ') values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
    [
      newDatabaseId(),
      _foodName,
      'historical-total',
      'history calorie total imported',
      1.0,
      'day',
      0.0,
      0.0,
      0.0,
      0.0,
      _calorieEvidenceMask,
      0,
      _calorieEvidenceMask,
      _foodSource,
      now,
      now,
      1,
      'local',
    ],
  );
  return database.lastInsertRowId;
}

void _insertItem(
  Database database,
  int mealId,
  int foodId,
  int calories,
  int measuredAt,
  int now,
) {
  database.execute(
    'insert into meal_items('
    'uuid,meal_id,food_id,quantity,position,calories,protein,carbs,fats,'
    'nutrient_evidence_mask,food_source_snapshot,food_verified_snapshot,'
    'serving_size_snapshot,serving_unit_snapshot,created_at,updated_at,'
    'revision,sync_status'
    ') values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
    [
      newDatabaseId(),
      mealId,
      foodId,
      1.0,
      0,
      calories.toDouble(),
      0.0,
      0.0,
      0.0,
      1,
      _foodSource,
      0,
      1.0,
      'day',
      measuredAt,
      now,
      1,
      'local',
    ],
  );
}

void _requireColumns(Database database, String table, Set<String> required) {
  final columns = database
      .select('pragma table_info($table)')
      .map((row) => row['name'])
      .toSet();
  if (!columns.containsAll(required)) {
    throw StateError('Unexpected $table schema: $columns');
  }
}

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

List<_CalorieHistoryEntry> _parse(List<String> lines) {
  final entries = <_CalorieHistoryEntry>[];
  final days = <String>{};
  for (var index = 1; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) continue;
    final fields = line.split('\t');
    if (fields.length != 2) {
      throw FormatException('Line ${index + 1}: expected 2 TSV fields');
    }
    final date = DateTime.tryParse(fields[0]);
    final calories = int.tryParse(fields[1]);
    if (date == null ||
        calories == null ||
        calories < 100 ||
        calories > 10000) {
      throw FormatException('Line ${index + 1}: invalid date or calories');
    }
    final dayKey = fields[0];
    if (!days.add(dayKey)) {
      throw FormatException('Line ${index + 1}: duplicate day $dayKey');
    }
    if (entries.isNotEmpty && !date.isAfter(entries.last.date)) {
      throw FormatException('Line ${index + 1}: dates are not ascending');
    }
    entries.add(
      _CalorieHistoryEntry(date: date, dayKey: dayKey, calories: calories),
    );
  }
  if (entries.isEmpty) throw const FormatException('No calorie entries found');
  return entries;
}

final class _CalorieHistoryEntry {
  const _CalorieHistoryEntry({
    required this.date,
    required this.dayKey,
    required this.calories,
  });

  final DateTime date;
  final String dayKey;
  final int calories;
}
