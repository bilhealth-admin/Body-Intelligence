import 'dart:io';

import 'package:body_intelligence_log/data/database/database_ids.dart';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> arguments) {
  final databasePath = _argument(arguments, '--database');
  final inputPath = _argument(arguments, '--input');
  final apply = arguments.contains('--apply');
  if (databasePath == null || inputPath == null) {
    stderr.writeln(
      'Usage: dart run tool/qa/import_owner_weight_history.dart '
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
    final columns = database
        .select('pragma table_info(weight_entries)')
        .map((row) => row['name'])
        .toSet();
    const required = {
      'uuid',
      'date',
      'day_key',
      'weight',
      'measurement_context',
      'created_at',
      'updated_at',
      'revision',
      'sync_status',
    };
    if (!columns.containsAll(required)) {
      throw StateError('Unexpected weight_entries schema: $columns');
    }

    final profileTimestamp = database.select(
      'select created_at, typeof(created_at) as storage_type '
      'from user_profile limit 1',
    );
    if (profileTimestamp.isNotEmpty) {
      stdout.writeln(
        'Drift timestamp sample: ${profileTimestamp.single['created_at']} '
        '(${profileTimestamp.single['storage_type']}).',
      );
    }

    final existingCount = database
        .select(
          'select count(*) as count from weight_entries where deleted_at is null',
        )
        .first['count'];
    final ownerRows = database.select(
      "select value from preferences where key = 'cloud.localDataOwner.v1' "
      'limit 1',
    );
    final syncStates = database.select(
      'select sync_status, count(*) as count from weight_entries '
      'where deleted_at is null group by sync_status order by sync_status',
    );
    stdout.writeln(
      'Validated ${entries.length} weights; existing active rows: $existingCount; '
      'range ${entries.first.dayKey} ${entries.first.weightKg} kg -> '
      '${entries.last.dayKey} ${entries.last.weightKg} kg.',
    );
    stdout.writeln(
      'Local owner: ${ownerRows.isEmpty ? '<unbound>' : ownerRows.single['value']}; '
      'weight sync states: '
      '${syncStates.map((row) => '${row['sync_status']}=${row['count']}').join(', ')}.',
    );
    if (!apply) {
      stdout.writeln('Dry run only. Re-run with --apply to mutate the copy.');
      return;
    }

    var inserted = 0;
    var updated = 0;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    database.execute('begin immediate');
    try {
      for (final entry in entries) {
        final existing = database.select(
          'select id, revision from weight_entries '
          'where day_key = ? and deleted_at is null limit 1',
          [entry.dayKey],
        );
        final measuredAt =
            DateTime.utc(
              entry.date.year,
              entry.date.month,
              entry.date.day,
              8,
            ).millisecondsSinceEpoch ~/
            1000;
        if (existing.isEmpty) {
          database.execute(
            'insert into weight_entries('
            'uuid,date,day_key,weight,note,progress_photo_path,'
            'measurement_context,created_at,updated_at,deleted_at,revision,sync_status'
            ') values(?,?,?,?,?,?,?,?,?,?,?,?)',
            [
              newDatabaseId(),
              measuredAt,
              entry.dayKey,
              entry.weightKg,
              null,
              null,
              'afterWaking',
              measuredAt,
              now,
              null,
              1,
              'local',
            ],
          );
          inserted++;
        } else {
          final id = existing.single['id'];
          final revision = (existing.single['revision'] as int) + 1;
          database.execute(
            'update weight_entries set date=?, weight=?, updated_at=?, '
            'deleted_at=null, revision=?, sync_status=? where id=?',
            [measuredAt, entry.weightKg, now, revision, 'local', id],
          );
          updated++;
        }
      }
      database.execute('commit');
    } catch (_) {
      database.execute('rollback');
      rethrow;
    }

    final active = database
        .select(
          'select count(*) as count, min(day_key) as first_day, '
          'max(day_key) as last_day, min(weight) as min_weight, '
          'max(weight) as max_weight from weight_entries where deleted_at is null',
        )
        .single;
    final dirty = database
        .select(
          "select count(*) as count from weight_entries where sync_status in "
          "('local','pending','pendingDelete')",
        )
        .single['count'];
    final invalidTimestamps =
        database
                .select(
                  'select count(*) as count from weight_entries '
                  'where deleted_at is null and (date < 0 or date >= 4102444800)',
                )
                .single['count']
            as int;
    if (invalidTimestamps != 0) {
      throw StateError(
        '$invalidTimestamps weight rows use an invalid Drift epoch scale.',
      );
    }
    stdout.writeln(
      'Applied: inserted=$inserted updated=$updated; active=${active['count']}; '
      'dirty=$dirty; days=${active['first_day']}..${active['last_day']}; '
      'kg=${active['min_weight']}..${active['max_weight']}.',
    );
  } finally {
    database.close();
  }
}

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

List<_WeightHistoryEntry> _parse(List<String> lines) {
  final entries = <_WeightHistoryEntry>[];
  final days = <String>{};
  for (var index = 1; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) continue;
    final fields = line.split('\t');
    if (fields.length != 2) {
      throw FormatException('Line ${index + 1}: expected 2 TSV fields');
    }
    final date = DateTime.tryParse(fields[0]);
    final weight = double.tryParse(fields[1]);
    if (date == null || weight == null || weight < 20 || weight > 400) {
      throw FormatException('Line ${index + 1}: invalid date or weight');
    }
    final dayKey = fields[0];
    if (!days.add(dayKey)) {
      throw FormatException('Line ${index + 1}: duplicate day $dayKey');
    }
    if (entries.isNotEmpty && !date.isAfter(entries.last.date)) {
      throw FormatException('Line ${index + 1}: dates are not ascending');
    }
    entries.add(
      _WeightHistoryEntry(date: date, dayKey: dayKey, weightKg: weight),
    );
  }
  if (entries.isEmpty) throw const FormatException('No weight entries found');
  return entries;
}

final class _WeightHistoryEntry {
  const _WeightHistoryEntry({
    required this.date,
    required this.dayKey,
    required this.weightKg,
  });

  final DateTime date;
  final String dayKey;
  final double weightKg;
}
