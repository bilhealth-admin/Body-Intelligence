part of 'intelligence_center_page.dart';

extension _IntelligenceActionFlow on _IntelligenceCenterPageState {
  Future<void> _executeAction(IntelligenceAction action) async {
    try {
      if (action.requiresConfirmation && !await _confirmAction(action)) {
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
            _showActionCompleted(tr('Appearance updated.', 'تم تحديث المظهر.'));
          }
        case IntelligenceActionType.setLanguage:
          final locale = BilLocalePolicy.canonicalSupportedTag(
            action.payload['locale']?.toString(),
          );
          if (locale == null) return;
          await ref.read(appSettingsProvider.notifier).setLocale(locale);
          if (mounted) {
            _showActionCompleted(tr('Language updated.', 'تم تحديث اللغة.'));
          }
        case IntelligenceActionType.updateGoal:
          final target = action.payload['targetWeightKg'];
          if (target is! num) return;
          final profile = await ref.read(userProfileProvider.future);
          if (profile == null) return;
          final existing = await ref.read(activeGoalProvider.future);
          final currentWeight =
              ref.read(effectiveCurrentWeightProvider) ?? profile.currentWeight;
          final targetDate = action.payload['targetDate'] == null
              ? null
              : DateTime.tryParse(action.payload['targetDate'].toString());
          final type = target < currentWeight
              ? 'lose'
              : target > currentWeight
              ? 'gain'
              : 'maintain';
          final entityId = await ref.read(databaseProvider).transaction(
            () async {
              await ref
                  .read(userProfileRepositoryProvider)
                  .save(
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
              return ref
                  .read(goalRepositoryProvider)
                  .save(
                    uuid: existing?.uuid,
                    profileUuid: profile.uuid,
                    type: type,
                    targetWeight: target.toDouble(),
                    targetDate: targetDate,
                  );
            },
          );
          ref.invalidate(userProfileProvider);
          ref.invalidate(activeGoalProvider);
          if (mounted && entityId > 0) {
            _showActionCompleted(tr('Goal updated.', 'تم تحديث الهدف.'));
          }
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
              );
          ref.invalidate(bodyMeasurementHistoryProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _showActionCompleted(
              tr('Measurements updated.', 'تم تحديث القياسات.'),
            );
          }
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
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted && entityId > 0) {
            _showActionCompleted(tr('Meal updated.', 'تم تحديث الوجبة.'));
          }
        case IntelligenceActionType.updateMealItem:
          await ref
              .read(mealRepositoryProvider)
              .updateMealItem(
                id: action.payload['itemId']! as int,
                quantity: (action.payload['quantityGrams']! as num).toDouble(),
              );
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _showActionCompleted(
              tr('Meal item updated.', 'تم تحديث عنصر الوجبة.'),
            );
          }
        case IntelligenceActionType.deleteMealItem:
          await ref
              .read(mealRepositoryProvider)
              .deleteMealItem(action.payload['itemId']! as int);
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _showActionCompleted(
              tr('Meal item deleted.', 'تم حذف عنصر الوجبة.'),
            );
          }
        case IntelligenceActionType.moveMealItem:
          await ref
              .read(mealRepositoryProvider)
              .moveMealItemToType(
                id: action.payload['itemId']! as int,
                mealType: action.payload['mealType']!.toString(),
              );
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _showActionCompleted(tr('Meal item moved.', 'تم نقل عنصر الوجبة.'));
          }
        case IntelligenceActionType.requestAccountDeletion:
          context.push('/community/profile');
        case IntelligenceActionType.saveMemory:
          final value = action.payload['text']?.toString().trim() ?? '';
          if (value.isEmpty || value.length > 500) return;
          await CoachMemoryRepository(
            preferences: ref.read(preferencesRepositoryProvider),
          ).saveConfirmed(
            text: value,
            kind: action.payload['kind']?.toString() ?? 'user_fact',
          );
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _appendToolReceipt(
              tr(
                'BIL will remember this. You can review or remove it any time.',
                'سيتذكر BIL هذه المعلومة. يمكنك مراجعتها أو حذفها في أي وقت.',
              ),
            );
          }
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
    }
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
    _updateState(() => messageFeedback[message.id] = helpful);
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
        if (previous == null) {
          messageFeedback.remove(message.id);
        } else {
          messageFeedback[message.id] = previous;
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
