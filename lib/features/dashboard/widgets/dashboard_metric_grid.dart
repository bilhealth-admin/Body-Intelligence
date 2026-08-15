part of 'dashboard_daily_summary.dart';

class DashboardMetricData {
  const DashboardMetricData(
    this.icon,
    this.label,
    this.value,
    this.unit,
    this.accent,
  );

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color accent;
}

class DashboardMetricGridPage extends StatelessWidget {
  const DashboardMetricGridPage({required this.metrics, super.key});

  final List<DashboardMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = DashboardComposition.metricGrid(
          viewportWidth: MediaQuery.sizeOf(context).width,
          contentWidth: constraints.maxWidth,
          metricCount: metrics.length,
        );
        final phone = MediaQuery.sizeOf(context).width < 600;

        if (DashboardPrimaryEmbeddedScope.active(context)) {
          return GridView.builder(
            key: const Key('dashboard-summary-static-metric-rows'),
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: PremiumDesignTokens.spaceXs,
              mainAxisSpacing: PremiumDesignTokens.spaceXs,
              mainAxisExtent: 58,
            ),
            itemCount: metrics.length,
            itemBuilder: (context, index) =>
                _EmbeddedMetricRow(metric: metrics[index]),
          );
        }

        final columns = phone ? 2 : layout.metricColumns;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          primary: false,
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: PremiumDesignTokens.spaceSm,
            mainAxisSpacing: phone ? 18 : PremiumDesignTokens.spaceSm,
            childAspectRatio: phone ? .94 : layout.metricChildAspectRatio,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _CompactMetricTile(
              icon: metric.icon,
              label: metric.label,
              value: metric.value,
              unit: metric.unit,
              accent: metric.accent,
            );
          },
        );
      },
    );
  }
}

class _EmbeddedMetricRow extends StatelessWidget {
  const _EmbeddedMetricRow({required this.metric});

  final DashboardMetricData metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .78)),
      ),
      child: Row(
        children: [
          Icon(metric.icon, size: 20, color: metric.accent),
          const SizedBox(width: PremiumDesignTokens.spaceSm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: metric.value,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (metric.unit.isNotEmpty)
                          TextSpan(text: ' ${metric.unit}'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetricTile extends StatelessWidget {
  const _CompactMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final layout = DashboardComposition.metricTile(
      viewportWidth: MediaQuery.sizeOf(context).width,
    );
    final compact = layout.compactMetricTiles;
    final phone = layout.isPhone;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? 150 : (phone ? 176 : 172),
      ),
      child: PremiumSurface(
        level: PremiumSurfaceLevel.detail,
        dashboardGlass: true,
        padding: EdgeInsets.all(compact ? 8 : PremiumDesignTokens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: compact ? 13 : 18, color: accent),
                const SizedBox(width: PremiumDesignTokens.spaceXs),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    softWrap: true,
                    style:
                        (compact
                                ? Theme.of(context).textTheme.labelSmall
                                : Theme.of(context).textTheme.labelLarge)
                            ?.copyWith(
                              fontSize: phone ? 9 : null,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 1 : 8),
            Expanded(
              child: Center(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                height: 1.0,
                                fontSize: phone ? 10 : 13,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (unit.isNotEmpty) ...[
                          const SizedBox(width: PremiumDesignTokens.spaceXs),
                          Text(
                            unit,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  height: 1.0,
                                  fontSize: phone ? 8.5 : 11,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardStreakBadge extends StatelessWidget {
  const DashboardStreakBadge({
    required this.days,
    required this.arabic,
    super.key,
  });

  final int days;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final streak = (_dashboardStreakCopy[locale] ?? _dashboardStreakCopy['en']!)
        .replaceFirst('{days}', '$days');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PremiumDesignTokens.spaceSm,
        vertical: PremiumDesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        streak,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

const _dashboardStreakCopy = <String, String>{
  'ar': '{days} أيام متتالية',
  'en': '{days} day streak',
  'fr': '{days} jours consécutifs',
  'es': 'Racha de {days} días',
  'tr': '{days} günlük seri',
};
