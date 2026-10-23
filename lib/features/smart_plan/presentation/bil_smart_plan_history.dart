part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanHistory on _BilSmartPlanPageState {
  Future<void> _showRevision(BilSmartPlan plan, int revision) async {
    var version = plan;
    while (version.revision > revision) {
      final previous = version.previousVersion();
      if (previous == null) return;
      version = previous;
    }
    final change = version.changes.firstOrNull;
    if (change == null) return;
    await showBilModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_t('Revision ', 'الإصدار ')}${change.revision}',
                style: Theme.of(sheet).textTheme.headlineSmall,
              ),
              Text(_changeReason(change.reason)),
              const SizedBox(height: 16),
              if (change.previousStatus != version.status)
                Text(
                  '${_statusName(change.previousStatus)} → ${_statusName(version.status)}',
                ),
              for (final before in change.beforeDays) ...[
                Text(before.date, style: Theme.of(sheet).textTheme.titleMedium),
                Text(
                  '${before.workout == null ? _t('Recovery day', 'يوم راحة') : _workoutTitle(before.workout!.templateId)} → '
                  '${version.onDate(BilPlanDate.parse(before.date))?.workout == null ? _t('Recovery day', 'يوم راحة') : _workoutTitle(version.onDate(BilPlanDate.parse(before.date))!.workout!.templateId)}',
                ),
                if (before.workout != null &&
                    version.onDate(BilPlanDate.parse(before.date))?.workout !=
                        null &&
                    before.workout!.completed !=
                        version
                            .onDate(BilPlanDate.parse(before.date))!
                            .workout!
                            .completed)
                  Text(
                    version
                            .onDate(BilPlanDate.parse(before.date))!
                            .workout!
                            .completed
                        ? _t(
                            'Not recorded → Confirmed completed',
                            'غير مسجل ← إنجاز مؤكد',
                          )
                        : _t(
                            'Confirmed completed → Completion corrected',
                            'إنجاز مؤكد ← تم تصحيح الإنجاز',
                          ),
                  ),
                for (final oldMeal in before.meals)
                  if (version
                      .onDate(BilPlanDate.parse(before.date))!
                      .meals
                      .any(
                        (m) =>
                            m.slot == oldMeal.slot &&
                            m.recipeId != oldMeal.recipeId,
                      ))
                    Text(
                      '${_mealSlot(oldMeal.slot)}\n'
                      '${const BilSmartPlanCatalog().recipeTitle(oldMeal.recipeId, locale: Localizations.localeOf(sheet).languageCode)}\n↓\n'
                      '${const BilSmartPlanCatalog().recipeTitle(version.onDate(BilPlanDate.parse(before.date))!.meals.singleWhere((m) => m.slot == oldMeal.slot).recipeId, locale: Localizations.localeOf(sheet).languageCode)}',
                    ),
                const SizedBox(height: 12),
              ],
              Text(
                _t(
                  'Comparison does not alter your saved plan or actual activity records.',
                  'المقارنة لا تعدل خطتك المحفوظة أو سجلات نشاطك الفعلية.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
