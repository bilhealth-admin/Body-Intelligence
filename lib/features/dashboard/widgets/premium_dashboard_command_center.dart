part of 'premium_dashboard_benchmark.dart';

// Retained for the wide-screen insights composition while the mobile release
// uses the consolidated Body Twin rail.
// ignore: unused_element
class _PrimaryInsightsPage extends StatelessWidget {
  const _PrimaryInsightsPage({
    required this.semanticLabel,
    required this.pages,
  });

  final String semanticLabel;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: semanticLabel,
      child: KeyedSubtree(
        key: const Key('dashboard-insights-static-body-twin-content'),
        child: pages.first,
      ),
    );
  }
}

// Retained for the large-screen release layout.
// ignore: unused_element
class _PrimaryActionDeck extends StatelessWidget {
  const _PrimaryActionDeck({required this.semanticLabel, required this.pages});

  final String semanticLabel;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: semanticLabel,
      child: KeyedSubtree(
        key: const Key('dashboard-action-static-body-twin-content'),
        child: pages.first,
      ),
    );
  }
}

// Retained as a rollback-safe presentation fallback; it does not calculate.
// ignore: unused_element
class _MobileCommandCenter extends StatelessWidget {
  const _MobileCommandCenter({
    required this.arabic,
    required this.actionTitle,
    required this.actionReason,
    required this.actionEvidence,
    required this.confidence,
    required this.missingEvidence,
    required this.abstentionReason,
    required this.onAction,
    required this.onExplain,
    required this.onAccepted,
    required this.onDone,
    required this.onNotSuitable,
    required this.loggingItems,
  });

  final bool arabic;
  final String actionTitle;
  final String actionReason;
  final String actionEvidence;
  final String confidence;
  final String missingEvidence;
  final String? abstentionReason;
  final VoidCallback? onAction;
  final VoidCallback? onExplain;
  final VoidCallback? onAccepted;
  final VoidCallback? onDone;
  final VoidCallback? onNotSuitable;
  final List<DashboardLoggingItem> loggingItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recorded = loggingItems.where((item) => item.recorded).length;

    return Semantics(
      container: true,
      label: arabic
          ? 'أفضل خطوة الآن: $actionTitle. $actionReason. الثقة: $confidence.'
          : 'One best action: $actionTitle. $actionReason. Confidence: $confidence.',
      child: PremiumSurface(
        key: const Key('dashboard-mobile-command-center'),
        level: PremiumSurfaceLevel.primary,
        semanticContainer: false,
        padding: PremiumDesignTokens.cardPaddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Eyebrow(
              label: dashboardFiveLocaleText(
                'ONE BEST ACTION',
                'أفضل خطوة الآن',
              ),
            ),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            Text(
              actionTitle,
              key: const Key('dashboard-mobile-command-title'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            Text(
              actionReason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: PremiumDesignTokens.spaceMd),
            if (missingEvidence.trim().isNotEmpty ||
                (abstentionReason?.trim().isNotEmpty ?? false))
              _TruthExplanationSurface(
                arabic: arabic,
                reason: actionReason,
                evidence: actionEvidence,
                confidence: confidence,
                missingEvidence: missingEvidence,
                abstentionReason: abstentionReason,
              )
            else
              _EvidenceSequence(
                evidence: actionEvidence,
                confidence: confidence,
                arabic: arabic,
              ),
            const SizedBox(height: PremiumDesignTokens.spaceMd),
            OutlinedButton.icon(
              key: const Key('dashboard-explain-decision'),
              onPressed: onExplain,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                dashboardFiveLocaleText(
                  'View decision details',
                  'اعرض تفاصيل القرار',
                ),
              ),
            ),
            Semantics(
              label: arabic
                  ? 'اكتمال التسجيل: $recorded من ${loggingItems.length}'
                  : 'Logging completeness: $recorded of ${loggingItems.length}',
              child: Wrap(
                spacing: PremiumDesignTokens.spaceXs,
                runSpacing: PremiumDesignTokens.spaceXs,
                children: [
                  for (final item in loggingItems)
                    Chip(
                      key: ValueKey('dashboard-mobile-log-${item.label}'),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: Icon(
                        item.recorded
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: item.recorded
                            ? scheme.tertiary
                            : scheme.onSurfaceVariant,
                      ),
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
            if (onAccepted != null ||
                onDone != null ||
                onNotSuitable != null) ...[
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              Wrap(
                key: const Key('dashboard-decision-feedback'),
                spacing: PremiumDesignTokens.spaceXs,
                runSpacing: PremiumDesignTokens.spaceXs,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('dashboard-decision-accepted'),
                    onPressed: onAccepted,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      dashboardFiveLocaleText('I’ll do it', 'سأنفذها'),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('dashboard-decision-done'),
                    onPressed: onDone,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(dashboardFiveLocaleText('Done', 'تم')),
                  ),
                  TextButton.icon(
                    key: const Key('dashboard-decision-not-suitable'),
                    onPressed: onNotSuitable,
                    icon: const Icon(Icons.block_rounded),
                    label: Text(
                      dashboardFiveLocaleText('Not suitable', 'غير مناسبة'),
                    ),
                  ),
                ],
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              FilledButton.icon(
                key: const Key('dashboard-mobile-command-action'),
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  dashboardFiveLocaleText(
                    'Take action now',
                    'نفّذ الخطوة الآن',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TruthExplanationSurface extends StatelessWidget {
  const _TruthExplanationSurface({
    required this.arabic,
    required this.reason,
    required this.evidence,
    required this.confidence,
    required this.missingEvidence,
    required this.abstentionReason,
  });

  final bool arabic;
  final String reason;
  final String evidence;
  final String confidence;
  final String missingEvidence;
  final String? abstentionReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.45,
    );

    Widget explanationRow({
      required Key key,
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Semantics(
        key: key,
        label: '$label: $value',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: PremiumDesignTokens.spaceXs),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label\n',
                      style: textStyle?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: value, style: textStyle),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('dashboard-truth-explanation-surface'),
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dashboardFiveLocaleText(
              'Why BIL believes this',
              'لماذا يعتقد BIL ذلك؟',
            ),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          explanationRow(
            key: const Key('dashboard-truth-reason'),
            icon: Icons.psychology_alt_outlined,
            label: dashboardFiveLocaleText('Interpretation', 'التفسير'),
            value: reason,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          explanationRow(
            key: const Key('dashboard-truth-evidence'),
            icon: Icons.fact_check_outlined,
            label: dashboardFiveLocaleText('Evidence used', 'الدليل المستخدم'),
            value: evidence,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          explanationRow(
            key: const Key('dashboard-truth-confidence'),
            icon: Icons.verified_outlined,
            label: dashboardFiveLocaleText('Confidence', 'الثقة'),
            value: confidence,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          explanationRow(
            key: const Key('dashboard-truth-missing-evidence'),
            icon: Icons.manage_search_rounded,
            label: dashboardFiveLocaleText('Evidence gap', 'فجوة الدليل'),
            value: missingEvidence,
          ),
          if (abstentionReason != null &&
              abstentionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            explanationRow(
              key: const Key('dashboard-truth-abstention'),
              icon: Icons.pause_circle_outline_rounded,
              label: dashboardFiveLocaleText(
                'Why BIL is holding back',
                'سبب الامتناع',
              ),
              value: abstentionReason!,
            ),
          ],
        ],
      ),
    );
  }
}
