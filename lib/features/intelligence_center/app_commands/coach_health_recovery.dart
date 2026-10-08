part of '../presentation/intelligence_center_page.dart';

/// The existing Native journal owns recovery metadata. Conversation messages
/// are only a presentation of a fresh journal/row read, never a second journal.
extension _CoachHealthReceiptRecovery on _IntelligenceCenterPageState {
  Future<String> _healthRecoveryConversationForCommit(
    _PreparedCoachNativeAction prepared,
  ) async {
    final conversationId = activeConversationId;
    if (conversationId == null || conversationId.isEmpty) {
      throw const CoachNativeConflict(
        CoachNativeConflictReason.operationMismatch,
      );
    }
    prepared.scope.check(prepared.database.localOwnerId);
    // A crash after commit must still reopen the same conversation. The
    // existing save is best effort, so verify its durable identity explicitly
    // before permitting this health mutation to begin.
    await _saveConversation();
    prepared.scope.check(prepared.database.localOwnerId);
    final storedId = await prepared.repository.preferences.get(
      'intelligenceConversationActiveIdV1',
    );
    prepared.scope.check(prepared.database.localOwnerId);
    if (activeConversationId != conversationId ||
        storedId != conversationId ||
        conversationPersistenceEpoch != prepared.conversationEpoch) {
      throw const CoachNativeConflict(
        CoachNativeConflictReason.readbackUnavailable,
      );
    }
    return conversationId;
  }

  bool _healthReceiptMatchesMessage(
    IntelligenceMessage message,
    BilActionReceipt receipt,
  ) {
    if (message.role != IntelligenceMessageRole.bil ||
        message.kind != IntelligenceMessageKind.action) {
      return false;
    }
    final canonical = receipt.toStructuredPayload();
    for (final evidence in message.evidence) {
      try {
        final value = jsonDecode(evidence);
        if (value is Map &&
            value['source'] == 'ai_coach' &&
            value['verified'] == true &&
            value['committed'] == true &&
            const [
              'tool_id',
              'operation_id',
              'entity_type',
              'entity_id',
              'completed_at',
              'before',
              'after',
            ].every(
              (key) => _sameRecoveredNativeEvidence(value[key], canonical[key]),
            )) {
          return true;
        }
      } on Object {
        // Ordinary text and malformed evidence cannot acknowledge a receipt.
      }
    }
    return false;
  }

  Future<void> _acknowledgePersistedHealthReceipt({
    required CoachNativeCommit result,
    required BilActionReceipt receipt,
    required CoachNativeCommandRepository repository,
    required CoachNativeOwnerScope scope,
    required String conversationId,
    required int conversationEpoch,
  }) async {
    try {
      if (result.kind != CoachNativeCommandKind.health) return;
      await _saveConversation();
      scope.check(repository.database.localOwnerId, committed: true);
      if (conversationPersistenceEpoch != conversationEpoch ||
          activeConversationId != conversationId) {
        return;
      }
      final raw = await repository.preferences.get(
        'intelligenceConversationV1',
      );
      scope.check(repository.database.localOwnerId, committed: true);
      final storedId = await repository.preferences.get(
        'intelligenceConversationActiveIdV1',
      );
      scope.check(repository.database.localOwnerId, committed: true);
      if (storedId != conversationId || raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List ||
          !decoded.whereType<Map>().any((value) {
            try {
              return _healthReceiptMatchesMessage(
                IntelligenceMessage.fromJson(Map<String, Object?>.from(value)),
                receipt,
              );
            } on Object {
              return false;
            }
          })) {
        return;
      }
      await repository.markHealthReceiptPersisted(
        operationId: result.operationId,
        scope: scope,
        conversationId: conversationId,
      );
    } on Object {
      // The atomic journal locator remains pending until a later visit can
      // prove that a truthful receipt is durable. Never roll back saved data
      // because the optional conversation projection could not be persisted.
    }
  }

  Future<void> _restorePendingCoachHealthReceipts() async {
    final conversationId = activeConversationId;
    if (!mounted || !conversationReady || conversationId == null) return;
    final epoch = conversationPersistenceEpoch;
    _RecoveredCoachNativeOwner? owner;
    var retained = false;
    try {
      final visit = owner = _captureRecoveredCoachNativeOwner();
      recoveredNativeOwners.add(visit);
      final operationIds = await visit.repository
          .listPendingHealthReceiptOperationIds(
            scope: visit.scope,
            conversationId: conversationId,
          );
      visit.scope.check(visit.database.localOwnerId);
      for (final operationId in operationIds.reversed) {
        if (!mounted ||
            !conversationReady ||
            activeConversationId != conversationId ||
            conversationPersistenceEpoch != epoch) {
          break;
        }
        try {
          final result = await visit.repository.readOperation(
            operationId: operationId,
            scope: visit.scope,
          );
          visit.scope.check(visit.database.localOwnerId);
          if (result == null || result.kind != CoachNativeCommandKind.health) {
            continue;
          }
          final actionId = 'recovered-health-$operationId';
          final receipt = _coachNativeReceipt(
            actionId,
            result,
            undo: result.state == CoachNativeResultState.undone,
          );
          if (!messages.any(
            (message) => _healthReceiptMatchesMessage(message, receipt),
          )) {
            _appendToolReceipt(
              _coachNativeResultText(result),
              receipt: receipt,
              undoReadback: result.canUndo
                  ? (checkWritePermission) => _undoRecoveredCoachNative(
                      actionId: actionId,
                      result: result,
                      owner: visit,
                      checkWritePermission: checkWritePermission,
                    )
                  : null,
            );
            retained = retained || result.canUndo;
          }
          _refreshCommittedCoachNative(result.kind);
          await _acknowledgePersistedHealthReceipt(
            result: result,
            receipt: receipt,
            repository: visit.repository,
            scope: visit.scope,
            conversationId: conversationId,
            conversationEpoch: epoch,
          );
          visit.scope.check(visit.database.localOwnerId);
        } on Object {
          if (!visit.scope.isCurrent) break;
          // One unavailable/corrupt operation must not conceal other verified
          // receipts. It remains pending and is never automatically replayed.
        }
      }
    } on Object {
      // Reading the conversation remains available during a recovery outage.
    } finally {
      if (!retained) {
        recoveredNativeOwners.remove(owner);
        owner?.dispose();
      }
    }
  }
}
