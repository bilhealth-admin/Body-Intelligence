import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../engine/daily_return_engine.dart';
import '../../../engine/data_honesty_engine.dart';

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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(PremiumDesignTokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
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
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              Wrap(
                spacing: PremiumDesignTokens.spaceXs,
                runSpacing: PremiumDesignTokens.spaceXs,
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
              const SizedBox(height: PremiumDesignTokens.spaceSm + 2),
              Text(
                context.strings.text('What changed'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(changedSummary),
              const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
              Text(
                context.strings.text('Important missing evidence'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(missingEvidence),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              if (report.hasPrimaryAction) ...[
                Text(
                  context.strings.text('Why this action appears'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(actionReason),
                const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
                Text(
                  context.strings.text('Evidence used'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(changedSummary),
                const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
                Text(
                  context.strings.text('Evidence missing'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(missingEvidence),
                const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
                Text(
                  context.strings.text('Confidence'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(_confidenceLabel(context)),
                if (recommendationTimeHorizon != null) ...[
                  const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
                  Text(
                    context.strings.text('Time horizon'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(recommendationTimeHorizon!),
                ],
                if (alternativeExplanation != null) ...[
                  const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
                  Text(
                    context.strings.text('Alternative explanation'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(alternativeExplanation!),
                ],
                const SizedBox(height: PremiumDesignTokens.spaceMd),
                FilledButton(
                  onPressed: onPrimaryAction,
                  child: Text(actionTitle),
                ),
                if (onDismissRecommendation != null ||
                    onCorrectRecommendation != null ||
                    onRecommendationFeedback != null) ...[
                  const SizedBox(height: PremiumDesignTokens.spaceXs + 2),
                  Wrap(
                    spacing: PremiumDesignTokens.spaceXs,
                    runSpacing: PremiumDesignTokens.spaceXs,
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

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.recorded});
  final String label;
  final bool recorded;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      recorded ? Icons.check_circle : Icons.circle_outlined,
      size: 18,
    ),
    label: Text(
      '$label · ${context.strings.text(recorded ? 'recorded' : 'missing')}',
    ),
  );
}
