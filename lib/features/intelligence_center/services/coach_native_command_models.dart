part of 'coach_native_command_repository.dart';

enum CoachNativeCommandKind { water, weight, goal, measurements, memory }

enum CoachNativeResultState { committed, modified, undone }

enum CoachNativeConflictReason {
  ownerChanged,
  operationMismatch,
  staleRecord,
  missingRecord,
  invalidJournal,
  readbackUnavailable,
}

final class CoachNativeConflict implements Exception {
  const CoachNativeConflict(this.reason, {this.committed = false});
  final CoachNativeConflictReason reason;
  final bool committed;
  @override
  String toString() =>
      'CoachNativeConflict(${reason.name}, committed=$committed)';
}

/// A lifetime cannot be reactivated by a later return to the same owner ID.
final class CoachNativeOwnerScope {
  CoachNativeOwnerScope({required this.ownerId, required this._isCurrent});
  final String? ownerId;
  final bool Function() _isCurrent;
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  bool get isCurrent {
    if (!_cancelled && !_isCurrent()) _cancelled = true;
    return !_cancelled;
  }

  void check(String? databaseOwner, {bool committed = false}) {
    if (ownerId != databaseOwner || !isCurrent) {
      _cancelled = true;
      throw CoachNativeConflict(
        CoachNativeConflictReason.ownerChanged,
        committed: committed,
      );
    }
  }
}

final class CoachNativeCommand {
  CoachNativeCommand._({
    required this.operationId,
    required this.toolId,
    required this.kind,
    required this.inputDigest,
    required Map<String, Object?> arguments,
    required Map<String, Object?> resolved,
    required this.before,
  }) : arguments = _freezeNativeJson(arguments) as Map<String, Object?>,
       resolved = _freezeNativeJson(resolved) as Map<String, Object?>;

  final String operationId;
  final String toolId;
  final CoachNativeCommandKind kind;
  final String inputDigest;
  final Map<String, Object?> arguments;
  final Map<String, Object?> resolved;
  final CoachNativeSnapshot before;
  String get argumentsDigest => _nativeDigest({
    'toolId': toolId,
    'arguments': arguments,
    'resolved': resolved,
    'before': before.toJson(),
  });

  Map<String, Object?> toJson() => {
    'operationId': operationId,
    'toolId': toolId,
    'kind': kind.name,
    'inputDigest': inputDigest,
    'arguments': arguments,
    'resolved': resolved,
    'before': before.toJson(),
  };

  factory CoachNativeCommand._fromJson(Map<String, dynamic> raw) {
    final command = CoachNativeCommand._(
      operationId: raw['operationId'] as String,
      toolId: raw['toolId'] as String,
      kind: CoachNativeCommandKind.values.byName(raw['kind'] as String),
      inputDigest: raw['inputDigest'] as String,
      arguments: Map<String, Object?>.from(raw['arguments'] as Map),
      resolved: Map<String, Object?>.from(raw['resolved'] as Map),
      before: CoachNativeSnapshot._fromJson(
        Map<String, dynamic>.from(raw['before'] as Map),
      ),
    );
    if (!CoachActionAdmission.validOperationId(command.operationId) ||
        _nativeKind(command.toolId) != command.kind ||
        const BilToolRegistry()
                .lookup(command.toolId)
                ?.validateArguments(command.arguments) ==
            null ||
        command.inputDigest !=
            _nativeDigest({
              'toolId': command.toolId,
              'arguments': command.arguments,
            })) {
      throw const FormatException('Invalid native command');
    }
    return command;
  }
}

final class CoachNativeCommit {
  const CoachNativeCommit._({
    required this.command,
    required this.committedAt,
    required this.after,
    required this.current,
    required this.state,
    required this.replayed,
    this.undoneAt,
  });
  final CoachNativeCommand command;
  final DateTime committedAt;
  final CoachNativeSnapshot after;
  final CoachNativeSnapshot current;
  final CoachNativeResultState state;
  final bool replayed;
  final DateTime? undoneAt;
  String get operationId => command.operationId;
  String get toolId => command.toolId;
  String get argumentsDigest => command.argumentsDigest;
  CoachNativeCommandKind get kind => command.kind;
  CoachNativeSnapshot get before => command.before;
  bool get canUndo => state == CoachNativeResultState.committed;
}

CoachNativeCommandKind _nativeKind(String toolId) => switch (toolId) {
  'log_water' => CoachNativeCommandKind.water,
  'log_weight' => CoachNativeCommandKind.weight,
  'update_goal' => CoachNativeCommandKind.goal,
  'save_measurements' => CoachNativeCommandKind.measurements,
  'save_memory' => CoachNativeCommandKind.memory,
  _ => throw const CoachNativeConflict(
    CoachNativeConflictReason.operationMismatch,
  ),
};

Object? _canonicalNativeJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonicalNativeJson(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalNativeJson).toList(growable: false);
  }
  return value;
}

Object? _freezeNativeJson(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freezeNativeJson(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeNativeJson));
  }
  return value;
}

String _nativeDigest(Object? value) => sha256
    .convert(utf8.encode(jsonEncode(_canonicalNativeJson(value))))
    .toString();
