import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import 'dashboard_twin_deck_shell.dart';

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
    this.missingEvidence = '',
    this.abstentionReason,
    required this.onAction,
    this.onExplain,
    this.onAccepted,
    this.onDone,
    this.onNotSuitable,
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
  final String missingEvidence;
  final String? abstentionReason;
  final VoidCallback? onAction;
  final VoidCallback? onExplain;
  final VoidCallback? onAccepted;
  final VoidCallback? onDone;
  final VoidCallback? onNotSuitable;
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
        eyebrow: '',
        title: insightTitle ?? actionTitle,
        interpretation: insightSummary ?? actionReason,
        evidence: actionEvidence,
        accent: const Color(0xFF58D8FF),
        onTap: phone ? onAction : (onExplain ?? onAction),
      ),
    ];

    return LayoutBuilder(
      key: const Key('premium-dashboard-benchmark'),
      builder: (context, constraints) {
        final sectionGap = constraints.maxWidth >= 900
            ? 12.0
            : PremiumDesignTokens.spaceMd;
        final insights = DashboardTwinDeckShell(
          key: const Key('dashboard-key-insights-deck'),
          title: tr("Today's Insights", "رؤى اليوم"),
          semanticLabel: tr("Today's Insights", "رؤى اليوم"),
          subtitle: tr('What BIL sees', 'ما يراه BIL'),
          titleColor: contentColor,
          pages: insightCards,
          compact: phone,
        );
        Widget intelligenceFor(double width) {
          final twinHeight = MediaQuery.textScalerOf(
            context,
          ).scale(phone ? 420.0 : 390.0).clamp(phone ? 420.0 : 390.0, 540.0);
          if (personalHealthAi == null) {
            return SizedBox(height: twinHeight, child: insights);
          }
          if (phone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const Key('dashboard-mobile-personal-ai-slot'),
                  height: twinHeight,
                  child: personalHealthAi!,
                ),
                SizedBox(height: sectionGap),
                SizedBox(
                  key: const Key('dashboard-mobile-insights-slot'),
                  height: twinHeight,
                  child: insights,
                ),
              ],
            );
          }
          return SizedBox(
            height: twinHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SizedBox.expand(
                    key: const Key('dashboard-tablet-personal-ai-slot'),
                    child: personalHealthAi!,
                  ),
                ),
                const SizedBox(width: PremiumDesignTokens.spaceMd),
                Expanded(
                  child: SizedBox.expand(
                    key: const Key('dashboard-tablet-insights-slot'),
                    child: insights,
                  ),
                ),
              ],
            ),
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
        final dayPairHeight = MediaQuery.textScalerOf(
          context,
        ).scale(188.0).clamp(188.0, 240.0);
        final dayAndProgress = progressSection != null && pairDaySections
            ? SizedBox(
                height: dayPairHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: SizedBox.expand(child: daily)),
                    const SizedBox(width: PremiumDesignTokens.spaceMd),
                    Expanded(child: SizedBox.expand(child: progressSection!)),
                  ],
                ),
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

        final mobileCommandCenter = phone
            ? _MobileCommandCenter(
                arabic: arabic,
                actionTitle: actionTitle,
                actionReason: actionReason,
                actionEvidence: actionEvidence,
                confidence: confidence,
                missingEvidence: missingEvidence,
                abstentionReason: abstentionReason,
                onAction: onAction,
                onExplain: onExplain,
                onAccepted: onAccepted,
                onDone: onDone,
                onNotSuitable: onNotSuitable,
                loggingItems: loggingItems,
              )
            : null;

        final mobileTwin = phone
            ? _MobileBodyTwinSnapshot(
                arabic: arabic,
                summary: bodyTwinSummary,
                evidence: bodyTwinEvidence,
                trendSummary: trendSummary,
                trendEvidence: trendEvidence,
              )
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mobileCommandCenter != null) ...[
              mobileCommandCenter,
              SizedBox(height: sectionGap),
            ],
            top,
            SizedBox(height: sectionGap),
            dayAndProgress,
            if (mobileTwin != null) ...[
              SizedBox(height: sectionGap),
              mobileTwin,
            ],
            if (connectedHealth != null) ...[
              SizedBox(height: sectionGap),
              connectedHealth!,
            ],
          ],
        );
      },
    );
  }
}

class _MobileBodyTwinSnapshot extends StatelessWidget {
  const _MobileBodyTwinSnapshot({
    required this.arabic,
    required this.summary,
    required this.evidence,
    required this.trendSummary,
    required this.trendEvidence,
  });

  final bool arabic;
  final String summary;
  final String evidence;
  final String trendSummary;
  final String trendEvidence;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumSurface(
      key: const Key('dashboard-mobile-body-twin-snapshot'),
      level: PremiumSurfaceLevel.detail,
      dashboardGlass: true,
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: .30),
                      scheme.tertiary.withValues(alpha: .12),
                    ],
                  ),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .36),
                  ),
                ),
                child: Icon(
                  Icons.accessibility_new_rounded,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: PremiumDesignTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('BODY TWIN', 'توأم الجسم'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .65,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('Your current body state', 'حالة جسمك الحالية'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          _TwinSignalRow(
            icon: Icons.timeline_rounded,
            label: tr('What changed', 'ما الذي تغيّر'),
            value: trendSummary,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          _TwinSignalRow(
            icon: Icons.science_outlined,
            label: tr('Model evidence', 'أدلة النموذج'),
            value: evidence,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          _TwinSignalRow(
            icon: Icons.fact_check_outlined,
            label: tr('Trend evidence', 'أدلة الاتجاه'),
            value: trendEvidence,
          ),
        ],
      ),
    );
  }
}

class _TwinSignalRow extends StatelessWidget {
  const _TwinSignalRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .78)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: PremiumDesignTokens.spaceSm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label · ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: value),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            _Eyebrow(label: arabic ? 'أفضل خطوة الآن' : 'ONE BEST ACTION'),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            Text(
              actionTitle,
              key: const Key('dashboard-mobile-command-title'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
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
                arabic ? 'اعرض تفاصيل القرار' : 'View decision details',
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
                    label: Text(arabic ? 'سأنفذها' : 'I’ll do it'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('dashboard-decision-done'),
                    onPressed: onDone,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(arabic ? 'تم' : 'Done'),
                  ),
                  TextButton.icon(
                    key: const Key('dashboard-decision-not-suitable'),
                    onPressed: onNotSuitable,
                    icon: const Icon(Icons.block_rounded),
                    label: Text(arabic ? 'غير مناسبة' : 'Not suitable'),
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
                label: Text(arabic ? 'نفّذ الخطوة الآن' : 'Take action now'),
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
                      style: textStyle?.copyWith(fontWeight: FontWeight.w800),
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
            arabic ? 'لماذا يعتقد BIL ذلك؟' : 'Why BIL believes this',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          explanationRow(
            key: const Key('dashboard-truth-reason'),
            icon: Icons.psychology_alt_outlined,
            label: arabic ? 'التفسير' : 'Interpretation',
            value: reason,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          explanationRow(
            key: const Key('dashboard-truth-evidence'),
            icon: Icons.fact_check_outlined,
            label: arabic ? 'الدليل المستخدم' : 'Evidence used',
            value: evidence,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          explanationRow(
            key: const Key('dashboard-truth-confidence'),
            icon: Icons.verified_outlined,
            label: arabic ? 'الثقة' : 'Confidence',
            value: confidence,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          explanationRow(
            key: const Key('dashboard-truth-missing-evidence'),
            icon: Icons.manage_search_rounded,
            label: arabic ? 'فجوة الدليل' : 'Evidence gap',
            value: missingEvidence,
          ),
          if (abstentionReason != null &&
              abstentionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            explanationRow(
              key: const Key('dashboard-truth-abstention'),
              icon: Icons.pause_circle_outline_rounded,
              label: arabic ? 'سبب الامتناع' : 'Why BIL is holding back',
              value: abstentionReason!,
            ),
          ],
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
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              interpretation,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Text(
            evidence,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (!matchPersonalAiSurface) {
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
                color: const Color(0xFF174E8C).withValues(alpha: .08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: content,
        ),
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
              color: const Color(0xFF174E8C).withValues(alpha: .08),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
