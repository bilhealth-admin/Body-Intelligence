import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../composition/dashboard_composition.dart';
import 'dashboard_carousel.dart';
import 'dashboard_section_heading.dart';

class DashboardDailySummarySection extends StatelessWidget {
  const DashboardDailySummarySection({
    required this.title,
    required this.subtitle,
    required this.pages,
    this.badge,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> pages;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final layout = DashboardComposition.pagedSection(
          viewportWidth: MediaQuery.sizeOf(context).width,
          contentWidth: outerConstraints.maxWidth,
        );
        final desktop = layout.isDesktop;
        final baseHeight = layout.pagedSectionBaseHeight;
        final heading = Row(
          children: [
            Expanded(
              child: DashboardSectionHeading(title: title, subtitle: subtitle),
            ),
            if (badge != null) ...[
              const SizedBox(width: PremiumDesignTokens.spaceSm),
              badge!,
            ],
          ],
        );
        final carousel = DashboardCarousel(
          height: MediaQuery.textScalerOf(
            context,
          ).scale(baseHeight).clamp(baseHeight, baseHeight + 90),
          semanticLabel: title,
          pages: pages,
        );

        return PremiumSurface(
          dashboardGlass: true,
          padding: desktop
              ? const EdgeInsets.all(PremiumDesignTokens.spaceMd)
              : PremiumDesignTokens.cardPaddingLarge,
          child: desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 235, child: heading),
                    const SizedBox(width: PremiumDesignTokens.spaceMd),
                    Expanded(child: carousel),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: PremiumDesignTokens.spaceSm),
                    carousel,
                  ],
                ),
        );
      },
    );
  }
}

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
        final columns = layout.metricColumns;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: PremiumDesignTokens.spaceSm,
            mainAxisSpacing: PremiumDesignTokens.spaceSm,
            childAspectRatio: layout.metricChildAspectRatio,
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
    return Container(
      constraints: BoxConstraints(
        minHeight: compact ? 124 : (phone ? 142 : 136),
      ),
      padding: EdgeInsets.all(
        compact ? PremiumDesignTokens.spaceXs : PremiumDesignTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .26),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusLg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 16 : 20, color: accent),
              const SizedBox(width: PremiumDesignTokens.spaceXs),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style:
                      (compact
                              ? Theme.of(context).textTheme.labelMedium
                              : Theme.of(context).textTheme.titleSmall)
                          ?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
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
                        style:
                            (compact
                                    ? Theme.of(context).textTheme.titleLarge
                                    : Theme.of(context).textTheme.headlineSmall)
                                ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(width: PremiumDesignTokens.spaceXs),
                        Text(
                          unit,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                height: 1.1,
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
        arabic ? '$days أيام متتالية' : '$days day streak',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
