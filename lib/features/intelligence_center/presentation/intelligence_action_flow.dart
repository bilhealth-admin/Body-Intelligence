part of 'intelligence_center_page.dart';

extension _IntelligenceActionFlow on _IntelligenceCenterPageState {
  Future<void> _executeAction(
    IntelligenceAction action, {
    bool confirmationAlreadyProvided = false,
  }) async {
    final executionKey = '${action.type.name}:${action.id}';
    if (!executingActionKeys.add(executionKey)) return;
    try {
      final acceptsTypedConfirmation =
          confirmationAlreadyProvided &&
          action.type == IntelligenceActionType.updateGoal &&
          !action.destructive;
      if (action.requiresConfirmation &&
          !acceptsTypedConfirmation &&
          !await _confirmAction(action)) {
        return;
      }
      if (!mounted) return;
      switch (action.type) {
        case IntelligenceActionType.navigate:
          final target = action.payload['target']?.toString();
          final path = target == null
              ? null
              : const BilNavigationRegistry().resolve(target);
          if (path == null) return;
          context.go(path);
        case IntelligenceActionType.readNutritionRemaining:
          final snapshot = await ref.read(coachContextSnapshotProvider.future);
          final remaining = snapshot.nutritionRemainingFor(DateTime.now());
          if (remaining == null) return;
          if (mounted) {
            _appendToolReceipt(
              tr(
                'Remaining today: ${remaining['caloriesKcal']!.round()} kcal, ${remaining['proteinG']!.round()} g protein, ${remaining['carbsG']!.round()} g carbs, ${remaining['fatG']!.round()} g fat.',
                'المتبقي اليوم: ${remaining['caloriesKcal']!.round()} سعرة، ${remaining['proteinG']!.round()} غ بروتين، ${remaining['carbsG']!.round()} غ كربوهيدرات، ${remaining['fatG']!.round()} غ دهون.',
              ),
            );
          }
        case IntelligenceActionType.readProfileIdentity:
          final snapshot = await ref.read(coachContextSnapshotProvider.future);
          final name = snapshot.minimalIdentity['displayName']?.toString();
          if (mounted) {
            _appendToolReceipt(
              name == null
                  ? tr(
                      'No profile name is saved.',
                      'لا يوجد اسم محفوظ في الملف الشخصي.',
                    )
                  : tr('Profile name: $name', 'اسم الملف الشخصي: $name'),
            );
          }
        case IntelligenceActionType.openDailyLog:
          final requested = action.payload['action']?.toString();
          const supportedActions = {
            'barcode',
            'voice',
            'photo',
            'water',
            'notes',
            'exercise',
          };
          final safeAction = supportedActions.contains(requested)
              ? requested
              : null;
          context.go(
            Uri(
              path: '/daily-log',
              queryParameters: safeAction == null
                  ? null
                  : {'action': safeAction},
            ).toString(),
          );
        case IntelligenceActionType.addWater:
          final amount = action.payload['amountMl'];
          if (amount is! int) return;
          final entityId = await ref
              .read(waterRepositoryProvider)
              .add(occurredAt: DateTime.now(), amountMl: amount);
          final receipt = BilActionReceipt(
            actionId: action.id,
            committed: entityId > 0,
            completedAt: DateTime.now(),
            entityType: 'water_entry',
            entityId: entityId.toString(),
            refreshTargets: const {'dailyWater', 'dashboard', 'coachContext'},
          );
          if (mounted && receipt.verified) {
            ref.invalidate(coachContextSnapshotProvider);
            _appendToolReceipt(
              tr(
                'Logged $amount ml of water.',
                'تم تسجيل $amount مل من الماء.',
              ),
            );
            _showActionCompleted(
              tr('Water logged locally.', 'تم تسجيل الماء محليًا.'),
            );
          }
        case IntelligenceActionType.addWeight:
          final value = action.payload['weightKg'];
          if (value is! num) {
            context.go('/daily-check-in');
            return;
          }
          final requestedDate = action.payload['date']?.toString();
          final occurredAt = requestedDate == null
              ? DateTime.now()
              : DateTime.tryParse(requestedDate);
          if (occurredAt == null) return;
          final entityId = await ref
              .read(weightRepositoryProvider)
              .addWeight(
                value.toDouble(),
                date: occurredAt,
                measurementContext: 'differentConditions',
              );
          final receipt = BilActionReceipt(
            actionId: action.id,
            committed: entityId > 0,
            completedAt: DateTime.now(),
            entityType: 'weight_entry',
            entityId: entityId.toString(),
            refreshTargets: const {
              'weightHistory',
              'progress',
              'dashboard',
              'coachContext',
            },
          );
          if (mounted && receipt.verified) {
            ref.invalidate(coachContextSnapshotProvider);
            _appendToolReceipt(
              tr(
                'Logged weight: ${value.toStringAsFixed(1)} kg.',
                'تم تسجيل الوزن: ${value.toStringAsFixed(1)} كغ.',
              ),
            );
            _showActionCompleted(
              tr('Weight logged locally.', 'تم تسجيل الوزن محليًا.'),
            );
          }
        case IntelligenceActionType.reviewMeal:
          final dayOffset = action.payload['dayOffset'];
          if (dayOffset is int && dayOffset != 0) {
            ref.read(selectedLogDateProvider.notifier).state = DateTime.now()
                .add(Duration(days: dayOffset));
          }
          context.go('/daily-log?focus=meal');
        case IntelligenceActionType.reviewWorkout:
          context.push('/wellness/workouts/log');
        case IntelligenceActionType.openPlan:
          context.go('/plan?origin=dashboard');
        case IntelligenceActionType.openReport:
          context.go('/analytics');
        case IntelligenceActionType.openAiCoachSubscription:
          context.push('/plans?focus=ai-coach');
        case IntelligenceActionType.buyAiBoost:
          context.push('/plans?focus=boost');
        case IntelligenceActionType.manageSubscription:
          context.push('/plans');
        case IntelligenceActionType.setThemeMode:
          final mode = action.payload['mode']?.toString();
          if (!const {'dark', 'light', 'system'}.contains(mode)) return;
          await ref.read(appSettingsProvider.notifier).setThemeMode(mode!);
          if (mounted) {
            _appendToolReceipt(
              tr('App appearance updated.', 'تم تحديث مظهر التطبيق.'),
            );
            _showActionCompleted(tr('Appearance updated.', 'تم تحديث المظهر.'));
          }
        case IntelligenceActionType.setLanguage:
          final locale = BilLocalePolicy.canonicalSupportedTag(
            action.payload['locale']?.toString(),
          );
          if (locale == null) return;
          await ref.read(appSettingsProvider.notifier).setLocale(locale);
          if (mounted) {
            _appendToolReceipt(
              tr('App language updated.', 'تم تحديث لغة التطبيق.'),
            );
            _showActionCompleted(tr('Language updated.', 'تم تحديث اللغة.'));
          }
        case IntelligenceActionType.updateGoal:
          final target = action.payload['targetWeightKg'];
          if (target is! num) return;
          final requestedTargetDate = action.payload['targetDate'];
          final targetDate = requestedTargetDate == null
              ? null
              : DateTime.tryParse(requestedTargetDate.toString());
          if (requestedTargetDate != null && targetDate == null) {
            throw ArgumentError.value(requestedTargetDate, 'targetDate');
          }
          // Capture every provider-owned dependency before the first await.
          // The confirmed transaction is allowed to finish after this route
          // is disposed, without touching WidgetRef again.
          final database = ref.read(databaseProvider);
          final profileRepository = ref.read(userProfileRepositoryProvider);
          final goalRepository = ref.read(goalRepositoryProvider);
          final weightRepository = ref.read(weightRepositoryProvider);
          await database.transaction(() async {
            // Reads and writes belong to one snapshot. In particular, do not
            // classify the goal from StreamProvider.value: it can still hold
            // the profile fallback while the latest weight query is loading.
            final profile = await profileRepository.getProfile();
            if (profile == null) throw StateError('goal_profile_missing');
            final existing = await goalRepository.getActive();
            final weights = await weightRepository.getAll();
            final currentWeight = weights.isEmpty
                ? profile.currentWeight
                : weights.first.weight;
            final type = target < currentWeight
                ? 'lose'
                : target > currentWeight
                ? 'gain'
                : 'maintain';
            await profileRepository.save(
              gender: profile.gender,
              age: profile.age,
              height: profile.height,
              currentWeight: currentWeight,
              targetWeight: target.toDouble(),
              activityLevel: profile.activityLevel,
              exercises: profile.exercises,
              medicalConditions: profile.medicalConditions,
              waist: profile.waist,
              neck: profile.neck,
              chest: profile.chest,
              arm: profile.arm,
              thigh: profile.thigh,
            );
            final goalId = await goalRepository.save(
              uuid: existing?.uuid,
              profileUuid: profile.uuid,
              type: type,
              targetWeight: target.toDouble(),
              targetDate: targetDate,
            );
            if (goalId <= 0) {
              // Throw inside the transaction so the preceding profile write
              // is rolled back together with a failed goal commit.
              throw StateError('goal_update_not_committed');
            }
            return goalId;
          });
          // Remove the durable proposal before any mounted-only refresh. This
          // save is queued after dispose's snapshot too, so a completed write
          // cannot reappear as a replayable action when Coach is reopened.
          await _retireDurableAction(action);
          if (!mounted) return;
          ref.invalidate(userProfileProvider);
          ref.invalidate(activeGoalProvider);
          ref.invalidate(coachContextSnapshotProvider);
          _appendToolReceipt(
            tr(
              'Target weight updated to ${target.toStringAsFixed(1)} kg.',
              'تم تحديث الوزن المستهدف إلى ${target.toStringAsFixed(1)} كغ.',
            ),
          );
          _showActionCompleted(tr('Goal updated.', 'تم تحديث الهدف.'));
        case IntelligenceActionType.saveMeasurements:
          double? measurement(String key) =>
              (action.payload[key] as num?)?.toDouble();
          final requestedDate = action.payload['date']?.toString();
          final date = requestedDate == null
              ? DateTime.now()
              : DateTime.tryParse(requestedDate);
          if (date == null) return;
          await ref
              .read(bodyMeasurementRepositoryProvider)
              .saveForDay(
                date: date,
                neckCm: measurement('neckCm'),
                waistCm: measurement('waistCm'),
                hipsCm: measurement('hipsCm'),
                chestCm: measurement('chestCm'),
                armCm: measurement('armCm'),
                thighCm: measurement('thighCm'),
                preserveExistingValues: true,
              );
          if (!mounted) return;
          ref.invalidate(bodyMeasurementHistoryProvider);
          ref.invalidate(coachContextSnapshotProvider);
          _appendToolReceipt(
            tr(
              'Body measurements saved for ${_coachDateLabel(date)}.',
              'تم حفظ قياسات الجسم لتاريخ ${_coachDateLabel(date)}.',
            ),
          );
          _showActionCompleted(
            tr('Measurements updated.', 'تم تحديث القياسات.'),
          );
        case IntelligenceActionType.quickAddMacros:
          final date = action.payload['date'] == null
              ? DateTime.now()
              : DateTime.tryParse(action.payload['date'].toString());
          if (date == null) return;
          final entityId = await ref
              .read(mealRepositoryProvider)
              .addQuickMacroEntry(
                date: date,
                mealType: action.payload['mealType']!.toString(),
                calories: (action.payload['calories']! as num).toDouble(),
                protein: (action.payload['protein']! as num).toDouble(),
                carbohydrates: (action.payload['carbohydrates']! as num)
                    .toDouble(),
                fat: (action.payload['fat']! as num).toDouble(),
                caloriesKnown: true,
                proteinKnown: true,
                carbohydratesKnown: true,
                fatKnown: true,
              );
          if (!mounted) return;
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (entityId > 0) {
            _appendToolReceipt(
              tr(
                'Quick macros added to ${action.payload['mealType']}: '
                    '${(action.payload['calories']! as num).round()} kcal.',
                'تمت إضافة المغذيات السريعة إلى ${action.payload['mealType']}: '
                    '${(action.payload['calories']! as num).round()} سعرة.',
              ),
            );
            _showActionCompleted(tr('Meal updated.', 'تم تحديث الوجبة.'));
          }
        case IntelligenceActionType.updateMealItem:
          await ref
              .read(mealRepositoryProvider)
              .updateMealItem(
                id: action.payload['itemId']! as int,
                quantity: (action.payload['quantityGrams']! as num).toDouble(),
              );
          if (!mounted) return;
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          _appendToolReceipt(
            tr(
              'Meal item ${action.payload['itemId']} updated to '
                  '${(action.payload['quantityGrams']! as num).toStringAsFixed(1)} g.',
              'تم تحديث عنصر الوجبة ${action.payload['itemId']} إلى '
                  '${(action.payload['quantityGrams']! as num).toStringAsFixed(1)} غ.',
            ),
          );
          _showActionCompleted(
            tr('Meal item updated.', 'تم تحديث عنصر الوجبة.'),
          );
        case IntelligenceActionType.deleteMealItem:
          await ref
              .read(mealRepositoryProvider)
              .deleteMealItem(action.payload['itemId']! as int);
          if (!mounted) return;
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          _appendToolReceipt(
            tr(
              'Meal item ${action.payload['itemId']} deleted.',
              'تم حذف عنصر الوجبة ${action.payload['itemId']}.',
            ),
          );
          _showActionCompleted(tr('Meal item deleted.', 'تم حذف عنصر الوجبة.'));
        case IntelligenceActionType.moveMealItem:
          await ref
              .read(mealRepositoryProvider)
              .moveMealItemToType(
                id: action.payload['itemId']! as int,
                mealType: action.payload['mealType']!.toString(),
              );
          if (!mounted) return;
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          _appendToolReceipt(
            tr(
              'Meal item ${action.payload['itemId']} moved to '
                  '${action.payload['mealType']}.',
              'تم نقل عنصر الوجبة ${action.payload['itemId']} إلى '
                  '${action.payload['mealType']}.',
            ),
          );
          _showActionCompleted(tr('Meal item moved.', 'تم نقل عنصر الوجبة.'));
        case IntelligenceActionType.requestAccountDeletion:
          context.push('/help/delete-account');
        case IntelligenceActionType.saveMemory:
          final value = action.payload['text']?.toString().trim() ?? '';
          if (value.isEmpty || value.length > 500) return;
          await CoachMemoryRepository(
            preferences: ref.read(preferencesRepositoryProvider),
          ).saveConfirmed(
            text: value,
            kind: action.payload['kind']?.toString() ?? 'user_fact',
          );
          if (!mounted) return;
          ref.invalidate(coachContextSnapshotProvider);
          _appendToolReceipt(
            tr(
              'BIL will remember this. You can review or remove it any time.',
              'سيتذكر BIL هذه المعلومة. يمكنك مراجعتها أو حذفها في أي وقت.',
            ),
          );
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The action was not completed. Your data stayed unchanged; review the value and try again.',
              'لم يُنفذ الإجراء. بقيت بياناتك دون تغيير؛ راجع القيمة وحاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      executingActionKeys.remove(executionKey);
    }
  }

  Future<void> _retireDurableAction(IntelligenceAction action) async {
    var changed = false;
    void retire() {
      for (var index = 0; index < messages.length; index += 1) {
        final message = messages[index];
        final retained = message.actionLinks
            .where(
              (candidate) =>
                  candidate.type != action.type || candidate.id != action.id,
            )
            .toList(growable: false);
        if (retained.length == message.actionLinks.length) continue;
        messages[index] = message.copyWith(actionLinks: retained);
        changed = true;
      }
    }

    if (mounted) {
      _updateState(retire);
    } else {
      // The state object and its captured repositories remain valid while an
      // already-started commit finishes. Avoid setState/WidgetRef, but queue a
      // newer action-free snapshot after dispose's best-effort save.
      retire();
    }
    if (changed) await _saveConversation();
  }

  Future<bool> _confirmAction(IntelligenceAction action) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          action.destructive
              ? BilSemanticIcons.deleteAccount
              : _iconForAction(action.type),
          color: action.destructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(tr('Confirm action', 'تأكيد الإجراء')),
        content: Text(action.label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Continue', 'متابعة')),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    if (!action.destructive || !mounted) return true;
    return _confirmDestructiveAction(action);
  }

  Future<bool> _confirmDestructiveAction(IntelligenceAction action) async {
    final controller = TextEditingController();
    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              icon: Icon(
                BilSemanticIcons.deleteAccount,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(tr('Final confirmation', 'التأكيد النهائي')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.label),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      'Type DELETE to continue. This confirmation cannot be supplied by AI Coach.',
                      'اكتب حذف للمتابعة. لا يستطيع المدرب الذكي تقديم هذا التأكيد نيابةً عنك.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: tr('Confirmation word', 'كلمة التأكيد'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(tr('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    Navigator.pop(
                      dialogContext,
                      value == 'DELETE' || value == 'حذف',
                    );
                  },
                  child: Text(tr('Confirm', 'تأكيد')),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      controller.dispose();
    }
  }

  void _showActionCompleted(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _coachDateLabel(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void _appendToolReceipt(String text) {
    if (!mounted) return;
    _updateState(() {
      messages.add(
        IntelligenceMessage(
          id: 'tool-${DateTime.now().microsecondsSinceEpoch}',
          role: IntelligenceMessageRole.bil,
          kind: IntelligenceMessageKind.action,
          text: text,
          createdAt: DateTime.now(),
          evidence: const ['BIL verified tool result'],
          confidence: 1,
        ),
      );
    });
    _scrollToLatest();
    unawaited(_saveConversation());
  }

  Future<void> _recordFeedback(
    IntelligenceMessage message,
    bool helpful, {
    String? reason,
  }) async {
    final previous = messageFeedback[message.id];
    final wasReported = reportedMessages.contains(message.id);
    _updateState(() {
      if (reason == 'unsafe') {
        reportedMessages.add(message.id);
      } else {
        messageFeedback[message.id] = helpful;
      }
    });
    try {
      await const AiCoachFeedbackService().record(
        responseId: message.id,
        helpful: helpful,
        locale: BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
        runtime:
            messageRuntimes[message.id] ?? CoachAnswerRuntime.localFallback,
        reason: reason,
      );
      if (!mounted) return;
      _showActionCompleted(
        reason == 'unsafe'
            ? tr(
                'Thanks — this answer was reported for safety review.',
                'شكرًا — تم الإبلاغ عن هذه الإجابة لمراجعة السلامة.',
              )
            : tr(
                'Thanks — your feedback was saved.',
                'شكرًا — تم حفظ ملاحظتك.',
              ),
      );
    } on Object {
      if (!mounted) return;
      _updateState(() {
        if (reason == 'unsafe') {
          if (!wasReported) reportedMessages.remove(message.id);
        } else {
          if (previous == null) {
            messageFeedback.remove(message.id);
          } else {
            messageFeedback[message.id] = previous;
          }
        }
      });
      _showActionCompleted(
        tr('Feedback could not be saved right now.', 'تعذر حفظ الملاحظة الآن.'),
      );
    }
  }

  void usePrompt(String value) {
    question.text = value;
    ask();
  }

  Future<void> _openAiCoachSettings() async {
    await context.push('/settings/ai-coach');
    if (!mounted) return;
    _updateState(() {
      lastServiceStatus = CoachServiceStatus.ready;
      lastRuntime = CoachAnswerRuntime.onDevice;
    });
  }
}
