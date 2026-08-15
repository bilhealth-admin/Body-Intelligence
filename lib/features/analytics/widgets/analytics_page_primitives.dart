part of '../analytics_page.dart';

class _EvidencePill extends StatelessWidget {
  const _EvidencePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PremiumDesignTokens.spaceSm,
          vertical: PremiumDesignTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsStateSkeletonBlock extends StatelessWidget {
  const _AnalyticsStateSkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusLg),
      ),
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: FractionallySizedBox(
          widthFactor: 0.45,
          child: Container(
            height: PremiumDesignTokens.spaceSm,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.maximum,
    required this.suffix,
  });

  final String label;
  final double value;
  final double maximum;
  final String suffix;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    subtitle: LinearProgressIndicator(value: (value / maximum).clamp(0, 1)),
    trailing: Text('${value.toStringAsFixed(1)} $suffix'),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: rtl ? TextAlign.right : TextAlign.left,
            style: PremiumDesignTokens.cardHeading(context),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          ...lines.map(
            (line) =>
                Text(line, textAlign: rtl ? TextAlign.right : TextAlign.left),
          ),
        ],
      ),
    );
  }
}

class AnalyticsWeeklyProgressCard extends StatelessWidget {
  const AnalyticsWeeklyProgressCard({
    super.key,
    required this.weekly,
    required this.weeklyRateKg,
  });

  final WeeklyReview weekly;
  final double? weeklyRateKg;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => analyticsText(context, en, ar);
    return _SummaryCard(
      title: tr('Weekly review', 'المراجعة الأسبوعية'),
      lines: [
        tr(
          '${weekly.trackedDays} of 7 days with at least one core record',
          '${weekly.trackedDays} من 7 أيام بها سجل أساسي واحد على الأقل',
        ),
        if (arabic)
          weeklyRateKg == null
              ? 'لا توجد أدلة وزن متقاربة كافية لاتجاه أسبوعي.'
              : 'الاتجاه الأسبوعي الممهّد: ${weeklyRateKg! >= 0 ? '+' : ''}${weeklyRateKg!.toStringAsFixed(2)} كجم. لا يحدد هذا تغير الدهون أو العضلات.'
        else
          weekly.summary,
        if (arabic)
          weekly.missingData.isNotEmpty
              ? 'حسّن مصدر بيانات ناقصًا واحدًا قبل تغيير الخطة.'
              : 'حافظ على ثبات الخطة وقارن أسبوعًا كاملًا آخر.'
        else
          weekly.nextDecision,
        ...(arabic
            ? [
                if (weekly.weightDays < 4)
                  'تحسّن 4 أيام وزن على الأقل تفسير الاتجاه',
                if (weekly.nutritionDays < 5)
                  'تحسّن أيام الوجبات المكتملة فهم المدخول',
                if (weekly.waterDays < 5) 'تحسّن أيام الترطيب فهم الالتزام',
              ]
            : weekly.missingData),
      ],
    );
  }
}

class AnalyticsWeightJourneyCard extends StatelessWidget {
  const AnalyticsWeightJourneyCard({
    super.key,
    required this.weights,
    required this.system,
    required this.rangeLabel,
    required this.rangeDays,
    required this.weeklyRateKg,
    required this.progress,
  });

  final List<WeightEntry> weights;
  final MeasurementSystem system;
  final String rangeLabel;
  final int? rangeDays;
  final double? weeklyRateKg;
  final ProgressAnalysis progress;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => analyticsText(context, en, ar);
    final unit = UnitConverter.weightUnit(system);
    final confidence = arabic
        ? switch (progress.confidence) {
            ProgressConfidence.insufficient => 'غير كافية',
            ProgressConfidence.low => 'منخفضة',
            ProgressConfidence.medium => 'متوسطة',
            ProgressConfidence.high => 'مرتفعة',
          }
        : progress.confidence.name;
    return PremiumChartCard(
      semanticLabel: tr(
        'Weight chart with evidence explanation',
        'مخطط الوزن مع شرح الأدلة',
      ),
      title: tr('Weight over time', 'الوزن عبر الزمن'),
      subtitle: rangeDays == null
          ? tr(
              'Measured local check-ins across all recorded time.',
              'قياسات تسجيل محلية عبر كامل الفترة المسجلة.',
            )
          : tr(
              'Measured local check-ins across the selected $rangeDays-day range.',
              'قياسات تسجيل محلية عبر نطاق $rangeDays يومًا المحدد.',
            ),
      chart: AnalyticsWeightTrendChart(
        weights: weights,
        system: system,
        rangeLabel: rangeLabel,
      ),
      explanation: [
        tr(
          'Trend direction: ${weeklyRateKg == null ? 'insufficient evidence' : '${weeklyRateKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(weeklyRateKg!, system).toStringAsFixed(2)} $unit/week (smoothed)'}',
          'اتجاه المسار: ${weeklyRateKg == null ? 'أدلة غير كافية' : '${weeklyRateKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(weeklyRateKg!, system).toStringAsFixed(2)} $unit/أسبوع (ممهّد)'}',
        ),
        tr(
          'Evidence sufficiency: ${progress.sampleCount} measurements across ${progress.spanDays} days ($confidence).',
          'كفاية الأدلة: ${progress.sampleCount} قياسًا خلال ${progress.spanDays} يومًا (ثقة $confidence).',
        ),
        tr(
          'This chart reflects measured weight only and cannot safely conclude fat or muscle change on its own.',
          'يعرض هذا المخطط الوزن المقاس فقط ولا يمكنه وحده استنتاج تغير الدهون أو العضلات بشكل آمن.',
        ),
      ],
      footer: weights.isEmpty
          ? Text(
              tr(
                'Add weight entries to unlock trend interpretation.',
                'أضف قياسات وزن لبدء تفسير الاتجاه.',
              ),
            )
          : null,
    );
  }
}
