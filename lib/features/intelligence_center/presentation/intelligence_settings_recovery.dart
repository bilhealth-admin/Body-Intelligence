part of 'intelligence_center_page.dart';

final class _CoachSettingReceiptReference {
  const _CoachSettingReceiptReference({
    required this.actionId,
    required this.operationId,
    required this.toolId,
    required this.entityId,
    required this.payload,
  });

  final String actionId;
  final String operationId;
  final String toolId;
  final String entityId;
  final Map<dynamic, dynamic> payload;

  static _CoachSettingReceiptReference? fromMessage(
    IntelligenceMessage message,
  ) {
    if (message.role != IntelligenceMessageRole.bil ||
        message.kind != IntelligenceMessageKind.action) {
      return null;
    }
    const entities = <String, String>{
      'set_theme_mode': 'theme_mode',
      'set_language': 'locale',
    };
    for (final evidence in message.evidence) {
      try {
        final value = jsonDecode(evidence);
        if (value is! Map ||
            value['source'] != 'ai_coach' ||
            value['committed'] != true ||
            value['verified'] != true ||
            value['undoable'] != true ||
            value['undone_at'] != null ||
            value['entity_type'] != 'app_setting') {
          continue;
        }
        final actionId = value['action_id'];
        final operationId = value['operation_id'];
        final toolId = value['tool_id'];
        final entityId = value['entity_id'];
        final before = value['before'];
        final after = value['after'];
        final completedAt = value['completed_at'];
        if (actionId is! String ||
            actionId.isEmpty ||
            operationId is! String ||
            !CoachActionAdmission.validOperationId(operationId) ||
            toolId is! String ||
            entities[toolId] != entityId ||
            entityId is! String ||
            before is! Map ||
            after is! Map ||
            before['value'] is! String ||
            before['revision'] is! int ||
            after['value'] is! String ||
            after['revision'] is! int ||
            completedAt is! String ||
            DateTime.tryParse(completedAt) == null) {
          continue;
        }
        return _CoachSettingReceiptReference(
          actionId: actionId,
          operationId: operationId,
          toolId: toolId,
          entityId: entityId,
          payload: value,
        );
      } on Object {
        // Plain evidence and damaged history are not executable commands.
      }
    }
    return null;
  }

  bool matches(BilActionReceipt verified) {
    final canonical = verified.toStructuredPayload();
    return const <String>[
      'tool_id',
      'operation_id',
      'entity_type',
      'entity_id',
      'completed_at',
      'before',
      'after',
    ].every(
      (key) => _sameRecoveredSettingEvidence(payload[key], canonical[key]),
    );
  }
}

bool _sameRecoveredSettingEvidence(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) &&
              _sameRecoveredSettingEvidence(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (!_sameRecoveredSettingEvidence(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

extension _CoachSettingsRecovery on _IntelligenceCenterPageState {
  Future<void> _restoreCoachSettingsUndoOperations(
    List<IntelligenceMessage> restored,
  ) async {
    if (!mounted || !conversationReady) return;
    final candidates = [
      for (final message in restored.reversed)
        if (_CoachSettingReceiptReference.fromMessage(message)
            case final reference?)
          (message: message, reference: reference),
    ];
    if (candidates.isEmpty) return;

    final epoch = conversationPersistenceEpoch;
    final conversationId = activeConversationId;
    bool visitIsCurrent() =>
        mounted &&
        conversationReady &&
        conversationPersistenceEpoch == epoch &&
        activeConversationId == conversationId;
    final recoveredOperationIds = {
      for (final operation in undoOperations.values)
        ?operation.receipt.operationId,
    };

    for (final candidate in candidates) {
      if (!visitIsCurrent()) return;
      final reference = candidate.reference;
      if (recoveredOperationIds.contains(reference.operationId)) continue;
      try {
        final controller = ref.read(appSettingsProvider.notifier);
        final operation = await controller.readCoachSettingOperation(
          reference.operationId,
        );
        if (!visitIsCurrent() || operation == null || !operation.canUndo) {
          continue;
        }
        final settings = ref.read(appSettingsProvider);
        if (settings.revision != operation.afterRevision ||
            settings.fieldValue(operation.field) != operation.afterValue) {
          continue;
        }
        final expectedTool = operation.field == 'themeMode'
            ? 'set_theme_mode'
            : 'set_language';
        if (reference.toolId != expectedTool) continue;
        final action = IntelligenceAction(
          id: reference.actionId,
          toolId: reference.toolId,
          operationId: reference.operationId,
          type: operation.field == 'themeMode'
              ? IntelligenceActionType.setThemeMode
              : IntelligenceActionType.setLanguage,
          label: reference.actionId,
          requiresConfirmation: true,
        );
        final receipt = _coachSettingReceipt(action, operation);
        if (!reference.matches(receipt) ||
            !messages.any((message) => identical(message, candidate.message)) ||
            undoOperations.containsKey(candidate.message.id)) {
          continue;
        }
        _updateState(() {
          undoOperations[candidate.message.id] = _CoachUndoOperation(
            receipt: receipt,
            undoReadback: (checkWritePermission) async {
              final undone = await controller.undoCoachSetting(
                operationId: operation.operationId,
                checkWritePermission: () {
                  checkWritePermission();
                  return true;
                },
              );
              return _coachSettingReceipt(action, undone, undone: true);
            },
          );
        });
        recoveredOperationIds.add(reference.operationId);
      } on Object {
        // Settings history remains readable if one journal entry is missing or
        // stale. Never repair or replay a write while restoring a conversation.
      }
    }
  }
}
