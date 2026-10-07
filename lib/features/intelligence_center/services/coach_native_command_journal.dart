part of 'coach_native_command_repository.dart';

final class _NativeJournal {
  const _NativeJournal({
    required this.command,
    required this.ownerScope,
    required this.committedAt,
    required this.after,
    this.undoneAt,
    this.undoAfter,
  });
  final CoachNativeCommand command;
  final String ownerScope;
  final DateTime committedAt;
  final CoachNativeSnapshot after;
  final DateTime? undoneAt;
  final CoachNativeSnapshot? undoAfter;

  _NativeJournal compensated(CoachNativeSnapshot readback) => _NativeJournal(
    command: command,
    ownerScope: ownerScope,
    committedAt: committedAt,
    after: after,
    undoneAt: DateTime.now(),
    undoAfter: readback,
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
      );
      if (result.command.argumentsDigest != json['argumentsDigest'] ||
          (result.undoneAt == null) != (result.undoAfter == null)) {
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
        return CoachNativeCommit._(
          command: journal.command,
          committedAt: journal.committedAt,
          after: journal.after,
          current: current,
          state: journal.undoneAt != null
              ? CoachNativeResultState.undone
              : _sameNativeSnapshot(journal.after, current)
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
