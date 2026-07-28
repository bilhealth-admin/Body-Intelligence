import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../engine/daily_return_engine.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../shared/widgets/premium_surface.dart';
import 'dashboard_carousel.dart';

class DailyReturnCard extends StatelessWidget {
  const DailyReturnCard({
    super.key,
    required this.report,
    required this.changedSummary,
    required this.actionTitle,
    required this.actionReason,
    required this.missingEvidence,
    required this.onPrimaryAction,
    this.onDismissRecommendation,
    this.onCorrectRecommendation,
    this.onRecommendationFeedback,
    this.recommendationTimeHorizon,
    this.alternativeExplanation,
  });

  final DailyReturnReport report;
  final String changedSummary;
  final String actionTitle;
  final String actionReason;
  final String missingEvidence;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onDismissRecommendation;
  final VoidCallback? onCorrectRecommendation;
  final VoidCallback? onRecommendationFeedback;
  final String? recommendationTimeHorizon;
  final String? alternativeExplanation;

  @override
  Widget build(BuildContext context) {
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    String tr(String en, String ar) => arabic ? ar : en;
    final title = switch (report.state) {
      DailyReturnState.empty => tr('Start today calmly', 'ابدأ يومك بهدوء'),
      DailyReturnState.partial => tr('Continue today', 'واصل يومك'),
      DailyReturnState.complete => tr('Today is covered', 'اكتمل يومك'),
      DailyReturnState.gentleReturn || DailyReturnState.rebuilding => tr(
        'Welcome back — start with today',
        'مرحبًا بعودتك — ابدأ من اليوم',
      ),
    };
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final height = MediaQuery.textScalerOf(context)
        .scale(desktop ? 92 : 132)
        .clamp(desktop ? 92.0 : 132.0, desktop ? 120.0 : 190.0);
    final pages = [
      _FollowDayCard(
        icon: Icons.monitor_weight_outlined,
        label: tr('Weight', 'الوزن'),
        recorded: report.hasWeight,
        recordedText: tr('Today’s weight is recorded.', 'تم تسجيل وزن اليوم.'),
        missingText: tr(
          'Add a comparable weight when it suits you.',
          'أضف قياس وزن قابلًا للمقارنة عندما يناسبك.',
        ),
      ),
      _FollowDayCard(
        icon: Icons.restaurant_outlined,
        label: tr('Meals', 'الوجبات'),
        recorded: report.hasMeals,
        recordedText: tr(
          'Today’s meals are contributing to your live totals.',
          'تسهم وجبات اليوم في إجمالياتك الحالية.',
        ),
        missingText: tr(
          'Record a meal to complete today’s nutrition picture.',
          'سجّل وجبة لاستكمال صورة تغذية اليوم.',
        ),
      ),
      _FollowDayCard(
        icon: Icons.water_drop_outlined,
        label: tr('Water', 'الماء'),
        recorded: report.hasWater,
        recordedText: tr(
          'Today’s hydration is recorded.',
          'تم تسجيل ترطيب اليوم.',
        ),
        missingText: tr(
          'Record water as you move through the day.',
          'سجّل الماء تدريجيًا خلال يومك.',
        ),
      ),
    ];

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          tr('Follow Your Day', 'تابع يومك'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final carousel = DashboardCarousel(
      key: const Key('follow-your-day-carousel'),
      height: height,
      viewportFraction: .94,
      semanticLabel: tr('Follow Your Day', 'تابع يومك'),
      pages: pages,
    );

    return Semantics(
      container: true,
      label: tr('Follow Your Day', 'تابع يومك'),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 210, child: heading),
                const SizedBox(width: PremiumDesignTokens.spaceMd),
                Expanded(child: carousel),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [heading, const SizedBox(height: 6), carousel],
            ),
    );
  }

  // Retained for backwards-compatible recommendation semantics.
  // ignore: unused_element
  String _confidenceLabel(BuildContext context) {
    final reliability = report.honesty.reliability;
    if (reliability == DataReliability.strong) {
      return context.strings.text('High');
    }
    if (reliability == DataReliability.useful) {
      return context.strings.text('Moderate');
    }
    if (reliability == DataReliability.emerging) {
      return context.strings.text('Low');
    }
    return context.strings.text('Insufficient data');
  }
}

class _FollowDayCard extends StatelessWidget {
  const _FollowDayCard({
    required this.icon,
    required this.label,
    required this.recorded,
    required this.recordedText,
    required this.missingText,
  });

  final IconData icon;
  final String label;
  final bool recorded;
  final String recordedText;
  final String missingText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumSurface(
      emphasized: recorded,
      dashboardGlass: true,
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: .13),
              border: Border.all(color: scheme.primary.withValues(alpha: .28)),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: PremiumDesignTokens.spaceMd),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Icon(
                      recorded
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 20,
                      color: recorded
                          ? const Color(0xFF65E5B1)
                          : scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  recorded ? recordedText : missingText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
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

class _LabeledInsight extends StatelessWidget {
  const _LabeledInsight({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
      ),
      const SizedBox(height: PremiumDesignTokens.spaceXs),
      Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.48,
        ),
      ),
    ],
  );
}

// ignore: unused_element
class _InsightGrid extends StatelessWidget {
  const _InsightGrid({required this.insights});

  final List<(String, String)> insights;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final gap = PremiumDesignTokens.spaceSm;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final insight in insights)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 108),
                  padding: const EdgeInsets.all(PremiumDesignTokens.spaceSm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: .36),
                    borderRadius: BorderRadius.circular(
                      PremiumDesignTokens.radiusMd,
                    ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: _LabeledInsight(label: insight.$1, value: insight.$2),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ignore: unused_element
class _Status extends StatelessWidget {
  const _Status({required this.label, required this.recorded});
  final String label;
  final bool recorded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: .68),
      side: BorderSide(
        color: recorded ? const Color(0xFF42D9E9) : const Color(0xFF91A7B4),
        width: 1.2,
      ),
      avatar: Icon(
        recorded ? Icons.check_circle : Icons.circle_outlined,
        size: 18,
        color: recorded ? scheme.primary : scheme.onSurfaceVariant,
      ),
      label: Text(
        '$label · ${context.strings.text(recorded ? 'recorded' : 'missing')}',
        style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ignore: unused_element
ThemeData _dashboardSurfaceTheme(BuildContext context) {
  final base = Theme.of(context);
  final dark = base.brightness == Brightness.dark;
  final textTheme = base.textTheme.apply(
    bodyColor: base.colorScheme.onSurface,
    displayColor: base.colorScheme.onSurface,
  );

  return base.copyWith(
    textTheme: textTheme,
    dividerColor: base.colorScheme.outlineVariant,
    colorScheme: base.colorScheme.copyWith(
      surface: dark ? const Color(0xFF0A1724) : const Color(0xFFEAF2F3),
      onSurface: base.colorScheme.onSurface,
      primary: dark ? const Color(0xFF35D2E5) : const Color(0xFF087F91),
      onPrimary: dark ? const Color(0xFF001318) : Colors.white,
    ),
  );
}
