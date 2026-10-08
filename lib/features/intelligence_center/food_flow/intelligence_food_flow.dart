part of '../presentation/intelligence_center_page.dart';

extension _CoachFoodConversationFlow on _IntelligenceCenterPageState {
  Future<bool> _tryHandleCoachFoodTurn({
    required String text,
    required String localeTag,
  }) async {
    final witness = _captureCoachMealOwner();
    final ownerKey = LocalDatabaseScope.keyForOwner(
      witness.database.localOwnerId,
    );
    final epoch = conversationPersistenceEpoch;
    final foodScope = CoachFoodOwnerScope(
      captured: CoachFoodOwnerStamp(ownerKey: ownerKey, epoch: epoch),
      readCurrent: () => CoachFoodOwnerStamp(
        ownerKey: ownerKey,
        epoch: witness.scope.isCurrent ? epoch : epoch + 1,
      ),
    );
    try {
      final host = CoachFoodHost(
        foods: ref.read(foodRepositoryProvider),
        meals: witness.repository,
        preferences: ref.read(preferencesRepositoryProvider),
      );
      final result = await host.prepare(
        input: text,
        referenceLocal: ref.read(intelligenceConversationClockProvider)(),
        localeTag: localeTag,
        ownerScope: foodScope,
        preferredTargetItemId: _latestCoachFoodTargetItemId(),
      );
      foodScope.check();
      witness.scope.check(witness.database.localOwnerId);
      switch (result) {
        case CoachFoodHostIgnored():
          return false;
        case CoachFoodHostClarification():
          _appendCoachFoodMessage(
            result.message,
            evidence: ['food_clarification:${result.code}'],
          );
          return true;
        case CoachFoodPersonalRuleSaved():
          _appendCoachFoodMessage(
            localeTag.toLowerCase().startsWith('ar')
                ? 'تم اعتماد قاعدة Personal BIL لـ ${result.rule.snapshot.name} بالإصدار ${result.rule.revision}. ستبقى السجلات القديمة على لقطاتها السابقة.'
                : 'Personal BIL rule approved for ${result.rule.snapshot.name} at revision ${result.rule.revision}. Older logs keep their previous snapshots.',
            evidence: [
              jsonEncode({
                'schema': 'bil.personal.food-rule.receipt.v1',
                'owner_key': result.rule.ownerKey,
                'rule_id': result.rule.id,
                'revision': result.rule.revision,
                'approval_digest': result.rule.approvalDigest,
              }),
            ],
          );
          ref.invalidate(coachContextSnapshotProvider);
          return true;
        case CoachFoodPersonalRecipeRuleSaved():
          _appendCoachFoodMessage(
            localeTag.toLowerCase().startsWith('ar')
                ? 'تم اعتماد وصفة Personal BIL لـ ${result.rule.savedRecipe.recipe.name} بالإصدار ${result.rule.revision} وحصة ${result.rule.servingGrams.toStringAsFixed(0)}غ. السجلات القديمة تبقى على لقطاتها السابقة.'
                : 'Personal BIL recipe approved for ${result.rule.savedRecipe.recipe.name} at revision ${result.rule.revision} with a ${result.rule.servingGrams.toStringAsFixed(0)} g serving. Older logs keep their previous snapshots.',
            evidence: [
              jsonEncode({
                'schema': 'bil.personal.recipe-rule.receipt.v1',
                'owner_key': result.rule.ownerKey,
                'rule_id': result.rule.id,
                'revision': result.rule.revision,
                'approval_digest': result.rule.approvalDigest,
                'recipe_fingerprint':
                    result.rule.savedRecipe.recipe.fingerprint,
              }),
            ],
          );
          ref.invalidate(coachContextSnapshotProvider);
          return true;
        case CoachFoodActionDraft():
          final action = _coachFoodAction(result, localeTag);
          final binding = const CoachActionAdmission().bind(
            action,
            requireOperationId: true,
          );
          if (binding == null) {
            throw const CoachMealConflict(
              CoachMealConflictReason.operationMismatch,
            );
          }
          // Freeze UUID/revision/owner before the confirmation card appears.
          final prepared = await _prepareCoachMealAction(binding.action);
          if (prepared == null) {
            throw const CoachMealConflict(
              CoachMealConflictReason.operationMismatch,
            );
          }
          foodScope.check();
          witness.scope.check(witness.database.localOwnerId);
          await _showCoachFoodReview(
            draft: result,
            action: binding.action,
            prepared: prepared,
            localeTag: localeTag,
          );
          return true;
      }
    } on CoachFoodContractError catch (error) {
      if (!mounted) return true;
      _appendCoachFoodMessage(
        localeTag.toLowerCase().startsWith('ar')
            ? 'تعذر تجهيز تسجيل الطعام بأمان (${error.code}). لم تتغير بياناتك.'
            : 'The food action could not be prepared safely (${error.code}). Your data was not changed.',
        evidence: ['food_contract:${error.code}'],
      );
      return true;
    } finally {
      witness.dispose();
    }
  }

  IntelligenceAction _coachFoodAction(
    CoachFoodActionDraft draft,
    String localeTag,
  ) {
    final arabicTurn = localeTag.toLowerCase().startsWith('ar');
    return switch (draft.kind) {
      CoachFoodDraftKind.logFoods => IntelligenceAction(
        id: 'log-foods',
        toolId: 'log_foods',
        operationId: draft.operationId,
        type: IntelligenceActionType.logFoods,
        label: arabicTurn ? 'مراجعة وحفظ الأطعمة' : 'Review and save foods',
        requiresConfirmation: true,
        payload: draft.payload,
      ),
      CoachFoodDraftKind.replaceMealItem => IntelligenceAction(
        id: 'replace-meal-item',
        toolId: 'replace_meal_item',
        operationId: draft.operationId,
        type: IntelligenceActionType.replaceMealItem,
        label: arabicTurn ? 'مراجعة تصحيح الطعام' : 'Review food correction',
        requiresConfirmation: true,
        payload: draft.payload,
      ),
    };
  }

  Future<void> _showCoachFoodReview({
    required CoachFoodActionDraft draft,
    required IntelligenceAction action,
    required _PreparedCoachMealAction prepared,
    required String localeTag,
  }) async {
    if (!mounted) return;
    final operationId = draft.operationId;
    var completed = false;
    BuildContext? reviewSheetContext;
    void revokeReview() {
      prepared.scope.cancel();
      final sheet = reviewSheetContext;
      // An account transition invalidates the old review permanently. Pop
      // only our still-current sheet so it cannot be confirmed after A-B-A.
      if (sheet != null &&
          sheet.mounted &&
          ModalRoute.of(sheet)?.isCurrent == true) {
        Navigator.of(sheet).pop();
      }
    }

    final ownerWitness = ref.read(coachNativeOwnerWitnessProvider);
    final reviewOwner = prepared.database.localOwnerId;
    final reviewWatcher = ownerWitness?.changes.listen((owner) {
      if (owner != reviewOwner) revokeReview();
    }, onError: (Object _, StackTrace _) => revokeReview());
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          reviewSheetContext = sheetContext;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoachFoodReviewCard(
                    review: draft.review,
                    operationId: operationId,
                    mealType: draft.mealType,
                    day: draft.day,
                    ownerIsCurrent: () => prepared.scope.isCurrent,
                    onConfirm: () async {
                      final ok = await _executeAction(
                        action,
                        confirmationAlreadyProvided: true,
                      );
                      if (!ok) {
                        throw StateError('coach_food_commit_not_completed');
                      }
                      completed = true;
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    onAdjust: () async {
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      _appendCoachFoodMessage(
                        localeTag.toLowerCase().startsWith('ar')
                            ? 'لم أحفظ شيئًا. اكتب الطعام أو الكمية المصححة وسأجهز مراجعة جديدة.'
                            : 'Nothing was saved. Tell me the corrected food or amount and I will prepare a new review.',
                        evidence: const ['food_review_adjusted'],
                      );
                    },
                  ),
                  TextButton(
                    key: Key('coach-food-review-reject-$operationId'),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(
                      intelligenceText(
                        sheetContext,
                        'Cancel — do not save',
                        'إلغاء — لا تحفظ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      reviewSheetContext = null;
      unawaited(reviewWatcher?.cancel());
      if (!completed) {
        preparedMealActions.remove(operationId)?.dispose();
      }
    }
  }

  int? _latestCoachFoodTargetItemId() {
    for (final message in messages.reversed) {
      for (final evidence in message.evidence.reversed) {
        try {
          final value = jsonDecode(evidence);
          if (value is! Map ||
              value['source'] != 'ai_coach' ||
              value['verified'] != true ||
              value['entity_type'] != 'meal_item' ||
              !const {
                'log_foods',
                'replace_meal_item',
                'update_meal_item',
                'move_meal_item',
              }.contains(value['tool_id'])) {
            continue;
          }
          final id = int.tryParse(value['entity_id']?.toString() ?? '');
          if (id != null && id > 0) return id;
        } on Object {
          // Non-JSON evidence is ordinary text.
        }
      }
    }
    return null;
  }

  void _appendCoachFoodMessage(
    String text, {
    List<String> evidence = const [],
  }) {
    if (!mounted) return;
    final now = ref.read(intelligenceConversationClockProvider)();
    _updateState(() {
      messages.add(
        IntelligenceMessage(
          id: 'coach-food-${now.microsecondsSinceEpoch}',
          role: IntelligenceMessageRole.bil,
          kind: IntelligenceMessageKind.coach,
          text: text,
          createdAt: now,
          evidence: evidence,
          confidence: 1,
        ),
      );
    });
    _scrollToLatest();
    unawaited(_saveConversation());
  }

  Widget? _coachFoodReceiptWidget(IntelligenceMessage message) {
    final operation = undoOperations[message.id];
    final commit = operation?.mealCommit;
    final receipt = operation?.receipt;
    if (commit == null ||
        receipt == null ||
        !const {
          CoachMealCommandKind.foods,
          CoachMealCommandKind.replacement,
        }.contains(commit.kind)) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: CoachFoodReceiptCard(
        commit: commit,
        receipt: receipt,
        ownerIsCurrent: () =>
            LocalDatabaseScope.keyForOwner(
              ref.read(databaseProvider).localOwnerId,
            ) ==
            commit.ownerScope,
        onEdit: (snapshot) async {
          question.text =
              localeTagFor(Localizations.localeOf(context)).startsWith('ar')
              ? 'صحح ${snapshot.foodName}'
              : 'Correct ${snapshot.foodName}';
        },
        onUndo: () => _undoCoachAction(message.id),
        onViewDailyLog: () => _openCoachRoute('/daily-log?focus=meal'),
      ),
    );
  }
}

String localeTagFor(Locale locale) => BilLocalePolicy.canonicalTag(locale);
