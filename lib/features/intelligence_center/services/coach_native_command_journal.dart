part of 'coach_native_command_repository.dart';

final class _NativeJournal {
  const _NativeJournal({
    required this.command,
    required this.ownerScope,
    required this.committedAt,
    required this.after,
    this.undoneAt,
    this.undoAfter,
    this.healthReceiptRecovery,
  });
  final CoachNativeCommand command;
  final String ownerScope;
  final DateTime committedAt;
  final CoachNativeSnapshot after;
  final DateTime? undoneAt;
  final CoachNativeSnapshot? undoAfter;
  final _HealthReceiptRecovery? healthReceiptRecovery;

  _NativeJournal compensated(CoachNativeSnapshot readback) => _NativeJournal(
    command: command,
    ownerScope: ownerScope,
    committedAt: committedAt,
    after: after,
    undoneAt: DateTime.now(),
    undoAfter: readback,
    healthReceiptRecovery: healthReceiptRecovery,
  );

  String encode() => jsonEncode({
    'schema': 1,
    'command': command.toJson(),
    'ownerScope': ownerScope,
    'committedAt': committedAt.toIso8601String(),
    'after': after.toJson(),
    'undoneAt': undoneAt?.toIso8601String(),
    'undoAfter': undoAfter?.toJson(),
    'argumentsDigest': command.argumentsDigest,
    if (healthReceiptRecovery != null)
      'healthReceiptRecovery': healthReceiptRecovery!.toJson(),
  });

  factory _NativeJournal.decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schema'] != 1) throw const FormatException('Journal schema');
      final result = _NativeJournal(
        command: CoachNativeCommand._fromJson(
          Map<String, dynamic>.from(json['command'] as Map),
        ),
        ownerScope: json['ownerScope'] as String,
        committedAt: DateTime.parse(json['committedAt'] as String),
        after: CoachNativeSnapshot._fromJson(
          Map<String, dynamic>.from(json['after'] as Map),
        ),
        undoneAt: json['undoneAt'] == null
            ? null
            : DateTime.parse(json['undoneAt'] as String),
        undoAfter: json['undoAfter'] == null
            ? null
            : CoachNativeSnapshot._fromJson(
                Map<String, dynamic>.from(json['undoAfter'] as Map),
              ),
        healthReceiptRecovery: json.containsKey('healthReceiptRecovery')
            ? _HealthReceiptRecovery.fromJson(json['healthReceiptRecovery'])
            : null,
      );
      if (result.command.argumentsDigest != json['argumentsDigest'] ||
          (result.undoneAt == null) != (result.undoAfter == null) ||
          result.healthReceiptRecovery != null &&
              result.command.kind != CoachNativeCommandKind.health) {
        throw const FormatException('Journal identity');
      }
      return result;
    } on Object {
      throw const CoachNativeConflict(CoachNativeConflictReason.invalidJournal);
    }
  }
}

extension _NativeJournalStorage on CoachNativeCommandRepository {
  String _journalKey(String operationId) {
    if (!CoachActionAdmission.validOperationId(operationId)) {
      throw const CoachNativeConflict(
        CoachNativeConflictReason.operationMismatch,
      );
    }
    return 'coachNativeOperationV1.${LocalDatabaseScope.keyForOwner(database.localOwnerId)}.$operationId';
  }

  Future<_NativeJournal?> _readJournal(
    String operationId,
    CoachNativeOwnerScope scope, {
    bool committed = false,
  }) async {
    final raw = await _awaitOwner(
      () => preferences.get(_journalKey(operationId)),
      scope,
      committed: committed,
    );
    if (raw == null) return null;
    final journal = _NativeJournal.decode(raw);
    if (journal.command.operationId != operationId ||
        journal.ownerScope !=
            LocalDatabaseScope.keyForOwner(database.localOwnerId)) {
      throw const CoachNativeConflict(CoachNativeConflictReason.invalidJournal);
    }
    return journal;
  }

  Future<void> _writeJournal(
    _NativeJournal journal,
    CoachNativeOwnerScope scope,
  ) => _awaitOwner(
    () => preferences.setManyInCurrentTransaction({
      _journalKey(journal.command.operationId): journal.encode(),
    }),
    scope,
  );

  void _requireMatchingOperation(
    _NativeJournal journal,
    CoachNativeCommand command,
  ) {
    if (journal.command.toolId != command.toolId ||
        journal.command.argumentsDigest != command.argumentsDigest) {
      throw const CoachNativeConflict(
        CoachNativeConflictReason.operationMismatch,
      );
    }
  }

  /// Preference-backed health rows have no revision column and their clocks
  /// have second precision. A later accepted command may therefore write the
  /// same values and timestamp. The existing native journal's insertion order
  /// supplies a durable, clock-independent guard without another journal or
  /// schema. Legacy native commands retain their existing revision behavior.
  Future<bool> _laterOverlappingHealthOperation(
    _NativeJournal original,
    CoachNativeOwnerScope scope, {
    bool committed = false,
  }) async {
    if (original.command.kind != CoachNativeCommandKind.health) return false;
    final affected = _nativeHealthAffectedIdentities(original);
    if (affected == null || affected.isEmpty) return true;
    final key = _journalKey(original.command.operationId);
    final anchor = await _awaitOwner(
      () => database
          .customSelect(
            'SELECT rowid AS journal_rowid FROM preferences WHERE key = ?',
            variables: [Variable<String>(key)],
            readsFrom: {database.preferences},
          )
          .getSingleOrNull(),
      scope,
      committed: committed,
    );
    if (anchor == null) return true;
    final prefix = 'coachNativeOperationV1.${original.ownerScope}.';
    final later = await _awaitOwner(
      () => database
          .customSelect(
            'SELECT key, value FROM preferences '
            'WHERE rowid > ? AND substr(key, 1, ?) = ? '
            'ORDER BY rowid DESC LIMIT 129',
            variables: [
              Variable<int>(anchor.read<int>('journal_rowid')),
              Variable<int>(prefix.length),
              Variable<String>(prefix),
            ],
            readsFrom: {database.preferences},
          )
          .get(),
      scope,
      committed: committed,
    );
    // There may be an older overlapping operation beyond this bounded scan.
    if (later.length > 128) return true;
    for (final row in later) {
      _NativeJournal candidate;
      try {
        candidate = _NativeJournal.decode(row.read<String>('value'));
        if (candidate.ownerScope != original.ownerScope ||
            _journalKey(candidate.command.operationId) !=
                row.read<String>('key')) {
          return true;
        }
      } on Object {
        // An unverifiable later journal cannot authorize destructive recovery.
        return true;
      }
      if (candidate.command.kind != CoachNativeCommandKind.health) continue;
      final candidateAffected = _nativeHealthAffectedIdentities(candidate);
      if (candidateAffected == null ||
          candidateAffected.any(affected.contains)) {
        return true;
      }
      // Already-undone later commands deliberately still fence the older
      // command: a subsequent explicit choice must never be silently erased.
    }
    return false;
  }

  Future<CoachNativeCommit> _commitReadback(
    String operationId,
    CoachNativeOwnerScope scope, {
    required bool replayed,
  }) async => (await _operationReadback(
    operationId,
    scope,
    replayed: replayed,
    committed: true,
  ))!;

  Future<CoachNativeCommit?> _operationReadback(
    String operationId,
    CoachNativeOwnerScope scope, {
    required bool replayed,
    required bool committed,
  }) async {
    try {
      scope.check(database.localOwnerId, committed: committed);
      final result = await database.transaction(() async {
        final journal = await _readJournal(
          operationId,
          scope,
          committed: committed,
        );
        if (journal == null) {
          if (!committed) return null;
          throw const CoachNativeConflict(
            CoachNativeConflictReason.invalidJournal,
          );
        }
        final current = await _readSnapshot(
          journal.command.kind,
          journal.command.resolved,
          scope,
          waterId: journal.after.water?.id,
          committed: committed,
        );
        final superseded =
            journal.command.kind == CoachNativeCommandKind.health &&
            journal.undoneAt == null &&
            await _laterOverlappingHealthOperation(
              journal,
              scope,
              committed: committed,
            );
        return CoachNativeCommit._(
          command: journal.command,
          committedAt: journal.committedAt,
          after: journal.after,
          current: current,
          state: journal.undoneAt != null
              ? CoachNativeResultState.undone
              : !superseded && _sameNativeSnapshot(journal.after, current)
              ? CoachNativeResultState.committed
              : CoachNativeResultState.modified,
          replayed: replayed,
          undoneAt: journal.undoneAt,
        );
      });
      scope.check(database.localOwnerId, committed: committed);
      return result;
    } on CoachNativeConflict catch (error) {
      throw CoachNativeConflict(error.reason, committed: committed);
    } on Object {
      throw CoachNativeConflict(
        CoachNativeConflictReason.readbackUnavailable,
        committed: committed,
      );
    }
  }
}

/// Only affected record identities are inspected. Receipts and private health
/// contents do not participate in cross-operation overlap classification.
Set<String>? _nativeHealthAffectedIdentities(_NativeJournal journal) {
  final command = journal.command;
  final result = <String>{};
  final states = [
    command.before.health,
    journal.after.health,
    journal.undoAfter?.health,
  ];
  for (final state in states) {
    if (state == null) continue;
    final preferences = state['preferences'];
    if (preferences != null) {
      if (preferences is! Map || preferences.isEmpty) return null;
      for (final key in preferences.keys) {
        if (key is! String || key.isEmpty) return null;
        result.add('preference:$key');
      }
    }
  }

  if (const {
    'log_exercise',
    'close_day',
    'reopen_day',
    'log_sleep',
    'save_day_note',
  }.contains(command.toolId)) {
    final date = command.resolved['date'];
    if (date is! String || date.isEmpty) return null;
    result.add('daily-day:$date');
    for (final state in states) {
      if (state == null) continue;
      final record =
          state[command.toolId == 'log_exercise' ? 'dailyLog' : 'record'];
      if (record == null) continue;
      if (record is! Map) return null;
      final uuid = record['uuid'];
      final day = record['dayKey'];
      if (uuid is! String || uuid.isEmpty || day is! String || day.isEmpty) {
        return null;
      }
      result.add('daily-uuid:$uuid');
      result.add('daily-day:$day');
    }
  } else if (command.toolId == 'save_life_context') {
    final uuid = command.resolved['uuid'];
    if (uuid is! String || uuid.isEmpty) return null;
    result.add('life-uuid:$uuid');
    for (final state in states) {
      if (state == null) continue;
      final record = state['record'];
      if (record == null) continue;
      if (record is! Map || record['uuid'] is! String || record['id'] is! int) {
        return null;
      }
      result.add('life-uuid:${record['uuid']}');
      result.add('life-id:${record['id']}');
    }
  }
  return result.isEmpty ? null : result;
}
