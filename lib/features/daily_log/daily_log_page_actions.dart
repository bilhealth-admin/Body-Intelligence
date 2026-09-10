part of 'daily_log_page.dart';

extension _DailyLogPageActions on _DailyLogPageState {
  Future<bool> _requirePremiumNutrition() async {
    try {
      final subscription = await ref
          .read(verifiedSubscriptionStateProvider.future)
          .timeout(const Duration(seconds: 8));
      if (subscription.grants(CommerceEntitlement.advancedIntelligence)) {
        return true;
      }
    } on Object {
      // Commerce access fails closed when the server cannot verify it.
    }
    if (mounted) await GoRouter.maybeOf(context)?.push('/plans');
    return false;
  }

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

  Future<void> _copyPreviousDayMeals() async {
    final destination = ref.read(selectedLogDateProvider);
    final source = destination.subtract(const Duration(days: 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('Copy yesterday’s meals?', 'نسخ وجبات اليوم السابق؟')),
        content: Text(
          _arabic
              ? 'ستُنسخ الوجبات وكمياتها إلى هذا اليوم. لن تُستبدل أي وجبات موجودة.'
              : 'Meals and their quantities will be copied to this day. Existing meals will not be replaced.',
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
    if (confirmed != true || !mounted) return;

    try {
      final copied = await ref
          .read(mealRepositoryProvider)
          .copyDay(sourceDate: source, destinationDate: destination);
      if (!mounted) return;
      _message(
        _arabic
            ? copied == 0
                  ? 'لا توجد وجبات في اليوم السابق.'
                  : 'تم نسخ $copied وجبة بعد مراجعتك.'
            : copied == 0
            ? 'There were no meals on the previous day.'
            : '$copied meals copied after your confirmation.',
      );
    } on StateError {
      _message(
        _arabic
            ? 'يحتوي هذا اليوم على وجبات بالفعل. لم يتم استبدالها أو مضاعفتها.'
            : 'This day already has meals. Nothing was replaced or duplicated.',
      );
    }
  }

  Future<void> _copyToMultipleDays() async {
    if (!await _ensureDiaryOpen() || !mounted) return;
    final count = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
    if (count == null || !mounted) return;
    final source = ref.read(selectedLogDateProvider);
    final destinations = List.generate(
      count,
      (index) => source.add(Duration(days: index + 1)),
    );
    try {
      final result = await ref
          .read(mealRepositoryProvider)
          .copyDayToDates(sourceDate: source, destinationDates: destinations);
      ref.invalidate(selectedDailyLedgerProvider);
      if (mounted) {
        _message(
          _tr(
            'Diary copied to {count} days.',
            'تم نسخ اليومية إلى ${result.length} أيام.',
          ).replaceAll('{count}', '${result.length}'),
        );
      }
    } on StateError {
      if (mounted) {
        _message(
          _tr(
            'One of the selected days already has meals. Nothing was copied.',
            'يحتوي أحد الأيام المحددة على وجبات. لم يتم نسخ أي شيء.',
          ),
        );
      }
    }
  }
}
