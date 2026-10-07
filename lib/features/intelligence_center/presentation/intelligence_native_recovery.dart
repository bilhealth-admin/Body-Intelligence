part of 'intelligence_center_page.dart';

final class _CoachNativeReceiptReference {
  const _CoachNativeReceiptReference({
    required this.actionId,
    required this.operationId,
    required this.payload,
  });

  final String actionId;
  final String operationId;
  final Map<dynamic, dynamic> payload;

  static _CoachNativeReceiptReference? fromMessage(
    IntelligenceMessage message,
  ) {
    if (message.role != IntelligenceMessageRole.bil ||
        message.kind != IntelligenceMessageKind.action) {
      return null;
    }
    const entities = {
      'log_water': 'water_entry',
      'log_weight': 'weight_entry',
      'update_goal': 'goal',
      'save_measurements': 'body_measurement',
      'save_memory': 'coach_memory',
    };
    for (final evidence in message.evidence) {
      try {
        final value = jsonDecode(evidence);
        if (value is! Map ||
            value['source'] != 'ai_coach' ||
            value['committed'] != true ||
            value['verified'] != true ||
            value['undoable'] != true ||
            value['undone_at'] != null) {
          continue;
        }
        final actionId = value['action_id'];
        final operationId = value['operation_id'];
        final toolId = value['tool_id'];
        final entityId = value['entity_id'];
        final after = value['after'];
        final digest = after is Map ? after['arguments_digest'] : null;
        if (actionId is! String ||
            actionId.isEmpty ||
            operationId is! String ||
            !CoachActionAdmission.validOperationId(operationId) ||
            !entities.containsKey(toolId) ||
            entities[toolId] != value['entity_type'] ||
            entityId is! String ||
            entityId.isEmpty ||
            digest is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
          continue;
        }
        return _CoachNativeReceiptReference(
          actionId: actionId,
          operationId: operationId,
          payload: value,
        );
      } on Object {
        // Plain evidence and damaged history are not executable commands.
      }
    }
    return null;
  }

  bool matches(BilActionReceipt verified) {
    // Match immutable row UUID/version and commit time as well as integer ID.
    // A copied receipt cannot point to an unrelated row with the same ID or a
    // coincidentally identical operation name in another owner's database.
    final canonical = verified.toStructuredPayload();
    return const [
      'tool_id',
      'operation_id',
      'entity_type',
      'entity_id',
      'completed_at',
      'before',
      'after',
    ].every(
      (key) => _sameRecoveredNativeEvidence(payload[key], canonical[key]),
    );
  }
}

bool _sameRecoveredNativeEvidence(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) &&
              _sameRecoveredNativeEvidence(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_sameRecoveredNativeEvidence(left[i], right[i])) return false;
    }
    return true;
  }
  return left == right;
}

extension _CoachNativeRecovery on _IntelligenceCenterPageState {
  Future<void> _restoreCoachNativeUndoOperations(
    List<IntelligenceMessage> restored,
  ) async {
    if (!mounted || !conversationReady) return;
    final candidates = [
      for (final message in restored.reversed)
        if (_CoachNativeReceiptReference.fromMessage(message)
            case final reference?)
          (message: message, reference: reference),
    ];
    if (candidates.isEmpty) return;
    _RecoveredCoachNativeOwner? owner;
    var retained = false;
    final recoveredOperations = {
      for (final operation in undoOperations.values)
        ?operation.receipt.operationId,
    };
    try {
      final visit = owner = _captureRecoveredCoachNativeOwner();
      recoveredNativeOwners.add(visit);
      for (final candidate in candidates) {
        visit.scope.check(visit.database.localOwnerId);
        final reference = candidate.reference;
        if (recoveredOperations.contains(reference.operationId)) continue;
        try {
          final result = await visit.repository.readOperation(
            operationId: reference.operationId,
            scope: visit.scope,
          );
          visit.scope.check(visit.database.localOwnerId);
          if (result == null || !result.canUndo) continue;
          final receipt = _coachNativeReceipt(reference.actionId, result);
          if (!reference.matches(receipt) ||
              !messages.any(
                (message) => identical(message, candidate.message),
              ) ||
              undoOperations.containsKey(candidate.message.id)) {
            continue;
          }
          _updateState(() {
            undoOperations[candidate.message.id] = _CoachUndoOperation(
              receipt: receipt,
              undoReadback: (checkWritePermission) => _undoRecoveredCoachNative(
                actionId: reference.actionId,
                result: result,
                owner: visit,
                checkWritePermission: checkWritePermission,
              ),
            );
          });
          recoveredOperations.add(reference.operationId);
          retained = true;
        } on Object {
          if (!visit.scope.isCurrent) break;
          // A corrupt/missing journal does not hide other valid operations.
        }
      }
    } on Object {
      // Reading history must remain available if recovery cannot be verified.
    } finally {
      if (!retained) {
        recoveredNativeOwners.remove(owner);
        owner?.dispose();
      }
    }
  }

  Future<BilActionReceipt> _undoRecoveredCoachNative({
    required String actionId,
    required CoachNativeCommit result,
    required _RecoveredCoachNativeOwner owner,
    required void Function() checkWritePermission,
  }) async {
    owner.scope.check(owner.database.localOwnerId);
    final undone = await owner.repository.undo(
      operationId: result.operationId,
      toolId: result.toolId,
      argumentsDigest: result.argumentsDigest,
      scope: owner.scope,
      checkWritePermission: checkWritePermission,
    );
    owner.scope.check(owner.database.localOwnerId, committed: true);
    _refreshCommittedCoachNative(undone.kind);
    if (undone.kind == CoachNativeCommandKind.memory) {
      final id = undone.command.resolved['memoryId']! as String;
      unawaited(
        owner.memoryRepository.syncCommittedChange(
          id: id,
          expectedLocal: undone.current.memory(id),
          isCurrentOwner: () => owner.scope.isCurrent,
        ),
      );
    }
    return _coachNativeReceipt(actionId, undone, undo: true);
  }
}
