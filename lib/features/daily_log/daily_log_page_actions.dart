part of 'daily_log_page.dart';

extension _DailyLogPageActions on _DailyLogPageState {
  Future<bool> _requirePremiumNutrition() => requestVerifiedFeatureAccess(
    context,
    ref,
    CommerceEntitlement.advancedIntelligence,
  );

  Future<void> _quickAddMacros() async {
    if (!await _requirePremiumNutrition() || !mounted) return;
    if (!await _ensureDiaryOpen() || !mounted) return;
    final saved = await showQuickMacroEntryDialog(
      context: context,
      copy: _tr,
      mealLabel: _mealCopy(mealType),
      onSave: (draft) async {
        final date = ref.read(selectedLogDateProvider);
        await ref
            .read(mealRepositoryProvider)
            .addQuickMacroEntry(
              date: date,
              mealType: mealType,
              calories: draft.calories,
              protein: draft.protein,
              carbohydrates: draft.carbohydrates,
              fat: draft.fat,
              caloriesKnown: draft.caloriesKnown,
              proteinKnown: draft.proteinKnown,
              carbohydratesKnown: draft.carbohydratesKnown,
              fatKnown: draft.fatKnown,
              occurredAt: DateTime(
                date.year,
                date.month,
                date.day,
                draft.time.hour,
                draft.time.minute,
              ),
            );
      },
    );
    if (saved != true) return;
    ref.invalidate(selectedDailyLedgerProvider);
    if (mounted) {
      _message(
        _tr('Quick Add saved locally.', 'تم حفظ الإضافة السريعة محليًا.'),
      );
    }
  }

  Future<bool> _ensureDiaryOpen() async {
    final ledger = await ref
        .read(dailyLogRepositoryProvider)
        .readLedger(ref.read(selectedLogDateProvider));
    if (ledger.state != DayLifecycleState.closed) return true;
    if (mounted) {
      _message(
        _tr(
          'Reopen the completed diary before making changes.',
          'أعد فتح اليوميات المكتملة قبل إجراء تغييرات.',
        ),
      );
    }
    return false;
  }

  Future<void> _completeDiary() async {
    final date = ref.read(selectedLogDateProvider);
    final repository = ref.read(dailyLogRepositoryProvider);
    final ledger = await repository.readLedger(date);
    if (ledger.state == DayLifecycleState.notStarted) {
      await repository.startDay(date);
    }
    await repository.closeDay(date);
    ref.invalidate(selectedDailyLogProvider);
    ref.invalidate(selectedDailyLedgerProvider);
    if (mounted) {
      _message(_tr('Diary completed', 'اكتملت اليوميات'));
      unawaited(
        ref
            .read(storeReviewPromptServiceProvider)
            .recordPositiveMoment(StoreReviewMoment.diaryCompleted),
      );
    }
  }

  Future<void> _reopenDiary() async {
    final date = ref.read(selectedLogDateProvider);
    await ref.read(dailyLogRepositoryProvider).reopenDay(date);
    ref.invalidate(selectedDailyLogProvider);
    ref.invalidate(selectedDailyLedgerProvider);
    if (mounted) {
      _message(_tr('Diary reopened', 'أُعيد فتح اليوميات'));
    }
  }

  bool _copyContextIsCurrent(
    DateTime chosenDay,
    MealRepository repository, {
    DailyLogRepository? diaryRepository,
  }) =>
      mounted &&
      DateUtils.isSameDay(ref.read(selectedLogDateProvider), chosenDay) &&
      identical(ref.read(mealRepositoryProvider), repository) &&
      (diaryRepository == null ||
          identical(ref.read(dailyLogRepositoryProvider), diaryRepository));

  String get _closedDiaryCopyMessage => _tr(
    'Reopen the completed diary before copying meals.',
    'أعد فتح اليوميات المكتملة قبل نسخ الوجبات.',
  );

  String get _failedDiaryCopyMessage => _tr(
    'Meals could not be copied. Nothing was changed.',
    'تعذر نسخ الوجبات. لم يتغير شيء.',
  );

  Future<void> _copyPreviousDayMeals() async {
    final chosenDay = ref.read(selectedLogDateProvider);
    final destination = DateTime(
      chosenDay.year,
      chosenDay.month,
      chosenDay.day,
    );
    final source = DateTime(
      destination.year,
      destination.month,
      destination.day - 1,
    );
    final repository = ref.read(mealRepositoryProvider);
    bool current() => _copyContextIsCurrent(destination, repository);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BilPearlMaterialAlertDialog(
        title: Text(_tr('Copy yesterday’s meals?', 'نسخ وجبات اليوم السابق؟')),
        content: Text(
          _tr(
            'Meals and their quantities will be copied to this day. Existing meals will not be replaced.',
            'ستُنسخ الوجبات وكمياتها إلى هذا اليوم. لن تُستبدل أي وجبات موجودة.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('Copy', 'نسخ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !current()) return;
    try {
      final copied = await repository.copyDay(
        sourceDate: source,
        destinationDate: destination,
      );
      if (!current()) return;
      _message(
        copied == 0
            ? _tr(
                'There were no meals on the previous day.',
                'لا توجد وجبات في اليوم السابق.',
              )
            : _tr(
                '{count} meals copied after your confirmation.',
                'تم نسخ {count} وجبة بعد مراجعتك.',
              ).replaceAll('{count}', '$copied'),
      );
    } on MealDayCopyConflict {
      if (!current()) return;
      _message(
        _tr(
          'This day already has meals. Nothing was replaced or duplicated.',
          'يحتوي هذا اليوم على وجبات بالفعل. لم يتم استبدالها أو مضاعفتها.',
        ),
      );
    } on CoachMealConflict catch (error) {
      if (!current()) return;
      _message(
        error.reason == CoachMealConflictReason.closedDay
            ? _closedDiaryCopyMessage
            : _failedDiaryCopyMessage,
      );
    } on Object {
      if (current()) _message(_failedDiaryCopyMessage);
    }
  }

  Future<void> _copyToMultipleDays() async {
    final chosenDay = ref.read(selectedLogDateProvider);
    final source = DateTime(chosenDay.year, chosenDay.month, chosenDay.day);
    final repository = ref.read(mealRepositoryProvider);
    final diaryRepository = ref.read(dailyLogRepositoryProvider);
    bool current() => _copyContextIsCurrent(
      source,
      repository,
      diaryRepository: diaryRepository,
    );
    try {
      final ledger = await diaryRepository.readLedger(source);
      if (!mounted || !current()) return;
      if (ledger.state == DayLifecycleState.closed) {
        _message(_closedDiaryCopyMessage);
        return;
      }
      final count = await showDialog<int>(
        context: context,
        builder: (dialogContext) => BilPearlMaterialAlertDialog(
          title: Text(_tr('Copy to multiple days', 'نسخ إلى عدة أيام')),
          content: Text(
            _tr(
              'Choose how many upcoming empty days receive this diary. Existing days are never replaced.',
              'اختر عدد الأيام الفارغة القادمة التي ستستقبل هذه اليومية. لن تُستبدل الأيام الموجودة.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tr('Cancel', 'إلغاء')),
            ),
            for (final days in const [2, 3, 7])
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext, days),
                child: Text('$days'),
              ),
          ],
        ),
      );
      if (count == null || !current()) return;
      final destinations = List.generate(
        count,
        (index) => DateTime(source.year, source.month, source.day + index + 1),
      );
      final result = await repository.copyDayToDates(
        sourceDate: source,
        destinationDates: destinations,
      );
      if (!current()) return;
      if (result.values.every((copied) => copied == 0)) {
        _message(_tr('There were no meals to copy.', 'لا توجد وجبات لنسخها.'));
        return;
      }
      ref.invalidate(selectedDailyLedgerProvider);
      _message(
        _tr(
          'Diary copied to {count} days.',
          'تم نسخ اليومية إلى {count} أيام.',
        ).replaceAll('{count}', '${result.length}'),
      );
    } on MealDayCopyConflict {
      if (!current()) return;
      _message(
        _tr(
          'One of the selected days already has meals. Nothing was copied.',
          'يحتوي أحد الأيام المحددة على وجبات. لم يتم نسخ أي شيء.',
        ),
      );
    } on CoachMealConflict catch (error) {
      if (!current()) return;
      _message(
        error.reason == CoachMealConflictReason.closedDay
            ? _closedDiaryCopyMessage
            : _failedDiaryCopyMessage,
      );
    } on Object {
      if (current()) _message(_failedDiaryCopyMessage);
    }
  }
}
