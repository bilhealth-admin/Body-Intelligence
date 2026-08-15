import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../features/ai_platform/domain/personal_health_ai.dart';
import '../dashboard_five_locale_copy.dart';
import 'dashboard_twin_deck_shell.dart';

class PersonalHealthAiPanel extends StatelessWidget {
  const PersonalHealthAiPanel({
    required this.snapshot,
    required this.arabic,
    required this.todayHasMeals,
    required this.decisionCount,
    this.compact = false,
    super.key,
  });

  final PersonalHealthAiSnapshot snapshot;
  final bool arabic;
  final bool todayHasMeals;
  final int decisionCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);
    final trend = snapshot.currentPhase;
    final cards = <_AiCardData>[
      _AiCardData(
        title: tr('Weight Direction', 'اتجاه الوزن'),
        result: trend.kgPerDay == null
            ? tr('Waiting for a second weight', 'بانتظار قياس وزن ثانٍ')
            : trend.kgPerDay!.abs() < 0.015
            ? tr('Early stable direction', 'اتجاه مستقر مبدئيًا')
            : trend.kgPerDay! < 0
            ? tr('Early downward direction', 'اتجاه هابط مبدئيًا')
            : tr('Early upward direction', 'اتجاه صاعد مبدئيًا'),
        state: trend.state,
        confidence: trend.confidence,
        explanation: tr(
          'Robust timestamp-aware trend; new weights replace stale projections.',
          'اتجاه متين يراعي التوقيت؛ القياسات الجديدة تصحح التوقعات السابقة.',
        ),
        missing: _localizedMissing(trend.missingEvidence, arabic),
      ),
      _AiCardData(
        title: tr('Adaptive TDEE', 'الإنفاق التكيفي'),
        result: snapshot.tdee.kcal <= 0
            ? tr('Unavailable', 'غير متاح')
            : tr(
                '${snapshot.tdee.kcal.round()} kcal · ${snapshot.tdee.lowerKcal.round()}–${snapshot.tdee.upperKcal.round()}',
                '${snapshot.tdee.kcal.round()} سعرة · ${snapshot.tdee.lowerKcal.round()}–${snapshot.tdee.upperKcal.round()}',
              ),
        state: snapshot.tdee.state,
        confidence: snapshot.tdee.confidence,
        explanation: tr(
          'Formula prior calibrates only with a complete calorie ledger.',
          'تقدير أولي بالمعادلة لا يُعاير إلا بسجل سعرات مكتمل.',
        ),
        missing: _localizedMissing(snapshot.tdee.missingEvidence, arabic),
      ),
      _AiCardData(
        title: tr('Tissue vs Fluid Signal', 'إشارة النسيج مقابل السوائل'),
        result: snapshot.tissueFluid.probableTissueChangeKg == null
            ? tr('Possible fluid influence', 'تأثير سوائل محتمل')
            : tr(
                'Mixed, calorie-supported signal',
                'إشارة مختلطة مدعومة بالسعرات',
              ),
        state: snapshot.tissueFluid.probableTissueChangeKg == null
            ? HealthAiLearningState.learning
            : HealthAiLearningState.calibrating,
        confidence: snapshot.tissueFluid.confidence,
        explanation: tr(
          'Scale change is not treated as exact fat change.',
          'تغير الميزان لا يُعامل كتغير دهون دقيق.',
        ),
        missing: _localizedMissing(
          snapshot.tissueFluid.missingEvidence,
          arabic,
        ),
      ),
      _AiCardData(
        title: tr('Goal Forecast', 'توقع الهدف'),
        result: snapshot.goalForecastState == HealthAiLearningState.unavailable
            ? tr('Waiting for direction', 'بانتظار اتجاه')
            : tr('Range is still learning', 'النطاق ما زال قيد التعلم'),
        state: snapshot.goalForecastState,
        confidence: trend.confidence,
        explanation: tr(
          'Both current phase and full journey remain represented.',
          'تظل المرحلة الحالية والرحلة الكاملة ممثلتين.',
        ),
        missing: _localizedMissing(trend.missingEvidence, arabic),
      ),
      _AiCardData(
        title: tr('Plateau Risk', 'خطر الثبات'),
        result: trend.observationCount < 5
            ? tr(
                'Too early for a reliable plateau assessment',
                'مبكر جدًا لتقييم ثبات موثوق',
              )
            : tr('Monitoring robust direction', 'مراقبة الاتجاه المتين'),
        state: snapshot.plateauState,
        confidence: trend.observationCount < 5 ? 0 : trend.confidence,
        explanation: tr(
          'One or two flat/noisy readings cannot trigger an alert.',
          'قياس أو قياسان مسطحان أو مشوشان لا يطلقان تنبيهًا.',
        ),
        missing: trend.observationCount < 5
            ? [tr('more weight observations', 'قياسات وزن إضافية')]
            : const [],
      ),
      _AiCardData(
        title: tr('Journey Progress', 'تقدم الرحلة'),
        result: tr(
          '${snapshot.fullJourney.observationCount} recorded weights · ${trend.observationCount} current phase',
          '${snapshot.fullJourney.observationCount} قياسات مسجلة · ${trend.observationCount} في المرحلة الحالية',
        ),
        state: snapshot.fullJourney.state,
        confidence: snapshot.fullJourney.confidence,
        explanation: tr(
          'Long-term and short-term directions are kept separate.',
          'يُفصل الاتجاه طويل المدى عن قصير المدى.',
        ),
        missing: _localizedMissing(
          snapshot.fullJourney.missingEvidence,
          arabic,
        ),
      ),
      _AiCardData(
        title: tr('Today’s Ledger Status', 'حالة سجل اليوم'),
        result: todayHasMeals
            ? tr('Live totals available', 'الإجماليات الحية متاحة')
            : tr('Open · no meals yet', 'مفتوح · لا وجبات بعد'),
        state: HealthAiLearningState.learning,
        confidence: todayHasMeals ? 0.5 : 0,
        explanation: tr(
          'Only recorded local entries contribute.',
          'تساهم الإدخالات المحلية المسجلة فقط.',
        ),
        missing: todayHasMeals
            ? const []
            : [tr('today’s meal evidence', 'بيانات وجبات اليوم')],
      ),
      _AiCardData(
        title: tr('Decision Learning Status', 'حالة تعلم القرارات'),
        result: decisionCount == 0
            ? tr('No recorded outcomes yet', 'لا نتائج مسجلة بعد')
            : tr(
                '$decisionCount durable decisions',
                '$decisionCount قرارات محفوظة',
              ),
        state: decisionCount == 0
            ? HealthAiLearningState.initial
            : HealthAiLearningState.learning,
        confidence: decisionCount == 0 ? 0 : 0.5,
        explanation: tr(
          'BIL never assumes a recommendation was followed.',
          'لا يفترض BIL أن التوصية اتُبعت.',
        ),
        missing: decisionCount == 0
            ? [
                tr(
                  'an observable action and later outcome',
                  'إجراء قابل للملاحظة ونتيجة لاحقة',
                ),
              ]
            : const [],
      ),
    ];

    return Semantics(
      container: true,
      label: tr('Bio Intelligence', 'الذكاء الحيوي'),
      child: DashboardTwinDeckShell(
        key: const Key('personal-health-ai-panel'),
        title: tr('Bio Intelligence', 'الذكاء الحيوي'),
        subtitle: tr('What BIL knows now.', 'ما يعرفه BIL الآن.'),
        semanticLabel: tr('Bio Intelligence', 'الذكاء الحيوي'),
        compact: compact,
        pages: [
          _UnifiedAiCard(
            cards: cards,
            arabic: arabic,
            updatedAt: snapshot.asOf,
          ),
        ],
      ),
    );
  }

  List<String> _localizedMissing(List<String> values, bool arabic) {
    if (!arabic) return values;
    return values
        .map(
          (value) => switch (value) {
            'a second valid weight measurement' => 'قياس وزن صالح ثانٍ',
            'enough elapsed time between measurements' =>
              'فاصل زمني كافٍ بين القياسات',
            'more comparable measurements to narrow uncertainty' =>
              'قياسات إضافية قابلة للمقارنة لتقليل عدم اليقين',
            'complete calorie intake for at least half the interval' =>
              'سجل سعرات مكتمل لنصف الفترة على الأقل',
            'more complete calorie days' => 'أيام إضافية مكتملة السعرات',
            'profile and first weight' => 'الملف الشخصي وأول قياس وزن',
            'two valid weights' => 'قياسان صالحان للوزن',
            'calorie evidence' => 'بيانات السعرات',
            _ => 'بيانات إضافية قابلة للمقارنة',
          },
        )
        .toList();
  }
}

class _UnifiedAiCard extends StatefulWidget {
  const _UnifiedAiCard({
    required this.cards,
    required this.arabic,
    required this.updatedAt,
  });

  final List<_AiCardData> cards;
  final bool arabic;
  final DateTime updatedAt;

  @override
  State<_UnifiedAiCard> createState() => _UnifiedAiCardState();
}

class _UnifiedAiCardState extends State<_UnifiedAiCard> {
  var _signal = 0;
  var _detail = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final card = widget.cards[_signal.clamp(0, widget.cards.length - 1)];
    String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);
    final missing = card.missing.isEmpty ? null : card.missing.first;
    final details = [
      '${_state(card.state, tr)} · ${_confidence(card.confidence, tr)}',
      card.explanation,
      missing == null
          ? tr(
              'Updated ${TimeOfDay.fromDateTime(widget.updatedAt).format(context)}',
              'آخر تحديث ${TimeOfDay.fromDateTime(widget.updatedAt).format(context)}',
            )
          : tr('Learning: $missing', 'قيد التعلم: $missing'),
    ];
    final labels = [
      tr('Model', 'النموذج'),
      tr('Meaning', 'التفسير'),
      tr('Evidence', 'الدليل'),
    ];
    final icons = const [
      Icons.verified_outlined,
      Icons.lightbulb_outline_rounded,
      Icons.fact_check_outlined,
    ];

    return Padding(
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: PremiumDesignTokens.spaceXs,
                mainAxisSpacing: PremiumDesignTokens.spaceXs,
                mainAxisExtent: 38,
              ),
              itemCount: widget.cards.length,
              itemBuilder: (context, index) {
                final selected = index == _signal;
                return InkWell(
                  onTap: () => setState(() => _signal = index),
                  borderRadius: BorderRadius.circular(
                    PremiumDesignTokens.radiusMd,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: .14)
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: .42,
                            ),
                      borderRadius: BorderRadius.circular(
                        PremiumDesignTokens.radiusMd,
                      ),
                      border: Border.all(
                        color: selected
                            ? scheme.primary.withValues(alpha: .55)
                            : scheme.outlineVariant.withValues(alpha: .72),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.cards[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w700,
                        color: selected ? scheme.primary : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            card.result,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _detail = index),
                    borderRadius: BorderRadius.circular(99),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: index == _detail
                            ? scheme.primary.withValues(alpha: .15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: scheme.primary.withValues(
                            alpha: index == _detail ? .58 : .18,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icons[index], size: 15, color: scheme.primary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              labels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (index != 2) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .72),
              ),
            ),
            child: Text(
              details[_detail],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _state(
    HealthAiLearningState state,
    String Function(String, String) tr,
  ) => switch (state) {
    HealthAiLearningState.unavailable => tr('Unavailable', 'غير متاح'),
    HealthAiLearningState.initial => tr('Initial', 'أولي'),
    HealthAiLearningState.learning => tr('Learning', 'يتعلم'),
    HealthAiLearningState.calibrating => tr('Calibrating', 'يُعاير'),
    HealthAiLearningState.established => tr('Established', 'راسخ'),
    HealthAiLearningState.temporarilyUnreliable => tr(
      'Temporarily unreliable',
      'غير موثوق مؤقتًا',
    ),
  };

  String _confidence(double value, String Function(String, String) tr) =>
      value <= 0
      ? tr('No confidence yet', 'لا ثقة بعد')
      : value < .45
      ? tr('Low confidence', 'ثقة منخفضة')
      : value < .7
      ? tr('Emerging confidence', 'ثقة ناشئة')
      : tr('Useful confidence', 'ثقة مفيدة');
}

// Kept for non-unified layouts on larger surfaces.
// ignore: unused_element
class _AiCard extends StatelessWidget {
  const _AiCard({
    required this.data,
    required this.arabic,
    required this.updatedAt,
  });

  final _AiCardData data;
  final bool arabic;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);
    final missing = data.missing.isEmpty ? null : data.missing.first;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.all(
        compact ? PremiumDesignTokens.spaceXs : PremiumDesignTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.visible,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: compact ? 3 : 5),
          Text(
            data.result,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.visible,
            style: compact
                ? Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                : Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          _AiSignalRow(
            icon: Icons.verified_outlined,
            label: tr('Model state', 'حالة النموذج'),
            value:
                '${_state(data.state, tr)} · ${_confidence(data.confidence, tr)}',
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          _AiSignalRow(
            icon: Icons.lightbulb_outline_rounded,
            label: tr('Interpretation', 'التفسير'),
            value: data.explanation,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          _AiSignalRow(
            icon: Icons.update_rounded,
            label: tr('Evidence', 'الدليل'),
            value: missing == null
                ? tr(
                    'Updated ${TimeOfDay.fromDateTime(updatedAt).format(context)}',
                    'آخر تحديث ${TimeOfDay.fromDateTime(updatedAt).format(context)}',
                  )
                : tr('Learning: $missing', 'قيد التعلم: $missing'),
          ),
        ],
      ),
    );
  }

  String _state(
    HealthAiLearningState state,
    String Function(String, String) tr,
  ) => switch (state) {
    HealthAiLearningState.unavailable => tr('Unavailable', 'غير متاح'),
    HealthAiLearningState.initial => tr('Initial', 'أولي'),
    HealthAiLearningState.learning => tr('Learning', 'يتعلم'),
    HealthAiLearningState.calibrating => tr('Calibrating', 'يُعاير'),
    HealthAiLearningState.established => tr('Established', 'راسخ'),
    HealthAiLearningState.temporarilyUnreliable => tr(
      'Temporarily unreliable',
      'غير موثوق مؤقتًا',
    ),
  };

  String _confidence(double value, String Function(String, String) tr) =>
      value <= 0
      ? tr('No confidence yet', 'لا ثقة بعد')
      : value < 0.45
      ? tr('Low confidence', 'ثقة منخفضة')
      : value < 0.7
      ? tr('Emerging confidence', 'ثقة ناشئة')
      : tr('Useful confidence', 'ثقة مفيدة');
}

class _AiSignalRow extends StatelessWidget {
  const _AiSignalRow({
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
      padding: const EdgeInsets.symmetric(
        horizontal: PremiumDesignTokens.spaceSm,
        vertical: PremiumDesignTokens.spaceXs,
      ),
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
              maxLines: 2,
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

final class _AiCardData {
  const _AiCardData({
    required this.title,
    required this.result,
    required this.state,
    required this.confidence,
    required this.explanation,
    required this.missing,
  });

  final String title;
  final String result;
  final HealthAiLearningState state;
  final double confidence;
  final String explanation;
  final List<String> missing;
}
