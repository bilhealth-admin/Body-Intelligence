import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import 'dashboard_carousel.dart';

/// Presentation-only benchmark for the premium dashboard hierarchy.
///
/// It receives already-computed, human-readable intelligence from the current
/// dashboard composition and deliberately owns no providers or calculations.
class PremiumDashboardBenchmark extends StatelessWidget {
  const PremiumDashboardBenchmark({
    super.key,
    required this.arabic,
    required this.actionTitle,
    required this.actionReason,
    required this.actionEvidence,
    required this.confidence,
    required this.onAction,
    required this.dailyIntelligence,
    this.hero,
    this.progressSection,
    this.personalHealthAi,
    this.connectedHealth,
    required this.bodyTwinSummary,
    required this.bodyTwinEvidence,
    required this.nutritionSummary,
    required this.nutritionEvidence,
    required this.trendSummary,
    required this.trendEvidence,
    required this.loggingItems,
    this.showRecommendation = true,
    this.insightTitle,
    this.insightSummary,
  });

  final bool arabic;
  final String actionTitle;
  final String actionReason;
  final String actionEvidence;
  final String confidence;
  final VoidCallback? onAction;
  final Widget dailyIntelligence;
  final Widget? hero;
  final Widget? progressSection;
  final Widget? personalHealthAi;
  final Widget? connectedHealth;
  final String bodyTwinSummary;
  final String bodyTwinEvidence;
  final String nutritionSummary;
  final String nutritionEvidence;
  final String trendSummary;
  final String trendEvidence;
  final List<DashboardLoggingItem> loggingItems;
  final bool showRecommendation;
  final String? insightTitle;
  final String? insightSummary;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = dark ? scheme.onSurface : const Color(0xFF061A2B);
    final phone = MediaQuery.sizeOf(context).width < 600;
    final scaledHeight = MediaQuery.textScalerOf(
      context,
    ).scale(phone ? 280 : 190).clamp(phone ? 280.0 : 190.0, 300.0);
    final insightCards = <Widget>[
      _CompactInsightCard(
        key: const Key('dashboard-nutrition-context'),
        eyebrow: '',
        title: showRecommendation
            ? tr('Protein below target', 'البروتين أقل من الهدف')
            : tr('Nutrition signal', 'إشارة التغذية'),
        interpretation: nutritionSummary,
        evidence: nutritionEvidence,
        accent: const Color(0xFF65E5B1),
        matchPersonalAiSurface: true,
      ),
      _CompactInsightCard(
        key: const Key('dashboard-action-insight'),
        eyebrow: tr('DAILY INTELLIGENCE', 'الذكاء اليومي'),
        title: insightTitle ?? actionTitle,
        interpretation: insightSummary ?? actionReason,
        evidence: actionEvidence,
        accent: const Color(0xFF58D8FF),
        onTap: onAction,
      ),
    ];

    return LayoutBuilder(
      key: const Key('premium-dashboard-benchmark'),
      builder: (context, constraints) {
        final sectionGap = constraints.maxWidth >= 900
            ? 12.0
            : PremiumDesignTokens.spaceMd;
        final insights = _KeyInsightsDeck(
          title: tr("Today's Insights", "Today's Insights"),
          contentColor: contentColor,
          height: scaledHeight,
          pages: insightCards,
          compact: phone,
        );
        Widget intelligenceFor(double width) {
          if (personalHealthAi == null) return insights;
          if (width < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                personalHealthAi!,
                SizedBox(height: sectionGap),
                insights,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: personalHealthAi!),
              const SizedBox(width: PremiumDesignTokens.spaceMd),
              Expanded(child: insights),
            ],
          );
        }

        final top = hero == null
            ? intelligenceFor(constraints.maxWidth)
            : constraints.maxWidth < 1180
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero!,
                  SizedBox(height: sectionGap),
                  intelligenceFor(constraints.maxWidth),
                ],
              )
            : Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: hero!),
                    const SizedBox(width: PremiumDesignTokens.spaceMd),
                    Expanded(
                      flex: 9,
                      child: LayoutBuilder(
                        builder: (context, panelConstraints) =>
                            intelligenceFor(panelConstraints.maxWidth),
                      ),
                    ),
                  ],
                ),
              );
        final dailyContent = Semantics(
          container: true,
          label: tr('Daily Intelligence', 'الذكاء اليومي'),
          child: dailyIntelligence,
        );
        final pairDaySections = constraints.maxWidth >= 1400;
        final daily = pairDaySections
            ? PremiumSurface(
                dashboardGlass: true,
                padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
                child: dailyContent,
              )
            : dailyContent;
        final dayAndProgress = progressSection != null && pairDaySections
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: daily),
                  const SizedBox(width: PremiumDesignTokens.spaceMd),
                  Expanded(child: progressSection!),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  daily,
                  if (progressSection != null) ...[
                    SizedBox(height: sectionGap),
                    progressSection!,
                  ],
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            top,
            if (connectedHealth != null) ...[
              SizedBox(height: sectionGap),
              connectedHealth!,
            ],
            SizedBox(height: sectionGap),
            dayAndProgress,
          ],
        );
      },
    );
  }
}

class _KeyInsightsDeck extends StatelessWidget {
  const _KeyInsightsDeck({
    required this.title,
    required this.contentColor,
    required this.height,
    required this.pages,
    this.compact = false,
  });

  final String title;
  final Color contentColor;
  final double height;
  final List<Widget> pages;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      dashboardGlass: true,
      padding: compact
          ? const EdgeInsets.all(PremiumDesignTokens.spaceSm)
          : PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style:
                  (compact
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(
                        color: contentColor,
                        fontWeight: FontWeight.w900,
                      ),
            ),
          ),
          const SizedBox(height: 6),
          DashboardCarousel(
            key: const Key('dashboard-key-insights-carousel'),
            height: height,
            viewportFraction: .88,
            compactControls: compact,
            semanticLabel: title,
            pages: pages,
          ),
        ],
      ),
    );
  }
}

class _CompactInsightCard extends StatelessWidget {
  const _CompactInsightCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.interpretation,
    required this.evidence,
    required this.accent,
    this.onTap,
    this.matchPersonalAiSurface = false,
  });

  final String eyebrow;
  final String title;
  final String interpretation;
  final String evidence;
  final Color accent;
  final VoidCallback? onTap;
  final bool matchPersonalAiSurface;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow.isNotEmpty) ...[
            Icon(Icons.auto_awesome_rounded, size: 20, color: accent),
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            Text(
              eyebrow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              interpretation,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          Text(
            evidence,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (!matchPersonalAiSurface) {
      return PremiumSurface(
        onTap: onTap,
        dashboardGlass: true,
        padding: EdgeInsets.zero,
        child: content,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .105),
              const Color(0xFF5BDAFF).withValues(alpha: .045),
              Colors.white.withValues(alpha: .035),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

class DashboardLoggingItem {
  const DashboardLoggingItem({required this.label, required this.recorded});

  final String label;
  final bool recorded;
}

// ignore: unused_element
class _EvidenceSequence extends StatelessWidget {
  const _EvidenceSequence({
    required this.evidence,
    required this.confidence,
    required this.arabic,
  });

  final String evidence;
  final String confidence;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: PremiumDesignTokens.spaceSm,
      runSpacing: PremiumDesignTokens.spaceSm,
      children: [
        _EvidencePill(
          key: const Key('dashboard-action-evidence'),
          label: arabic ? 'الدليل' : 'Evidence',
          value: evidence,
        ),
        _EvidencePill(
          key: const Key('dashboard-action-confidence'),
          label: arabic ? 'الثقة' : 'Confidence',
          value: confidence,
        ),
      ],
    );
  }
}

class _EvidencePill extends StatelessWidget {
  const _EvidencePill({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = dark ? scheme.onSurface : const Color(0xFF102033);
    return Container(
      constraints: const BoxConstraints(minHeight: 48, maxWidth: 420),
      padding: const EdgeInsets.symmetric(
        horizontal: PremiumDesignTokens.spaceSm,
        vertical: PremiumDesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: dark
            ? scheme.surfaceContainerHighest.withValues(alpha: .64)
            : const Color(0xFFDDECF0).withValues(alpha: .82),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: dark ? .92 : .78),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: PremiumDesignTokens.spaceXs),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label · ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: value),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: contentColor,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _IntelligencePreview extends StatelessWidget {
  const _IntelligencePreview({
    // ignore: unused_element_parameter
    super.key,
    required this.eyebrow,
    required this.title,
    required this.interpretation,
    required this.evidence,
    required this.unknownLabel,
  });

  final String eyebrow;
  final String title;
  final String interpretation;
  final String evidence;
  final String unknownLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = dark ? scheme.onSurface : const Color(0xFF102033);
    final mutedColor = dark ? scheme.onSurfaceVariant : const Color(0xFF526777);
    return Semantics(
      container: true,
      label: '$title. $interpretation. Evidence: $evidence. $unknownLabel',
      child: PremiumSurface(
        semanticContainer: false,
        padding: EdgeInsets.zero,
        child: Container(
          padding: PremiumDesignTokens.cardPaddingLarge,
          decoration: BoxDecoration(
            borderRadius: PremiumDesignTokens.cardRadius,
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: dark
                  ? [const Color(0xE9122234), const Color(0xF00A1826)]
                  : [const Color(0xF7F1F7F7), const Color(0xF2E3F0F2)],
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: dark ? .72 : .82),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Eyebrow(label: eyebrow),
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: contentColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceXs),
              Text(
                interpretation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: contentColor,
                  height: 1.48,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              Text(
                evidence,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                  height: 1.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceXs),
              Text(
                unknownLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: dark
                      ? const Color(0xFF63DDB5)
                      : const Color(0xFF087D68),
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _LoggingCompleteness extends StatelessWidget {
  const _LoggingCompleteness({required this.arabic, required this.items});

  final bool arabic;
  final List<DashboardLoggingItem> items;

  @override
  Widget build(BuildContext context) {
    final recorded = items.where((item) => item.recorded).length;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: arabic
          ? 'اكتمال التسجيل: $recorded من ${items.length}'
          : 'Logging completeness: $recorded of ${items.length}',
      child: PremiumSurface(
        semanticContainer: false,
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PremiumDesignTokens.spaceMd,
            vertical: PremiumDesignTokens.spaceSm,
          ),
          decoration: BoxDecoration(
            borderRadius: PremiumDesignTokens.cardRadius,
            gradient: LinearGradient(
              colors: dark
                  ? const [Color(0xE9122234), Color(0xF00A1826)]
                  : const [Color(0xF7F1F7F7), Color(0xF2E3F0F2)],
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: dark ? .72 : .82),
            ),
          ),
          child: Wrap(
            spacing: PremiumDesignTokens.spaceMd,
            runSpacing: PremiumDesignTokens.spaceXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: _Eyebrow(
                  label: arabic ? 'اكتمال التسجيل' : 'LOGGING COMPLETENESS',
                ),
              ),
              for (final item in items)
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  avatar: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.recorded
                          ? scheme.tertiary
                          : Colors.transparent,
                      border: Border.all(
                        color: item.recorded
                            ? scheme.tertiary
                            : scheme.onSurfaceVariant,
                        width: 1.5,
                      ),
                    ),
                  ),
                  label: Text(item.label),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
              Text(
                '$recorded/${items.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: PremiumDesignTokens.spaceXs),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
      ],
    );
  }
}
