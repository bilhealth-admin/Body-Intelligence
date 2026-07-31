import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../domain/dashboard_decision_explanation.dart';

class DashboardDecisionExplanationPage extends StatelessWidget {
  const DashboardDecisionExplanationPage({
    super.key,
    required this.explanation,
  });

  final DashboardDecisionExplanation? explanation;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => arabic ? ar : en;
    final value = explanation;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Why this decision?', 'لماذا هذا القرار؟')),
      ),
      body: value == null
          ? Center(
              key: const Key('decision-explanation-unavailable'),
              child: Padding(
                padding: const EdgeInsets.all(PremiumDesignTokens.spaceLg),
                child: Text(
                  tr(
                    'This explanation is no longer available. Return to Today for the current decision.',
                    'لم يعد هذا التفسير متاحًا. ارجع إلى اليوم لعرض القرار الحالي.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SafeArea(
              child: ListView(
                key: const Key('dashboard-decision-explanation-page'),
                padding: const EdgeInsets.all(PremiumDesignTokens.spaceLg),
                children: [
                  Text(
                    value.title,
                    key: const Key('decision-explanation-title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceMd),
                  _ExplanationSection(
                    key: const Key('decision-explanation-reason'),
                    icon: Icons.psychology_alt_outlined,
                    title: tr('Interpretation', 'التفسير'),
                    children: [value.reason],
                  ),
                  _ExplanationSection(
                    key: const Key('decision-explanation-evidence'),
                    icon: Icons.fact_check_outlined,
                    title: tr('Evidence used', 'الأدلة المستخدمة'),
                    children: value.evidence,
                  ),
                  _ExplanationSection(
                    key: const Key('decision-explanation-confidence'),
                    icon: Icons.verified_outlined,
                    title: tr('Confidence', 'الثقة'),
                    children: [value.confidence],
                  ),
                  _ExplanationSection(
                    key: const Key('decision-explanation-unknowns'),
                    icon: Icons.manage_search_rounded,
                    title: tr('What BIL does not know', 'ما لا يعرفه BIL'),
                    children: value.hasEvidenceGap
                        ? value.missingEvidence
                        : [
                            tr(
                              'No material evidence gap.',
                              'لا توجد فجوة أدلة مؤثرة.',
                            ),
                          ],
                  ),
                  _ExplanationSection(
                    key: const Key('decision-explanation-provenance'),
                    icon: Icons.account_tree_outlined,
                    title: tr('Decision provenance', 'مصدر القرار'),
                    children: [
                      '${tr('Engine version', 'إصدار المحرك')}: ${value.engineVersion}',
                      '${tr('Action type', 'نوع القرار')}: ${value.actionType}',
                      '${tr('Local input sources', 'مصادر المدخلات المحلية')}: ${value.inputSources.join(' · ')}',
                    ],
                  ),
                  Text(
                    tr(
                      'BIL explains local deterministic evidence. It does not diagnose disease or claim medical certainty.',
                      'يشرح BIL الأدلة المحلية الحتمية، ولا يشخّص الأمراض أو يدّعي يقينًا طبيًا.',
                    ),
                    key: const Key('decision-explanation-safety-note'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: PremiumDesignTokens.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: PremiumDesignTokens.spaceSm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            for (final item in children)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: PremiumDesignTokens.spaceXs,
                ),
                child: Text('• $item'),
              ),
          ],
        ),
      ),
    );
  }
}
