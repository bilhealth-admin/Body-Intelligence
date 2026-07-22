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
  final VoidCallback onPrimaryAction;
  final VoidCallback? onDismissRecommendation;
  final VoidCallback? onCorrectRecommendation;
  final VoidCallback? onRecommendationFeedback;
  final String? recommendationTimeHorizon;
  final String? alternativeExplanation;

  @override
  Widget build(BuildContext context) {
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
          data: _dashboardDarkSurfaceTheme(context),
          child: Container(
            padding: PremiumDesignTokens.cardPaddingLarge,
            decoration: BoxDecoration(
              borderRadius: PremiumDesignTokens.cardRadius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xE60A1724),
                  Color(0xDE102235),
                  Color(0xE607111D),
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
                      color: const Color(0xFFF3F7FA),
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
                _LabeledInsight(
                  label: context.strings.text('What changed'),
                  value: changedSummary,
                ),
                const SizedBox(height: PremiumDesignTokens.spaceSm),
                _LabeledInsight(
                  label: context.strings.text('Important missing evidence'),
                  value: missingEvidence,
                ),
                const SizedBox(height: PremiumDesignTokens.spaceLg),
                if (report.hasPrimaryAction) ...[
                  _LabeledInsight(
                    label: context.strings.text('Why this action appears'),
                    value: actionReason,
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  _LabeledInsight(
                    label: context.strings.text('Evidence used'),
                    value: changedSummary,
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  _LabeledInsight(
                    label: context.strings.text('Evidence missing'),
                    value: missingEvidence,
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  _LabeledInsight(
                    label: context.strings.text('Confidence'),
                    value: _confidenceLabel(context),
                  ),
                  if (recommendationTimeHorizon != null) ...[
                    const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
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
                  const SizedBox(height: PremiumDesignTokens.spaceMd),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPrimaryAction,
                      child: Text(actionTitle),
                    ),
                  ),
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
          color: const Color(0xFF9FE8F4),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
      ),
      const SizedBox(height: PremiumDesignTokens.spaceXs),
      Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFD6E1E8),
          height: 1.48,
        ),
      ),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.recorded});
  final String label;
  final bool recorded;

  @override
  Widget build(BuildContext context) => Chip(
    backgroundColor: const Color(0xFFF5F0E7),
    side: BorderSide(
      color: recorded ? const Color(0xFF42D9E9) : const Color(0xFF91A7B4),
      width: 1.2,
    ),
    avatar: Icon(
      recorded ? Icons.check_circle : Icons.circle_outlined,
      size: 18,
      color: recorded ? const Color(0xFF12BFD0) : const Color(0xFF6A8796),
    ),
    label: Text(
      '$label · ${context.strings.text(recorded ? 'recorded' : 'missing')}',
      style: const TextStyle(
        color: Color(0xFF263B47),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

ThemeData _dashboardDarkSurfaceTheme(BuildContext context) {
  final base = Theme.of(context);
  final textTheme = base.textTheme.apply(
    bodyColor: const Color(0xFFD6E1E8),
    displayColor: const Color(0xFFF3F7FA),
  );

  return base.copyWith(
    textTheme: textTheme,
    dividerColor: const Color(0x335ED9EA),
    colorScheme: base.colorScheme.copyWith(
      surface: const Color(0xFF0A1724),
      onSurface: const Color(0xFFE8F0F5),
      primary: const Color(0xFF35D2E5),
      onPrimary: const Color(0xFF001318),
    ),
  );
}
