import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../composition/dashboard_composition.dart';
import 'dashboard_carousel.dart';
import 'dashboard_primary_carousel.dart';
import 'dashboard_section_heading.dart';

part 'dashboard_metric_grid.dart';

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
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final carousel = DashboardCarousel(
          height: (baseHeight + (textScale - 1).clamp(0, 1.5) * 150).clamp(
            baseHeight,
            baseHeight + 220,
          ),
          semanticLabel: title,
          pages: pages,
        );

        if (DashboardPrimaryEmbeddedScope.active(context)) {
          if (pages.isEmpty) return const SizedBox.shrink();
          final embeddedMetrics = pages
              .whereType<DashboardMetricGridPage>()
              .expand((page) => page.metrics)
              .toList(growable: false);
          if (embeddedMetrics.isNotEmpty) {
            return _UnifiedMetricCard(metrics: embeddedMetrics);
          }
          return KeyedSubtree(
            key: const Key('dashboard-summary-static-body-twin-content'),
            child: pages.first,
          );
        }

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

class _UnifiedMetricCard extends StatefulWidget {
  const _UnifiedMetricCard({required this.metrics});

  final List<DashboardMetricData> metrics;

  @override
  State<_UnifiedMetricCard> createState() => _UnifiedMetricCardState();
}

class _UnifiedMetricCardState extends State<_UnifiedMetricCard> {
  var _metric = 0;
  var _detail = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.metrics.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final copy =
        _unifiedMetricCopy[locale] ??
        _unifiedMetricCopy['en']!.map(
          (key, value) => MapEntry(key, context.strings.text(value)),
        );
    final metric = widget.metrics[_metric.clamp(0, widget.metrics.length - 1)];
    final recorded = metric.value.trim().isNotEmpty && metric.value != '—';
    final labels = [copy['value']!, copy['unit']!, copy['logging']!];
    final icons = const [
      Icons.analytics_outlined,
      Icons.straighten_rounded,
      Icons.fact_check_outlined,
    ];
    final details = [
      metric.unit.isEmpty ? metric.value : '${metric.value} ${metric.unit}',
      metric.unit.isEmpty ? copy['noUnit']! : metric.unit,
      recorded ? copy['logged']! : copy['notLogged']!,
    ];

    return Padding(
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: PremiumDesignTokens.spaceXs,
                mainAxisSpacing: PremiumDesignTokens.spaceXs,
                mainAxisExtent: 38,
              ),
              itemCount: widget.metrics.length,
              itemBuilder: (context, index) {
                final item = widget.metrics[index];
                final selected = index == _metric;
                return InkWell(
                  onTap: () => setState(() => _metric = index),
                  borderRadius: BorderRadius.circular(
                    PremiumDesignTokens.radiusMd,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: .14)
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: .42,
                            ),
                      borderRadius: BorderRadius.circular(
                        PremiumDesignTokens.radiusMd,
                      ),
                      border: Border.all(
                        color: selected
                            ? scheme.primary.withValues(alpha: .55)
                            : scheme.outlineVariant.withValues(alpha: .72),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, size: 16, color: item.accent),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            metric.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _detail = index),
                    borderRadius: BorderRadius.circular(99),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: index == _detail
                            ? scheme.primary.withValues(alpha: .15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: scheme.primary.withValues(
                            alpha: index == _detail ? .58 : .18,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icons[index], size: 15, color: scheme.primary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              labels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (index != 2) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .72),
              ),
            ),
            child: Text(
              details[_detail],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _unifiedMetricCopy = <String, Map<String, String>>{
  'ar': {
    'value': 'القيمة',
    'unit': 'الوحدة',
    'logging': 'التسجيل',
    'noUnit': 'بدون وحدة',
    'logged': 'مسجل لليوم',
    'notLogged': 'غير مسجل بعد',
  },
  'en': {
    'value': 'Value',
    'unit': 'Unit',
    'logging': 'Logging',
    'noUnit': 'No unit',
    'logged': 'Logged today',
    'notLogged': 'Not logged yet',
  },
  'fr': {
    'value': 'Valeur',
    'unit': 'Unité',
    'logging': 'Suivi',
    'noUnit': 'Sans unité',
    'logged': "Enregistré aujourd’hui",
    'notLogged': 'Pas encore enregistré',
  },
  'es': {
    'value': 'Valor',
    'unit': 'Unidad',
    'logging': 'Registro',
    'noUnit': 'Sin unidad',
    'logged': 'Registrado hoy',
    'notLogged': 'Aún no registrado',
  },
  'tr': {
    'value': 'Değer',
    'unit': 'Birim',
    'logging': 'Kayıt',
    'noUnit': 'Birim yok',
    'logged': 'Bugün kaydedildi',
    'notLogged': 'Henüz kaydedilmedi',
  },
};
