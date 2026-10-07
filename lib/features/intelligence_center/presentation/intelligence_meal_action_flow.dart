part of 'intelligence_center_page.dart';

extension _CoachMealActionFlow on _IntelligenceCenterPageState {
  Future<bool> _commitPreparedCoachMealAction(
    IntelligenceAction action,
    _PreparedCoachMealAction prepared,
  ) async {
    final result = await prepared.repository.commitCoachMeal(
      command: prepared.command!,
      scope: prepared.scope,
    );
    if (!mounted || !prepared.scope.isCurrent) return true;
    _refreshCommittedCoachMeals();
    final receipt = _coachMealReceipt(action.id, result);
    _appendToolReceipt(
      _coachMealResultText(result),
      receipt: receipt,
      undoReadback: result.canUndo
          ? (checkWritePermission) => _undoCommittedCoachMeal(
              actionId: action.id,
              result: result,
              owner: prepared.owner,
              checkWritePermission: checkWritePermission,
            )
          : null,
    );
    if (result.state == CoachMealResultState.committed) {
      _showActionCompleted(tr('Meal updated.', 'تم تحديث الوجبة.'));
    }
    return true;
  }

  Future<BilActionReceipt> _undoCommittedCoachMeal({
    required String actionId,
    required CoachMealCommit result,
    required _CoachMealOwnerHandle owner,
    required void Function() checkWritePermission,
  }) async {
    final undone = await owner.repository.undoCoachMeal(
      operationId: result.operationId,
      toolId: result.toolId,
      argumentsDigest: result.argumentsDigest,
      scope: owner.scope,
      checkWritePermission: checkWritePermission,
    );
    owner.scope.check(owner.database.localOwnerId, committed: true);
    _refreshCommittedCoachMeals();
    return _coachMealReceipt(actionId, undone, undo: true);
  }

  void _refreshCommittedCoachMeals() {
    ref.invalidate(dailyMealsProvider);
    ref.invalidate(selectedDailyLedgerProvider);
    ref.invalidate(coachContextSnapshotProvider);
  }

  BilActionReceipt _coachMealReceipt(
    String actionId,
    CoachMealCommit result, {
    bool undo = false,
  }) => BilActionReceipt(
    actionId: actionId,
    operationId: result.operationId,
    toolId: result.toolId,
    committed: true,
    completedAt: result.committedAt,
    entityType: result.after.length == 1 ? 'meal_item' : 'meal',
    entityId: result.after.length == 1
        ? result.after.single.item.id.toString()
        : result.after.first.meal.id.toString(),
    refreshTargets: const {
      'dailyMeals',
      'dailyLedger',
      'dashboard',
      'coachContext',
    },
    before: undo
        ? {
            'items': result.after
                .map((row) => row.toReceiptPayload())
                .toList(growable: false),
          }
        : result.beforePayload,
    after: undo
        ? {
            'state': result.state.name,
            'items': result.current
                .map((row) => row?.toReceiptPayload())
                .toList(growable: false),
            'arguments_digest': result.argumentsDigest,
          }
        : result.afterPayload,
    undoable: !undo && result.canUndo,
    undoneAt: result.undoneAt,
  );

  String _coachMealResultText(CoachMealCommit result) {
    if (result.state == CoachMealResultState.undone) {
      return tr(
        'This action was already undone. Nothing was added again.',
        'سبق التراجع عن هذا الإجراء. لم تُضف البيانات مجددًا.',
      );
    }
    if (result.state == CoachMealResultState.modified) {
      return tr(
        'This meal changed since the action was prepared. Review it again.',
        'تغيّرت هذه الوجبة منذ تجهيز الإجراء. راجعها مجددًا.',
      );
    }
    final saved = result.after.first;
    final item = saved.item;
    switch (result.kind) {
      case CoachMealCommandKind.foods:
        return tr('Meal saved locally.', 'تم حفظ الوجبة محليًا.');
      case CoachMealCommandKind.replacement:
        return tr('Meal updated.', 'تم تحديث الوجبة.');
      case CoachMealCommandKind.quickMacros:
        final payload = saved.toReceiptPayload();
        if (payload['calories'] == null) {
          return tr(
            'Macro entry saved. Calories are unknown.',
            'حُفظ إدخال المغذيات. السعرات غير معروفة.',
          );
        }
        if (payload['calories'] != null &&
            payload['protein'] == null &&
            payload['carbohydrates'] == null &&
            payload['fat'] == null) {
          return tr(
            'Calorie-only entry saved. Other nutrients are unknown.',
            'حُفظ إدخال السعرات فقط. المغذيات الأخرى غير معروفة.',
          );
        }
        return tr(
          'Quick macros added to ${saved.meal.type}: ${item.calories.round()} kcal.',
          'تمت إضافة المغذيات السريعة إلى ${saved.meal.type}: ${item.calories.round()} سعرة.',
        );
      case CoachMealCommandKind.quantity:
        return tr(
          'Meal item ${item.id} updated to ${item.quantity.toStringAsFixed(1)} g.',
          'تم تحديث عنصر الوجبة ${item.id} إلى ${item.quantity.toStringAsFixed(1)} غ.',
        );
      case CoachMealCommandKind.remove:
        return tr(
          'Meal item ${item.id} deleted.',
          'تم حذف عنصر الوجبة ${item.id}.',
        );
      case CoachMealCommandKind.move:
        return tr(
          'Meal item ${item.id} moved to ${saved.meal.type}.',
          'تم نقل عنصر الوجبة ${item.id} إلى ${saved.meal.type}.',
        );
    }
  }

  void _showCoachMealConflict(CoachMealConflict error) {
    if (!mounted) return;
    // An earlier success toast must not queue this actionable failure behind it.
    ScaffoldMessenger.of(context).clearSnackBars();
    final message = switch (error.reason) {
      CoachMealConflictReason.ownerChanged => tr(
        'The account changed. Reopen AI Coach and try again.',
        'تغيّر الحساب. افتح المدرب الذكي مجددًا وحاول مرة أخرى.',
      ),
      CoachMealConflictReason.closedDay => tr(
        'This day is closed. Reopen it in Daily Log before making changes.',
        'هذا اليوم مغلق. أعد فتحه في السجل اليومي قبل التعديل.',
      ),
      CoachMealConflictReason.staleItem ||
      CoachMealConflictReason.missingMeal => tr(
        'This meal changed since the action was prepared. Review it again.',
        'تغيّرت هذه الوجبة منذ تجهيز الإجراء. راجعها مجددًا.',
      ),
      _ =>
        error.committed
            ? tr(
                'The change was saved, but its receipt could not be loaded. Retry to read the saved result.',
                'حُفظ التغيير، لكن تعذر تحميل الإيصال. أعد المحاولة لقراءة النتيجة المحفوظة.',
              )
            : tr(
                'The action was not completed. Your data stayed unchanged; review the value and try again.',
                'لم يُنفذ الإجراء. بقيت بياناتك دون تغيير؛ راجع القيمة وحاول مجددًا.',
              ),
    };
    _showActionCompleted(message);
  }
}
