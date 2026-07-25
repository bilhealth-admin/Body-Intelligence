import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';

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
    required this.bodyTwinSummary,
    required this.bodyTwinEvidence,
    required this.nutritionSummary,
    required this.nutritionEvidence,
    required this.trendSummary,
    required this.trendEvidence,
    required this.loggingItems,
    this.showRecommendation = true,
  });

  final bool arabic;
  final String actionTitle;
  final String actionReason;
  final String actionEvidence;
  final String confidence;
  final VoidCallback? onAction;
  final Widget dailyIntelligence;
  final String bodyTwinSummary;
  final String bodyTwinEvidence;
  final String nutritionSummary;
  final String nutritionEvidence;
  final String trendSummary;
  final String trendEvidence;
  final List<DashboardLoggingItem> loggingItems;
  final bool showRecommendation;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = dark ? scheme.onSurface : const Color(0xFF061A2B);
    final mutedColor = dark ? scheme.onSurfaceVariant : const Color(0xFF294456);
    return Column(
      key: const Key('premium-dashboard-benchmark'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRecommendation)
          Semantics(
            container: true,
            label: tr(
              'Protein recommendation. $actionTitle. Evidence: $actionEvidence. '
                  'Confidence: $confidence.',
              'توصية البروتين. $actionTitle. الدليل: $actionEvidence. '
                  'الثقة: $confidence.',
            ),
            child: PremiumSurface(
              semanticContainer: false,
              emphasized: true,
              padding: EdgeInsets.zero,
              child: Container(
                key: const Key('dashboard-one-best-action'),
                padding: const EdgeInsets.symmetric(
                  horizontal: PremiumDesignTokens.spaceLg,
                  vertical: PremiumDesignTokens.spaceMd,
                ),
                decoration: BoxDecoration(
                  borderRadius: PremiumDesignTokens.cardRadius,
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: highContrast
                        ? [scheme.surface, scheme.surface]
                        : dark
                        ? [
                            const Color(0xF20A1827),
                            const Color(0xEC102536),
                            const Color(0xF207111D),
                          ]
                        : [
                            const Color(0xFFF2F8FA),
                            const Color(0xFFE2EFF3),
                            const Color(0xFFEAF2F3),
                          ],
                  ),
                  border: Border.all(
                    color: highContrast
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: .86),
                    width: highContrast ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: dark
                          ? Colors.black.withValues(alpha: .20)
                          : const Color(0xFF4F7887).withValues(alpha: .12),
                      blurRadius: dark ? 22 : 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Eyebrow(
                      label: tr('PROTEIN RECOMMENDATION', 'توصية البروتين'),
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceXs),
                    Semantics(
                      header: true,
                      child: Text(
                        actionTitle,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: contentColor,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                            ),
                      ),
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceXs),
                    Text(
                      actionReason,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceMd),
                    _EvidenceSequence(
                      evidence: actionEvidence,
                      confidence: confidence,
                      arabic: arabic,
                    ),
                    if (onAction != null) ...[
                      const SizedBox(height: PremiumDesignTokens.spaceMd),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.icon(
                          onPressed: onAction,
                          icon: const SizedBox.shrink(),
                          style: FilledButton.styleFrom(
                            textStyle: Theme.of(context).textTheme.labelLarge,
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            elevation: dark ? 2 : 1,
                            shadowColor: scheme.primary.withValues(alpha: .28),
                          ),
                          label: Text(
                            tr('Take this action', 'نفّذ هذا الإجراء'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (showRecommendation)
          const SizedBox(height: PremiumDesignTokens.spaceMd),
        Semantics(
          container: true,
          label: tr('Daily Intelligence', 'الذكاء اليومي'),
          child: dailyIntelligence,
        ),
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        Semantics(
          header: true,
          child: Text(
            tr('Key insights today', 'أهم رؤى اليوم'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: contentColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: PremiumDesignTokens.spaceSm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 3
                : constraints.maxWidth >= 680
                ? 2
                : 1;
            final gap = PremiumDesignTokens.spaceMd;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: width,
                  child: _IntelligencePreview(
                    key: const Key('dashboard-body-twin-preview'),
                    eyebrow: tr('BODY TWIN', 'توأم الجسم'),
                    title: tr('Modeled direction', 'الاتجاه المُنمذج'),
                    interpretation: bodyTwinSummary,
                    evidence: bodyTwinEvidence,
                    unknownLabel: tr(
                      'A scenario is not a diagnosis or certainty.',
                      'السيناريو ليس تشخيصًا أو يقينًا.',
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _IntelligencePreview(
                    key: const Key('dashboard-nutrition-context'),
                    eyebrow: tr('NUTRITION CONTEXT', 'سياق التغذية'),
                    title: tr('What matters today', 'ما يهم اليوم'),
                    interpretation: nutritionSummary,
                    evidence: nutritionEvidence,
                    unknownLabel: tr(
                      'Unavailable nutrients remain unknown, never zero.',
                      'العناصر غير المتاحة تظل مجهولة ولا تُعرض كصفر.',
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _IntelligencePreview(
                    key: const Key('dashboard-trend-explanation'),
                    eyebrow: tr('TREND EXPLANATION', 'تفسير الاتجاه'),
                    title: tr('What changed', 'ما الذي تغيّر'),
                    interpretation: trendSummary,
                    evidence: trendEvidence,
                    unknownLabel: tr(
                      'A single reading does not prove a cause.',
                      'القراءة الواحدة لا تثبت سببًا.',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        _LoggingCompleteness(arabic: arabic, items: loggingItems),
      ],
    );
  }
}

class DashboardLoggingItem {
  const DashboardLoggingItem({required this.label, required this.recorded});

  final String label;
  final bool recorded;
}

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

class _IntelligencePreview extends StatelessWidget {
  const _IntelligencePreview({
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
