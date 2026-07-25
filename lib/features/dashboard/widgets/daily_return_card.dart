import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../engine/daily_return_engine.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../shared/widgets/premium_surface.dart';

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = switch (report.state) {
      DailyReturnState.empty => context.strings.text('Start today calmly'),
      DailyReturnState.partial => context.strings.text('Continue today'),
      DailyReturnState.complete => context.strings.text('Today is covered'),
      DailyReturnState.gentleReturn || DailyReturnState.rebuilding =>
        context.strings.text('Welcome back — start with today'),
    };
    return Semantics(
      container: true,
      label: context.strings.text('Daily return summary'),
      child: PremiumSurface(
        emphasized: true,
        padding: EdgeInsets.zero,
        child: Theme(
          data: _dashboardSurfaceTheme(context),
          child: Container(
            padding: PremiumDesignTokens.cardPaddingLarge,
            decoration: BoxDecoration(
              borderRadius: PremiumDesignTokens.cardRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xF00A1724),
                        Color(0xEE102235),
                        Color(0xF207111D),
                      ]
                    : const [
                        Color(0xF7F1F7F7),
                        Color(0xF3E4F0F2),
                        Color(0xF7EDF3EF),
                      ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (report.daysAway >= 4) ...[
                  const SizedBox(height: PremiumDesignTokens.spaceXs - 2),
                  Text(
                    context.strings.text(
                      'No backfill is required. Your earlier local records remain usable; today can be a fresh observation.',
                    ),
                  ),
                ],
                const SizedBox(height: PremiumDesignTokens.spaceMd),
                Wrap(
                  spacing: PremiumDesignTokens.spaceSm,
                  runSpacing: PremiumDesignTokens.spaceSm,
                  children: [
                    _Status(
                      label: context.strings.text('Weight'),
                      recorded: report.hasWeight,
                    ),
                    _Status(
                      label: context.strings.text('Meals'),
                      recorded: report.hasMeals,
                    ),
                    _Status(
                      label: context.strings.text('Water'),
                      recorded: report.hasWater,
                    ),
                  ],
                ),
                const SizedBox(height: PremiumDesignTokens.spaceMd),
                _InsightGrid(
                  insights: [
                    (context.strings.text('What changed'), changedSummary),
                    (
                      context.strings.text('Important missing evidence'),
                      missingEvidence,
                    ),
                    if (report.hasPrimaryAction) ...[
                      (
                        context.strings.text('Why this action appears'),
                        actionReason,
                      ),
                      (context.strings.text('Evidence used'), changedSummary),
                      (
                        context.strings.text('Evidence missing'),
                        missingEvidence,
                      ),
                      (
                        context.strings.text('Confidence'),
                        _confidenceLabel(context),
                      ),
                    ],
                  ],
                ),
                if (report.hasPrimaryAction) ...[
                  if (recommendationTimeHorizon != null) ...[
                    const SizedBox(height: PremiumDesignTokens.spaceSm),
                    _LabeledInsight(
                      label: context.strings.text('Time horizon'),
                      value: recommendationTimeHorizon!,
                    ),
                  ],
                  if (alternativeExplanation != null) ...[
                    const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
                    _LabeledInsight(
                      label: context.strings.text('Alternative explanation'),
                      value: alternativeExplanation!,
                    ),
                  ],
                  if (onPrimaryAction != null) ...[
                    const SizedBox(height: PremiumDesignTokens.spaceMd),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onPrimaryAction,
                        child: Text(actionTitle),
                      ),
                    ),
                  ],
                  if (onDismissRecommendation != null ||
                      onCorrectRecommendation != null ||
                      onRecommendationFeedback != null) ...[
                    const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
                    Wrap(
                      spacing: PremiumDesignTokens.spaceSm,
                      runSpacing: PremiumDesignTokens.spaceSm,
                      children: [
                        if (onDismissRecommendation != null)
                          OutlinedButton(
                            onPressed: onDismissRecommendation,
                            child: Text(context.strings.text('Dismiss')),
                          ),
                        if (onCorrectRecommendation != null)
                          OutlinedButton(
                            onPressed: onCorrectRecommendation,
                            child: Text(context.strings.text('Correct')),
                          ),
                        if (onRecommendationFeedback != null)
                          OutlinedButton(
                            onPressed: onRecommendationFeedback,
                            child: Text(context.strings.text('Feedback')),
                          ),
                      ],
                    ),
                  ],
                ] else
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      context.strings.text(
                        'No corrective action is needed from the evidence recorded today because the current evidence is insufficient or does not support a safer recommendation.',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
