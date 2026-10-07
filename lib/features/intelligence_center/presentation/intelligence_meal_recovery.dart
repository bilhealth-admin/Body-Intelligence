part of 'intelligence_center_page.dart';

final class _CoachMealReceiptReference {
  const _CoachMealReceiptReference({
    required this.actionId,
    required this.operationId,
    required this.toolId,
    required this.entityId,
    required this.argumentsDigest,
  });

  final String actionId;
  final String operationId;
  final String toolId;
  final String entityId;
  final String argumentsDigest;

  static _CoachMealReceiptReference? fromMessage(IntelligenceMessage message) {
    if (message.role != IntelligenceMessageRole.bil ||
        message.kind != IntelligenceMessageKind.action) {
      return null;
    }
    for (final evidence in message.evidence) {
      try {
        final value = jsonDecode(evidence);
        if (value is! Map ||
            value['source'] != 'ai_coach' ||
            value['committed'] != true ||
            value['verified'] != true ||
            value['undoable'] != true ||
            value['undone_at'] != null ||
            value['entity_type'] != 'meal_item') {
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
            !RegExp(
              r'^[A-Za-z0-9][A-Za-z0-9_:-]{0,127}$',
            ).hasMatch(operationId) ||
            toolId is! String ||
            !const {
              'quick_add_macros',
              'update_meal_item',
              'delete_meal_item',
              'move_meal_item',
            }.contains(toolId) ||
            entityId is! String ||
            entityId.isEmpty ||
            digest is! String ||
            digest.isEmpty) {
          continue;
        }
        return _CoachMealReceiptReference(
          actionId: actionId,
          operationId: operationId,
          toolId: toolId,
          entityId: entityId,
          argumentsDigest: digest,
        );
      } on Object {
        // Ordinary evidence text and damaged historical receipts are inert.
      }
    }
    return null;
  }
}

extension _CoachMealRecovery on _IntelligenceCenterPageState {
  /// Reading a transcript never executes its serialized actions. An Undo is
  /// restored only after the owner-scoped journal verifies the current rows.
  Future<void> _restoreCoachMealUndoOperations(
    List<IntelligenceMessage> restored,
  ) async {
    if (!mounted || !conversationReady) return;
    final candidates = [
      for (final message in restored.reversed)
        if (_CoachMealReceiptReference.fromMessage(message) case final ref?)
          (messageId: message.id, reference: ref),
    ];
    if (candidates.isEmpty) return;
    final owner = _captureCoachMealOwner();
    final recoveredOperations = {
      for (final operation in undoOperations.values)
        ?operation.receipt.operationId,
    };
    var retained = false;
    try {
      for (final candidate in candidates) {
        owner.scope.check(owner.database.localOwnerId);
        final reference = candidate.reference;
        if (recoveredOperations.contains(reference.operationId)) continue;
        final CoachMealCommit? result;
        try {
          result = await owner.repository.readCoachMealOperation(
            operationId: reference.operationId,
            scope: owner.scope,
          );
        } on Object {
          if (!owner.scope.isCurrent) break;
          // One damaged historical entry does not disable other valid Undo.
          continue;
        }
        owner.scope.check(owner.database.localOwnerId);
        if (result == null ||
            !result.canUndo ||
            result.toolId != reference.toolId ||
            result.argumentsDigest != reference.argumentsDigest ||
            result.after.length != 1 ||
            result.after.single.item.id.toString() != reference.entityId ||
            !messages.any((message) => message.id == candidate.messageId) ||
            undoOperations.containsKey(candidate.messageId)) {
          continue;
        }
        final verifiedResult = result;
        final receipt = _coachMealReceipt(reference.actionId, verifiedResult);
        _updateState(() {
          undoOperations[candidate.messageId] = _CoachUndoOperation(
            receipt: receipt,
            undoReadback: (checkWritePermission) => _undoCommittedCoachMeal(
              actionId: reference.actionId,
              result: verifiedResult,
              owner: owner,
              checkWritePermission: checkWritePermission,
            ),
          );
        });
        recoveredOperations.add(reference.operationId);
        if (!retained) {
          recoveredMealOwners.add(owner);
          retained = true;
        }
      }
    } on Object {
      // An unavailable journal cannot prevent the user reading their history,
      // and cannot grant a serialized receipt authority to mutate a row.
    } finally {
      if (!retained) owner.dispose();
    }
  }
}
