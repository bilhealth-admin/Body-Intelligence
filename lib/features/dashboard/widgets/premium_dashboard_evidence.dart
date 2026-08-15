part of 'premium_dashboard_benchmark.dart';

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
          label: dashboardFiveLocaleText('Evidence', 'الدليل'),
          value: evidence,
        ),
        _EvidencePill(
          key: const Key('dashboard-action-confidence'),
          label: dashboardFiveLocaleText('Confidence', 'الثقة'),
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
                  fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
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
                  label: dashboardFiveLocaleText(
                    'LOGGING COMPLETENESS',
                    'اكتمال التسجيل',
                  ),
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
                  fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
        ),
      ],
    );
  }
}
