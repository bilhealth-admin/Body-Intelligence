import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../features/ai_platform/domain/personal_health_ai.dart';
import '../../../shared/widgets/premium_surface.dart';
import 'dashboard_carousel.dart';

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
    String tr(String en, String ar) => arabic ? ar : en;
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
      label: tr('Personal Health AI', 'الذكاء الصحي الشخصي'),
      child: PremiumSurface(
        key: const Key('personal-health-ai-panel'),
        dashboardGlass: true,
        padding: compact
            ? const EdgeInsets.all(PremiumDesignTokens.spaceSm)
            : PremiumDesignTokens.cardPaddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Personal Health AI', 'الذكاء الصحي الشخصي'),
              style: compact
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    )
                  : Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            Text(
              tr(
                'What BIL knows now — and what it is still learning.',
                'ما يعرفه BIL الآن — وما زال يتعلمه.',
              ),
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: compact ? Theme.of(context).textTheme.bodySmall : null,
            ),
            SizedBox(
              height: compact
                  ? PremiumDesignTokens.spaceSm
                  : PremiumDesignTokens.spaceMd,
            ),
            DashboardCarousel(
              key: const Key('personal-health-ai-carousel'),
              height: MediaQuery.textScalerOf(context)
                  .scale(compact ? 280 : 218)
                  .clamp(compact ? 280.0 : 218.0, compact ? 300.0 : 280.0),
              viewportFraction: .88,
              compactControls: compact,
              semanticLabel: tr('Personal Health AI', 'الذكاء الصحي الشخصي'),
              pages: [
                for (final card in cards)
                  _AiCard(data: card, arabic: arabic, updatedAt: snapshot.asOf),
              ],
            ),
          ],
        ),
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
    String tr(String en, String ar) => arabic ? ar : en;
    final missing = data.missing.isEmpty ? null : data.missing.first;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
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
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(
          compact ? PremiumDesignTokens.spaceXs : PremiumDesignTokens.spaceSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: compact ? 3 : 5),
            Text(
              data.result,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: compact
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )
                  : Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: compact ? 3 : 6),
            Text(
              '${_state(data.state, tr)} · ${_confidence(data.confidence, tr)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            SizedBox(height: compact ? 3 : 5),
            Expanded(
              child: Text(
                data.explanation,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (missing != null) ...[
              SizedBox(height: compact ? 3 : 5),
              Text(
                tr('Learning: $missing', 'قيد التعلم: $missing'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            SizedBox(height: compact ? 3 : 6),
            Text(
              tr(
                'Updated ${TimeOfDay.fromDateTime(updatedAt).format(context)}',
                'آخر تحديث ${TimeOfDay.fromDateTime(updatedAt).format(context)}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
