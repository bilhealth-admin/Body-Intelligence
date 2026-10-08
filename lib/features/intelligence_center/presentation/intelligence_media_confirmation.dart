part of 'intelligence_center_page.dart';

/// Proposed shared host for BIL-00/BIL-01 integration. Input is a claimed,
/// owner-bound Food V2 review; output is completion/cancellation, never a
/// fabricated receipt. All writes use the existing BASE meal transaction.
extension _CoachMediaConfirmation on _IntelligenceCenterPageState {
  Future<void> _handoffMediaFoodReview(
    _CoachMediaPageRequest request,
    CoachFoodReview initialReview,
  ) async {
    if (!await _mediaRequestCurrent(request) || !mounted) return;
    initialReview.checkOwner(request.attempt.ownerScope);
    var review = initialReview;
    final selectedDay = ref.read(selectedLogDateProvider);
    var day = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    // A visible, editable review bucket; no claim about meal timing is inferred
    // from an image or barcode.
    var mealType = 'snack';
    var committing = false;
    CoachMealCommand? command;
    CoachMealCommit? committed;
    BilActionReceipt? receipt;
    var openDailyLog = false;

    bool writeAllowed() =>
        mounted &&
        request.attempt.isCurrent &&
        ref.read(coachActionPermissionModeProvider) !=
            CoachActionPermissionMode.readOnly;
    void checkWritePermission() {
      if (!writeAllowed()) {
        throw const CoachMealConflict(CoachMealConflictReason.ownerChanged);
      }
    }

    // Permission/visit validity is rechecked inside the existing transaction,
    // including immediately before its journal commit. A revoke cannot become
    // authorized again through a later provider value.
    final transactionScope = CoachMealOwnerScope(
      ownerId: request.owner.database.localOwnerId,
      isCurrent: () => request.owner.scope.isCurrent && writeAllowed(),
    );
    // Invalidate the visible review immediately when auth delivers an owner
    // transition. The transaction scope already fails closed, but a stale
    // Confirm button must not remain visible after A -> B -> A either.
    StateSetter? refreshReview;
    final witness = ref.read(coachNativeOwnerWitnessProvider);
    final reviewOwner = request.owner.database.localOwnerId;
    final ownerListener = witness?.changes.listen(
      (nextOwner) {
        if (nextOwner == reviewOwner) return;
        request.attempt.cancel();
        if (mounted) refreshReview?.call(() {});
      },
      onError: (Object _, StackTrace _) {
        request.attempt.cancel();
        if (mounted) refreshReview?.call(() {});
      },
    );
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) {
            refreshReview = updateDialog;
            Future<void> navigateToLog() async {
              if (!await _mediaRequestCurrent(request) ||
                  !dialogContext.mounted) {
                return;
              }
              openDailyLog = true;
              Navigator.pop(dialogContext);
            }

            return PopScope(
              canPop: !committing,
              child: Dialog(
                key: const Key('bil02-food-review-host'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 338,
                    maxHeight: MediaQuery.sizeOf(dialogContext).height * .85,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (committed == null) ...[
                                  DropdownButtonFormField<String>(
                                    key: const Key('bil02-media-meal'),
                                    initialValue: mealType,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: tr('Meal', 'الوجبة'),
                                    ),
                                    items: [
                                      for (final entry in <String, String>{
                                        'breakfast': tr('Breakfast', 'الفطور'),
                                        'lunch': tr('Lunch', 'الغداء'),
                                        'dinner': tr('Dinner', 'العشاء'),
                                        'snack': tr('Snack', 'وجبة خفيفة'),
                                      }.entries)
                                        DropdownMenuItem(
                                          value: entry.key,
                                          child: Text(entry.value),
                                        ),
                                    ],
                                    onChanged: command != null || committing
                                        ? null
                                        : (value) {
                                            if (value != null &&
                                                request.attempt.isCurrent) {
                                              updateDialog(
                                                () => mealType = value,
                                              );
                                            }
                                          },
                                  ),
                                  TextButton(
                                    key: const Key('bil02-media-day'),
                                    onPressed: command != null || committing
                                        ? null
                                        : () async {
                                            if (!await _mediaRequestCurrent(
                                                  request,
                                                ) ||
                                                !dialogContext.mounted) {
                                              return;
                                            }
                                            final changed =
                                                await showDatePicker(
                                                  context: dialogContext,
                                                  initialDate: day,
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                );
                                            if (changed != null &&
                                                await _mediaRequestCurrent(
                                                  request,
                                                ) &&
                                                dialogContext.mounted) {
                                              updateDialog(() => day = changed);
                                            }
                                          },
                                    child: Text(
                                      MaterialLocalizations.of(
                                        context,
                                      ).formatMediumDate(day),
                                    ),
                                  ),
                                  CoachFoodReviewCard(
                                    review: review,
                                    operationId: request.operationId,
                                    mealType: mealType,
                                    day: day,
                                    ownerIsCurrent: () =>
                                        request.attempt.isCurrent,
                                    onConfirm: () async {
                                      if (committing || committed != null) {
                                        return;
                                      }
                                      updateDialog(() => committing = true);
                                      try {
                                        if (!await _mediaRequestCurrent(
                                              request,
                                            ) ||
                                            !mounted ||
                                            !dialogContext.mounted) {
                                          return;
                                        }
                                        if (!writeAllowed()) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                tr(
                                                  'Read-only mode. No food was logged.',
                                                  'وضع القراءة فقط. لم يُسجَّل أي طعام.',
                                                ),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        review.checkOwner(
                                          request.attempt.ownerScope,
                                        );
                                        command ??= CoachMealCommand.foods(
                                          operationId: request.operationId,
                                          date: day,
                                          mealType: mealType,
                                          review: review,
                                        );
                                        final result = await request
                                            .owner
                                            .repository
                                            .commitCoachMeal(
                                              command: command!,
                                              scope: transactionScope,
                                            );
                                        if (!await _mediaRequestCurrent(
                                              request,
                                            ) ||
                                            !dialogContext.mounted) {
                                          return;
                                        }
                                        final verifiedReceipt =
                                            _coachMealReceipt(
                                              request.operationId,
                                              result,
                                            );
                                        if (!CoachFoodReceiptBinding.matches(
                                          result,
                                          verifiedReceipt,
                                        )) {
                                          throw const CoachMealConflict(
                                            CoachMealConflictReason
                                                .readbackUnavailable,
                                            committed: true,
                                          );
                                        }
                                        _refreshCommittedCoachMeals();
                                        if (!request.retainOwner) {
                                          request.retainOwner = true;
                                          recoveredMealOwners.add(
                                            request.owner,
                                          );
                                        }
                                        _appendToolReceipt(
                                          _coachMealResultText(result),
                                          receipt: verifiedReceipt,
                                          undoReadback: result.canUndo
                                              ? (checkPermission) =>
                                                    _undoCommittedCoachMeal(
                                                      actionId:
                                                          request.operationId,
                                                      result: result,
                                                      owner: request.owner,
                                                      checkWritePermission:
                                                          checkPermission,
                                                    )
                                              : null,
                                        );
                                        updateDialog(() {
                                          committed = result;
                                          receipt = verifiedReceipt;
                                        });
                                      } on CoachMealConflict catch (error) {
                                        if (request.attempt.isCurrent) {
                                          _showCoachMealConflict(error);
                                        }
                                        rethrow;
                                      } finally {
                                        if (dialogContext.mounted) {
                                          updateDialog(
                                            () => committing = false,
                                          );
                                        }
                                      }
                                    },
                                    onAdjust: () async {
                                      if (committing) return;
                                      updateDialog(() => committing = true);
                                      try {
                                        if (command != null) {
                                          // Preserve the exact operation after an uncertain
                                          // readback. Retry must never mutate its arguments.
                                          _showActionCompleted(
                                            tr(
                                              'Retry this review to read its saved result.',
                                              'أعد محاولة هذه المراجعة لقراءة نتيجتها المحفوظة.',
                                            ),
                                          );
                                          return;
                                        }
                                        final portions = <CoachFoodPortion>[];
                                        for (final item in review.items) {
                                          final grams = await _askMediaGrams(
                                            request,
                                            issue: CoachMediaFoodIssue
                                                .missingQuantity,
                                          );
                                          if (grams == null ||
                                              !await _mediaRequestCurrent(
                                                request,
                                              )) {
                                            return;
                                          }
                                          portions.add(
                                            CoachFoodPortion(
                                              food: item.food,
                                              quantity: CoachFoodQuantities.declaredGrams(
                                                grams,
                                                description:
                                                    'media:${request.operationId}; '
                                                    'user-adjusted grams before confirmation',
                                              ),
                                            ),
                                          );
                                        }
                                        if (dialogContext.mounted) {
                                          updateDialog(
                                            () => review = CoachFoodReview(
                                              portions,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (dialogContext.mounted) {
                                          updateDialog(
                                            () => committing = false,
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ] else
                                  CoachFoodReceiptCard(
                                    commit: committed!,
                                    receipt: receipt!,
                                    ownerIsCurrent: () =>
                                        request.attempt.isCurrent,
                                    // BASE's daily log owns the existing edit UI. Final
                                    // inline Food V2 correction wiring belongs to BIL-01.
                                    onEdit: (_) => navigateToLog(),
                                    onViewDailyLog: navigateToLog,
                                    onUndo: () async {
                                      if (committing) return;
                                      updateDialog(() => committing = true);
                                      try {
                                        if (!await _mediaRequestCurrent(
                                              request,
                                            ) ||
                                            !mounted) {
                                          return;
                                        }
                                        checkWritePermission();
                                        final previous = committed!;
                                        final undone = await request
                                            .owner
                                            .repository
                                            .undoCoachMeal(
                                              operationId: previous.operationId,
                                              toolId: previous.toolId,
                                              argumentsDigest:
                                                  previous.argumentsDigest,
                                              scope: transactionScope,
                                              checkWritePermission:
                                                  checkWritePermission,
                                            );
                                        if (!await _mediaRequestCurrent(
                                              request,
                                            ) ||
                                            !mounted ||
                                            !dialogContext.mounted) {
                                          return;
                                        }
                                        final undoReceipt = _coachMealReceipt(
                                          request.operationId,
                                          undone,
                                          undo: true,
                                        );
                                        if (!CoachFoodReceiptBinding.matches(
                                          undone,
                                          undoReceipt,
                                        )) {
                                          throw const CoachMealConflict(
                                            CoachMealConflictReason
                                                .readbackUnavailable,
                                            committed: true,
                                          );
                                        }
                                        _refreshCommittedCoachMeals();
                                        _updateState(() {
                                          undoOperations.removeWhere(
                                            (_, operation) =>
                                                operation.receipt.operationId ==
                                                undone.operationId,
                                          );
                                        });
                                        _appendToolReceipt(
                                          tr(
                                            'The previous action was undone.',
                                            'تم التراجع عن الإجراء السابق.',
                                          ),
                                          receipt: undoReceipt,
                                        );
                                        updateDialog(() {
                                          committed = undone;
                                          receipt = undoReceipt;
                                        });
                                      } finally {
                                        if (dialogContext.mounted) {
                                          updateDialog(
                                            () => committing = false,
                                          );
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            key: const Key('bil02-media-close'),
                            onPressed: committing
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: Text(
                              committed == null
                                  ? tr('Cancel', 'إلغاء')
                                  : tr('Close', 'إغلاق'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      // Navigation is authorized only by a current receipt callback. A late
      // dialog result after owner/visit disposal cannot open another route.
      if (openDailyLog && await _mediaRequestCurrent(request) && mounted) {
        ref.read(selectedLogDateProvider.notifier).state = day;
        await context.push('/daily-log');
      }
    } finally {
      refreshReview = null;
      unawaited(ownerListener?.cancel());
      transactionScope.cancel();
    }
  }
}
