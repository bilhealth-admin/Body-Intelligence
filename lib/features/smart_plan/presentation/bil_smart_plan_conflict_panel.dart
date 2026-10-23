part of 'bil_smart_plan_page.dart';

/// A real review surface shared by the sync flow and native visual tests.
class BilSmartPlanConflictReviewPanel extends ConsumerWidget {
  const BilSmartPlanConflictReviewPanel({
    super.key,
    required this.reviewed,
    required this.checkAccess,
    required this.horizonName,
    required this.statusName,
  });
  final BilSmartPlanSyncConflict reviewed;
  final void Function() checkAccess;
  final String Function(BilPlanHorizon) horizonName;
  final String Function(BilPlanStatus) statusName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(verifiedEntitlementOwnerIdProvider);
    try {
      checkAccess();
      if (ref.read(verifiedEntitlementOwnerIdProvider) != reviewed.owner) {
        return const SizedBox.shrink();
      }
    } on Object {
      return const SizedBox.shrink();
    }
    final sheet = context;
    String t(String en, String ar) => _smartPlanText(context, en, ar);
    void finish(bool? choice) {
      try {
        checkAccess();
        if (ref.read(verifiedEntitlementOwnerIdProvider) == reviewed.owner) {
          Navigator.pop(context, choice);
        }
      } on Object {
        /* A retired owner visit cannot approve a stale review. */
      }
    }

    String summary(String? raw) {
      if (raw == null) {
        return t('Deleted / no saved plan', 'محذوفة / لا توجد خطة محفوظة');
      }
      final plan = BilSmartPlan.decode(raw);
      return '${plan.startDate} · ${horizonName(plan.horizon)}\n'
          '${statusName(plan.status)} · ${plan.revision}\n'
          '${MaterialLocalizations.of(context).formatShortDate(plan.updatedAt.toLocal())} · '
          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(plan.updatedAt.toLocal()))}';
    }

    final device = reviewed.localPlan == null
        ? null
        : BilSmartPlan.decode(reviewed.localPlan!);
    final cloud = reviewed.cloud.plan == null
        ? null
        : BilSmartPlan.decode(reviewed.cloud.plan!);
    final dates = {
      ...?device?.days.map((day) => day.date),
      ...?cloud?.days.map((day) => day.date),
    }.toList()..sort();
    BilPlanDay? dayFor(BilSmartPlan? plan, String date) =>
        plan?.onDate(BilPlanDate.parse(date));
    String daySummary(BilPlanDay? day) {
      if (day == null) {
        return t(
          'No scheduled day for this date.',
          'لا يوجد يوم مجدول بهذا التاريخ.',
        );
      }
      const catalog = BilSmartPlanCatalog();
      return '${day.workout == null ? t('Recovery day', 'يوم راحة') : day.workout!.exerciseIds.map(catalog.exerciseTitle).join(', ')}\n'
          '${day.meals.map((meal) => catalog.recipeTitle(meal.recipeId)).join(', ')}';
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('Review conflicting plans', 'مراجعة تعارض الخطط'),
              style: Theme.of(sheet).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              t(
                'Choose the version to continue with. Both reviewed versions stay in your private local export history. Actual diary entries will not change.',
                'اختر الإصدار الذي تريد المتابعة به. يبقى الإصداران اللذان راجعتهما في سجل التصدير المحلي الخاص. لا تتغير سجلات دفتر الأنشطة الفعلية.',
              ),
            ),
            const SizedBox(height: 16),
            BilPearlMaterialCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('On this device', 'على هذا الجهاز'),
                      style: Theme.of(sheet).textTheme.titleMedium,
                    ),
                    Text(summary(reviewed.localPlan)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            BilPearlMaterialCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('In cloud backup', 'في النسخة السحابية'),
                      style: Theme.of(sheet).textTheme.titleMedium,
                    ),
                    Text(summary(reviewed.cloud.plan)),
                  ],
                ),
              ),
            ),
            ExpansionTile(
              title: Text(t('Compare changed days', 'مقارنة الأيام المتغيرة')),
              children: [
                for (final date in dates)
                  if (jsonEncode(dayFor(device, date)?.toJson()) !=
                      jsonEncode(dayFor(cloud, date)?.toJson()))
                    ListTile(
                      title: Text(date),
                      subtitle: Text(
                        '${t('On this device', 'على هذا الجهاز')}: ${daySummary(dayFor(device, date))}\n\n'
                        '${t('In cloud backup', 'في النسخة السحابية')}: ${daySummary(dayFor(cloud, date))}',
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => finish(true),
              child: Text(t('Use device version', 'استخدام إصدار الجهاز')),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _smartPlanActionInk(context),
              ),
              onPressed: () => finish(false),
              child: Text(t('Use cloud version', 'استخدام الإصدار السحابي')),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: _smartPlanActionInk(context),
              ),
              onPressed: () => finish(null),
              child: Text(t('Cancel', 'إلغاء')),
            ),
          ],
        ),
      ),
    );
  }
}
