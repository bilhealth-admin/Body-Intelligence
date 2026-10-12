part of 'analytics_page.dart';

class AnalyticsPersonalBaselineCard extends StatelessWidget {
  const AnalyticsPersonalBaselineCard({
    super.key,
    required this.report,
    this.recentAverageWeight,
    required this.weightUnit,
  });
  final PersonalBaselineReport report;
  final String? recentAverageWeight;
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => analyticsText(context, en, ar);
    Widget field(String name, String unit, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(unit.isEmpty ? name : '$name · $unit'),
          const SizedBox(height: 4),
          PremiumNutritionGlass(
            showLabel: false,
            compact: true,
            child: Text(value, textDirection: TextDirection.ltr),
          ),
        ],
      ),
    );
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Your personal baseline', 'خطك الأساسي الشخصي'),
            key: const Key('analytics-personal-baseline-title'),
            style: PremiumDesignTokens.cardHeading(context),
          ),
          Text(
            tr(
              'Compared with your own earlier records.',
              'مقارنة بسجلاتك السابقة أنت.',
            ),
          ),
          if (report.sufficient)
            PremiumNutritionFieldsGroup(
              key: const Key('analytics-personal-baseline-premium-glass'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (recentAverageWeight != null)
                    field(
                      tr('Recent average weight', 'متوسط الوزن الحديث'),
                      weightUnit,
                      recentAverageWeight!,
                    ),
                  field(
                    tr('Evidence confidence', 'ثقة الأدلة'),
                    '',
                    localizedBaselineConfidence(
                      report.confidence,
                      arabic: arabic,
                    ),
                  ),
                  for (final item in report.comparisons)
                    field(
                      tr(item.metric, switch (item.metric) {
                        'Calories' => 'السعرات',
                        'Protein' => 'البروتين',
                        'Sodium' => 'الصوديوم',
                        'Water' => 'الماء',
                        _ => 'الوزن',
                      }),
                      item.unit,
                      '${item.current.toStringAsFixed(1)} (${item.change >= 0 ? '+' : ''}${item.change.toStringAsFixed(1)} ${tr('vs your baseline', 'مقابل خطك الأساسي')})',
                    ),
                ],
              ),
            )
          else ...[
            Text(
              tr(
                'A personal comparison needs at least 7 earlier and 3 recent days for one metric.',
                'تحتاج المقارنة الشخصية إلى 7 أيام سابقة و3 أيام حديثة على الأقل لمؤشر واحد.',
              ),
            ),
            Text(
              tr(
                'No population average is substituted for your missing data.',
                'لن نستخدم متوسطات السكان بدلًا من بياناتك الناقصة.',
              ),
            ),
          ],
          Text(
            tr(
              'Associations describe your records; they do not prove a cause.',
              'العلاقات تصف سجلاتك ولا تثبت سببًا.',
            ),
          ),
        ],
      ),
    );
  }
}
