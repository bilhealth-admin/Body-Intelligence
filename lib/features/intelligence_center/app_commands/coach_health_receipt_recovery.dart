part of '../services/coach_native_command_repository.dart';

/// A locator in the existing journal, committed atomically with health data.
/// Its acknowledgement only records durable presentation, never write authority.
final class _HealthReceiptRecovery {
  const _HealthReceiptRecovery._(this.conversationId, this.receiptAcknowledged);

  factory _HealthReceiptRecovery.pending(String conversationId) {
    _requireHealthRecoveryConversationId(conversationId);
    return _HealthReceiptRecovery._(conversationId, false);
  }

  factory _HealthReceiptRecovery.fromJson(Object? value) {
    if (value is! Map ||
        value['conversationId'] is! String ||
        value['receiptAcknowledged'] is! bool) {
      throw const FormatException('Health receipt recovery metadata');
    }
    final conversationId = value['conversationId'] as String;
    _requireHealthRecoveryConversationId(conversationId);
    return _HealthReceiptRecovery._(
      conversationId,
      value['receiptAcknowledged'] as bool,
    );
  }

  final String conversationId;
  final bool receiptAcknowledged;

  Map<String, Object?> toJson() => {
    'conversationId': conversationId,
    'receiptAcknowledged': receiptAcknowledged,
  };
}

void _requireHealthRecoveryConversationId(String value) {
  if (value.isEmpty || value.trim() != value || value.length > 256) {
    throw ArgumentError.value(value, 'conversationId');
  }
}

extension _NativeHealthReceiptRecovery on CoachNativeCommandRepository {
  Future<List<String>> _listPendingHealthReceiptOperationIds(
    CoachNativeOwnerScope scope,
    String conversationId,
    int limit,
  ) async {
    _requireHealthRecoveryConversationId(conversationId);
    if (limit < 1 || limit > 32) {
      throw RangeError.range(limit, 1, 32, 'limit');
    }
    scope.check(database.localOwnerId);
    final owner = LocalDatabaseScope.keyForOwner(database.localOwnerId);
    final prefix = 'coachNativeOperationV1.$owner.';
    final rows = await _awaitOwner(
      () => database
          .customSelect(
            // CASE is deliberately the guard around every JSON function. A WHERE
            // json_valid(value) AND json_extract(...) can be reordered by SQLite.
            // Filtering precedes LIMIT, so unrelated newer operations cannot hide
            // an older unacknowledged receipt for this owner and conversation.
            'SELECT key, value FROM preferences '
            'WHERE substr(key, 1, ?) = ? AND CASE WHEN json_valid(value) THEN '
            "json_type(value, '\$.healthReceiptRecovery') = 'object' AND "
            "json_type(value, '\$.healthReceiptRecovery.conversationId') = 'text' AND "
            "json_extract(value, '\$.healthReceiptRecovery.conversationId') = ? AND "
            "json_type(value, '\$.healthReceiptRecovery.receiptAcknowledged') = 'false' AND "
            "json_extract(value, '\$.ownerScope') = ? AND "
            "json_extract(value, '\$.command.kind') = 'health' AND "
            "json_type(value, '\$.command.operationId') = 'text' AND "
            "key = ? || json_extract(value, '\$.command.operationId') "
            'ELSE 0 END ORDER BY rowid DESC LIMIT ?',
            variables: [
              Variable<int>(prefix.length),
              Variable<String>(prefix),
              Variable<String>(conversationId),
              Variable<String>(owner),
              Variable<String>(prefix),
              Variable<int>(limit),
            ],
            readsFrom: {database.preferences},
          )
          .get(),
      scope,
    );
    final result = <String>[];
    for (final row in rows) {
      try {
        final journal = _NativeJournal.decode(row.read<String>('value'));
        final recovery = journal.healthReceiptRecovery;
        if (journal.ownerScope == owner &&
            journal.command.kind == CoachNativeCommandKind.health &&
            _journalKey(journal.command.operationId) ==
                row.read<String>('key') &&
            recovery?.conversationId == conversationId &&
            recovery?.receiptAcknowledged == false) {
          result.add(journal.command.operationId);
        }
      } on Object {
        // Corrupt journal contents cannot become a candidate for UI recovery.
      }
    }
    scope.check(database.localOwnerId);
    return List.unmodifiable(result);
  }

  Future<void> _markHealthReceiptPersisted(
    String operationId,
    CoachNativeOwnerScope scope,
    String conversationId,
  ) async {
    _requireHealthRecoveryConversationId(conversationId);
    scope.check(database.localOwnerId);
    await database.transaction(() async {
      final key = _journalKey(operationId);
      final raw = await _awaitOwner(() => preferences.get(key), scope);
      if (raw == null) {
        throw const CoachNativeConflict(
          CoachNativeConflictReason.operationMismatch,
        );
      }
      final journal = _NativeJournal.decode(raw);
      final recovery = journal.healthReceiptRecovery;
      if (journal.ownerScope !=
              LocalDatabaseScope.keyForOwner(database.localOwnerId) ||
          journal.command.operationId != operationId ||
          journal.command.kind != CoachNativeCommandKind.health ||
          recovery?.conversationId != conversationId) {
        throw const CoachNativeConflict(
          CoachNativeConflictReason.operationMismatch,
        );
      }
      if (recovery!.receiptAcknowledged) return;
      // Preserve the serialized snapshots, digest and optional journal fields.
      // UPDATE never replaces the row: journal rowid orders the stale-Undo guard.
      final json = jsonDecode(raw) as Map<String, dynamic>;
      (json['healthReceiptRecovery'] as Map)['receiptAcknowledged'] = true;
      final changed = await _awaitOwner(
        () =>
            (database.update(database.preferences)
                  ..where((row) => row.key.equals(key) & row.value.equals(raw)))
                .write(PreferencesCompanion(value: Value(jsonEncode(json)))),
        scope,
      );
      if (changed != 1) {
        throw const CoachNativeConflict(
          CoachNativeConflictReason.invalidJournal,
        );
      }
      scope.check(database.localOwnerId);
    });
    scope.check(database.localOwnerId);
  }
}
