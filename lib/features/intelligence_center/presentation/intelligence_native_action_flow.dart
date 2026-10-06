part of 'intelligence_center_page.dart';

extension _CoachNativeActionFlow on _IntelligenceCenterPageState {
  Future<bool> _commitPreparedCoachNativeAction(
    IntelligenceAction action,
    _PreparedCoachNativeAction? prepared,
  ) async {
    if (prepared == null) {
      if (action.type == IntelligenceActionType.addWeight &&
          action.payload.isEmpty) {
        await _openCoachRoute('/daily-check-in');
        return true;
      }
      throw const CoachNativeConflict(
        CoachNativeConflictReason.operationMismatch,
      );
    }
    prepared.scope.check(prepared.database.localOwnerId);
    prepared.confirmedCommitInFlight = true;
    try {
      final result = await prepared.repository.commit(
        command: prepared.command!,
        scope: prepared.scope,
      );
      await _retireDurableAction(action);
      if (!mounted ||
          conversationPersistenceEpoch != prepared.conversationEpoch ||
          !prepared.scope.isCurrent) {
        return true;
      }
      _refreshCommittedCoachNative(result.kind);
      _syncCommittedCoachMemory(prepared, result, undo: false);
      _appendToolReceipt(
        _coachNativeResultText(result),
        receipt: _coachNativeReceipt(action.id, result),
        undoReadback: result.canUndo
            ? () async {
                final undone = await prepared.repository.undo(
                  operationId: result.operationId,
                  toolId: result.toolId,
                  argumentsDigest: result.argumentsDigest,
                  scope: prepared.scope,
                );
                prepared.scope.check(
                  prepared.database.localOwnerId,
                  committed: true,
                );
                if (mounted &&
                    conversationPersistenceEpoch ==
                        prepared.conversationEpoch) {
                  _refreshCommittedCoachNative(undone.kind);
                  _syncCommittedCoachMemory(prepared, undone, undo: true);
                }
                return _coachNativeReceipt(action.id, undone, undo: true);
              }
            : null,
      );
      return true;
    } on CoachNativeConflict catch (error) {
      if (error.committed) {
        completedActionOperationIds.add(action.operationId!);
        await _retireDurableAction(action);
      }
      if (mounted &&
          conversationPersistenceEpoch == prepared.conversationEpoch) {
        _showCoachNativeConflict(error);
      }
      return false;
    } finally {
      prepared.finishCommit();
    }
  }

  void _refreshCommittedCoachNative(CoachNativeCommandKind kind) {
    ref.invalidate(coachContextSnapshotProvider);
    switch (kind) {
      case CoachNativeCommandKind.water:
        ref.invalidate(dailyWaterProvider);
      case CoachNativeCommandKind.weight:
        ref.invalidate(weightHistoryProvider);
      case CoachNativeCommandKind.goal:
        ref.invalidate(userProfileProvider);
        ref.invalidate(activeGoalProvider);
      case CoachNativeCommandKind.measurements:
        ref.invalidate(bodyMeasurementHistoryProvider);
      case CoachNativeCommandKind.memory:
        break;
    }
  }

  void _syncCommittedCoachMemory(
    _PreparedCoachNativeAction prepared,
    CoachNativeCommit result, {
    required bool undo,
  }) {
    if (result.kind != CoachNativeCommandKind.memory) return;
    final id = result.command.resolved['memoryId']! as String;
    unawaited(
      prepared.memoryRepository.syncCommittedChange(
        id: id,
        expectedLocal: (undo ? result.current : result.after).memory(id),
        isCurrentOwner: () => prepared.scope.isCurrent,
      ),
    );
  }

  BilActionReceipt _coachNativeReceipt(
    String actionId,
    CoachNativeCommit result, {
    bool undo = false,
  }) {
    final after = result.after;
    final entityId = switch (result.kind) {
      CoachNativeCommandKind.water => after.water!.id.toString(),
      CoachNativeCommandKind.weight => after.weight!.id.toString(),
      CoachNativeCommandKind.goal => after.goal!.id.toString(),
      CoachNativeCommandKind.measurements => after.measurement!.id.toString(),
      CoachNativeCommandKind.memory =>
        result.command.resolved['memoryId']! as String,
    };
    final entityType = switch (result.kind) {
      CoachNativeCommandKind.water => 'water_entry',
      CoachNativeCommandKind.weight => 'weight_entry',
      CoachNativeCommandKind.goal => 'goal',
      CoachNativeCommandKind.measurements => 'body_measurement',
      CoachNativeCommandKind.memory => 'coach_memory',
    };
    return BilActionReceipt(
      actionId: actionId,
      operationId: result.operationId,
      toolId: result.toolId,
      committed: true,
      completedAt: result.committedAt,
      entityType: entityType,
      entityId: entityId,
      refreshTargets: const {
        'dashboard',
        'coachContext',
        'dailyWater',
        'weightHistory',
        'bodyMeasurements',
        'profile',
        'goal',
      },
      before: (undo ? result.after : result.before).receiptPayload(
        result.command,
      ),
      after: {
        ...(undo ? result.current : result.after).receiptPayload(
          result.command,
        ),
        'state': result.state.name,
        'arguments_digest': result.argumentsDigest,
      },
      undoable: !undo && result.canUndo,
      undoneAt: result.undoneAt,
    );
  }

  String _coachNativeResultText(CoachNativeCommit result) {
    if (result.state == CoachNativeResultState.undone) {
      return tr(
        'This action was already undone. Nothing was added again.',
        'سبق التراجع عن هذا الإجراء. لم تُضف البيانات مجددًا.',
      );
    }
    if (result.state == CoachNativeResultState.modified) {
      return tr(
        'This record changed since the action was prepared. Review it again.',
        'تغير هذا السجل منذ تجهيز الإجراء. راجعه مجددًا.',
      );
    }
    switch (result.kind) {
      case CoachNativeCommandKind.water:
        final amount = result.after.water!.amountMl;
        return tr(
          'Logged $amount ml of water.',
          'تم تسجيل $amount مل من الماء.',
        );
      case CoachNativeCommandKind.weight:
        final value = result.after.weight!.weight;
        return tr(
          'Logged weight: ${value.toStringAsFixed(1)} kg.',
          'تم تسجيل الوزن: ${value.toStringAsFixed(1)} كغ.',
        );
      case CoachNativeCommandKind.goal:
        final target = result.after.profile!.targetWeight;
        return tr(
          'Target weight updated to ${target.toStringAsFixed(1)} kg.',
          'تم تحديث الوزن المستهدف إلى ${target.toStringAsFixed(1)} كغ.',
        );
      case CoachNativeCommandKind.measurements:
        final date = result.after.measurement!.date;
        return tr(
          'Body measurements saved for ${_coachDateLabel(date)}.',
          'تم حفظ قياسات الجسم لتاريخ ${_coachDateLabel(date)}.',
        );
      case CoachNativeCommandKind.memory:
        return tr(
          'BIL will remember this. You can review or remove it any time.',
          'سيتذكر BIL هذه المعلومة. يمكنك مراجعتها أو حذفها في أي وقت.',
        );
    }
  }

  void _showCoachNativeConflict(CoachNativeConflict error) {
    final text = error.committed
        ? tr(
            'The action was saved, but its current state could not be verified. Review your data before retrying.',
            'حُفظ الإجراء، لكن تعذر التحقق من حالته الحالية. راجع بياناتك قبل المحاولة مجددًا.',
          )
        : switch (error.reason) {
            CoachNativeConflictReason.ownerChanged => tr(
              'Your account changed. Prepare this action again for the current account.',
              'تغير حسابك. جهز هذا الإجراء مجددًا للحساب الحالي.',
            ),
            CoachNativeConflictReason.staleRecord => tr(
              'This record changed since the action was prepared. Review it again.',
              'تغير هذا السجل منذ تجهيز الإجراء. راجعه مجددًا.',
            ),
            CoachNativeConflictReason.operationMismatch ||
            CoachNativeConflictReason.invalidJournal => tr(
              'The action could not be validated. Ask Coach to prepare it again.',
              'تعذر التحقق من الإجراء. اطلب من المدرب إعداده مرة أخرى.',
            ),
            CoachNativeConflictReason.missingRecord ||
            CoachNativeConflictReason.readbackUnavailable => tr(
              'The action was not completed. Your data stayed unchanged; review the value and try again.',
              'لم يُنفذ الإجراء. بقيت بياناتك دون تغيير؛ راجع القيمة وحاول مجددًا.',
            ),
          };
    ScaffoldMessenger.of(context).clearSnackBars();
    _showActionCompleted(text);
  }
}
