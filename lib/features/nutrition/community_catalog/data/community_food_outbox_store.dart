import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../data/database/app_database.dart';
import '../domain/community_food_contribution.dart';

class CommunityFoodOutboxEntry {
  const CommunityFoodOutboxEntry({
    required this.localFoodUuid,
    required this.operation,
    required this.payload,
    required this.attemptCount,
  });

  final String localFoodUuid;
  final String operation;
  final Map<String, dynamic> payload;
  final int attemptCount;
}

class CommunityFoodOutboxStore {
  CommunityFoodOutboxStore(this._database);

  final AppDatabase _database;

  Future<void> enqueueUpsert(CommunityFoodContribution contribution) {
    return _database.customStatement(
      '''
      INSERT INTO community_food_outbox(
        local_food_uuid, operation, payload_json, attempt_count,
        next_attempt_at, last_error, updated_at
      ) VALUES (?, 'upsert', ?, 0, NULL, NULL, ?)
      ON CONFLICT(local_food_uuid) DO UPDATE SET
        operation = 'upsert',
        payload_json = excluded.payload_json,
        attempt_count = 0,
        next_attempt_at = NULL,
        last_error = NULL,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        contribution.localFoodUuid,
        jsonEncode(contribution.payload),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> enqueueDelete(String localFoodUuid) {
    return _database.customStatement(
      '''
      INSERT INTO community_food_outbox(
        local_food_uuid, operation, payload_json, attempt_count,
        next_attempt_at, last_error, updated_at
      ) VALUES (?, 'delete', ?, 0, NULL, NULL, ?)
      ON CONFLICT(local_food_uuid) DO UPDATE SET
        operation = 'delete',
        payload_json = excluded.payload_json,
        attempt_count = 0,
        next_attempt_at = NULL,
        last_error = NULL,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        localFoodUuid,
        jsonEncode(<String, String>{'client_food_id': localFoodUuid}),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<List<CommunityFoodOutboxEntry>> due({int limit = 20}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _database
        .customSelect(
          '''
      SELECT local_food_uuid, operation, payload_json, attempt_count
      FROM community_food_outbox
      WHERE next_attempt_at IS NULL OR next_attempt_at <= ?
      ORDER BY updated_at ASC
      LIMIT ?
      ''',
          variables: <Variable<Object>>[
            Variable<int>(now),
            Variable<int>(limit),
          ],
        )
        .get();

    return rows
        .map((row) {
          final decoded = jsonDecode(row.read<String>('payload_json'));
          return CommunityFoodOutboxEntry(
            localFoodUuid: row.read<String>('local_food_uuid'),
            operation: row.read<String>('operation'),
            payload: Map<String, dynamic>.from(decoded as Map),
            attemptCount: row.read<int>('attempt_count'),
          );
        })
        .toList(growable: false);
  }

  Future<void> markSucceeded(String localFoodUuid) {
    return _database.customStatement(
      'DELETE FROM community_food_outbox WHERE local_food_uuid = ?',
      <Object?>[localFoodUuid],
    );
  }

  Future<void> markFailed(CommunityFoodOutboxEntry entry, Object error) {
    final nextAttempt = entry.attemptCount + 1;
    final exponent = nextAttempt.clamp(1, 8);
    final delaySeconds = (1 << exponent).clamp(2, 300);
    final retryAt = DateTime.now()
        .add(Duration(seconds: delaySeconds))
        .millisecondsSinceEpoch;
    final message = error.toString().replaceAll(RegExp(r'[\r\n]+'), ' ');
    return _database.customStatement(
      '''
      UPDATE community_food_outbox
      SET attempt_count = ?, next_attempt_at = ?, last_error = ?, updated_at = ?
      WHERE local_food_uuid = ?
      ''',
      <Object?>[
        nextAttempt,
        retryAt,
        message.length <= 500 ? message : message.substring(0, 500),
        DateTime.now().millisecondsSinceEpoch,
        entry.localFoodUuid,
      ],
    );
  }

  Future<int> pendingCount() async {
    final row = await _database
        .customSelect('SELECT COUNT(*) AS total FROM community_food_outbox')
        .getSingle();
    return row.read<int>('total');
  }
}
