import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> arguments) {
  final ledgerPath = _argument(arguments, '--ledger');
  if (ledgerPath == null) {
    stderr.writeln(
      'Usage: dart run tool/qa/inspect_cloud_sync_state.dart '
      '--ledger <sqlite>',
    );
    exitCode = 64;
    return;
  }

  final database = sqlite3.open(ledgerPath);
  try {
    final quickCheck = database.select('pragma quick_check').first.values.first;
    if (quickCheck != 'ok') {
      throw StateError('SQLite quick_check failed: $quickCheck');
    }
    stdout.writeln('Cloud ledger: $ledgerPath');
    for (final table in const <String>[
      'cloud_accounts',
      'cloud_devices',
      'cloud_outbox',
      'cloud_inbox',
      'cloud_tombstones',
      'cloud_conflicts',
      'cloud_dead_letters',
      'cloud_audit',
    ]) {
      final count = database
          .select('select count(*) as count from $table')
          .single['count'];
      stdout.writeln('$table=$count');
    }
    final outboxStates = database.select(
      'select disposition, attempt, count(*) as count, '
      'min(next_attempt_at) as next_attempt, max(last_error) as last_error '
      'from cloud_outbox group by disposition, attempt '
      'order by disposition, attempt',
    );
    for (final row in outboxStates) {
      stdout.writeln(
        'outbox disposition=${row['disposition']} attempt=${row['attempt']} '
        'count=${row['count']} next=${row['next_attempt']} '
        'error=${row['last_error'] ?? '<none>'}',
      );
    }
    final audits = database.select(
      'select occurred_at, category, severity, message, metadata '
      'from cloud_audit order by occurred_at desc limit 20',
    );
    for (final row in audits) {
      stdout.writeln(
        'audit ${row['occurred_at']} ${row['severity']} '
        '${row['category']}: ${row['message']} ${row['metadata']}',
      );
    }
  } finally {
    database.close();
  }
}

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}
