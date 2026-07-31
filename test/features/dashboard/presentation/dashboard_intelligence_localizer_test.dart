import 'package:body_intelligence_log/engine/body_composition_engine.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/engine/what_changed_engine.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_intelligence_localizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const english = DashboardIntelligenceLocalizer(arabic: false);
  const arabic = DashboardIntelligenceLocalizer(arabic: true);

  test('preserves available and unavailable composition presentation', () {
    expect(
      english.compositionValue(
        const BodyCompositionMetric.available(24.34),
        unit: '%',
      ),
      '24.3%',
    );
    expect(
      arabic.compositionValue(
        const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.missingWaist,
        ),
        unit: '%',
      ),
      'محيط الخصر غير مسجل',
    );
    expect(english.compositionIssue(null), 'Unavailable');
    expect(arabic.compositionIssue(null), 'غير متاح');
  });

  test('preserves every best-action title and reason mapping', () {
    const expectedTitles = {
      BestActionType.weighIn: 'سجّل وزن اليوم',
      BestActionType.completeLogging: 'أكمل تسجيل وجبة واحدة',
      BestActionType.protein: 'أضف مصدر بروتين مناسبًا اليوم',
      BestActionType.hydration: 'اشرب الماء تدريجيًا',
      BestActionType.holdPlan: 'حافظ على الخطة دون تغيير اليوم',
      BestActionType.none: 'لا حاجة لتغيير الخطة',
    };
    for (final type in BestActionType.values) {
      final action = BestAction(
        type: type,
        title: 'English title $type',
        reason: 'English reason $type',
        evidence: const [],
      );
      expect(english.bestActionTitle(action), action.title);
      expect(english.bestActionReason(action), action.reason);
      expect(arabic.bestActionTitle(action), expectedTitles[type]);
      expect(arabic.bestActionReason(action), isNotEmpty);
    }
  });

  test('preserves change summaries in both languages', () {
    for (final interpretation in ChangeInterpretation.values) {
      final report = WhatChangedReport(
        interpretation: interpretation,
        summary: 'English summary $interpretation',
        evidence: const [],
        alternatives: const [],
      );
      expect(english.changedSummary(report), report.summary);
      expect(arabic.changedSummary(report), isNot(report.summary));
      expect(arabic.changedSummary(report), isNotEmpty);
    }
  });

  test('preserves known and fallback insight titles', () {
    expect(
      arabic.insightTitle('Protein below target'),
      'البروتين أقل من الهدف',
    );
    expect(arabic.insightTitle('Build your baseline'), 'ابنِ خطك الأساسي');
    expect(
      arabic.insightTitle('Unknown insight'),
      'الأهداف اليومية متقاربة بصورة عامة',
    );
    expect(english.insightTitle('Unknown insight'), 'Unknown insight');
  });
}
