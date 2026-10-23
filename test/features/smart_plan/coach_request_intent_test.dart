import 'package:body_intelligence_log/features/intelligence_center/services/coach_request_intent.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_coach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = <String, CoachRequestKind>{
    'My goal is 60 kg.': CoachRequestKind.updateFutureGoal,
    'Log my weight as 60 kg.': CoachRequestKind.recordObservation,
    'Please, I need a plan.': CoachRequestKind.unspecifiedPlan,
    'بدي خطة غذاء وتمارين لشهر.': CoachRequestKind.combinedPlan,
    'شو تمريني اليوم؟': CoachRequestKind.todayPlan,
    'ما قدرت أتمرن مبارح.': CoachRequestKind.reviewProgress,
    'غيّر تمرين الخميس لأني مسافر.': CoachRequestKind.revisePlan,
    'اعمل لي خطة 3 أشهر.': CoachRequestKind.unspecifiedPlan,
    'خلصت التمرين': CoachRequestKind.completeWorkout,
    'ما خلصت التمرين': CoachRequestKind.reviewProgress,
    'I did not finish my workout': CoachRequestKind.reviewProgress,
    'هدفي ٦٠ كيلو': CoachRequestKind.updateFutureGoal,
    'سجّل وزني ٦٠ كيلو': CoachRequestKind.recordObservation,
    'أكلت وجباتي اليوم': CoachRequestKind.recordObservation,
    'اعرض خطتي': CoachRequestKind.savedData,
    'ابغى خطة تمارين ستة اشهر': CoachRequestKind.trainingPlan,
    'عايز خطة غذاء أسبوع': CoachRequestKind.nutritionPlan,
    'What are calories?': CoachRequestKind.information,
    'Have I finished my workout?': CoachRequestKind.savedData,
    'هل خلصت التمرين؟': CoachRequestKind.savedData,
    'خلصت التمرين؟': CoachRequestKind.savedData,
  };
  for (final item in cases.entries) {
    test(
      item.key,
      () => expect(classifyCoachRequest(item.key).kind, item.value),
    );
  }
  test('durations and focus are preserved as supported tool arguments', () {
    expect(classifyCoachRequest('بدي خطة غذاء وتمارين لشهر').horizon, 'month');
    expect(classifyCoachRequest('اعمل لي خطة ٣ أشهر').horizon, 'threeMonths');
    expect(
      classifyCoachRequest('ابغى خطة تمارين ستة اشهر').horizon,
      'sixMonths',
    );
    expect(
      classifyCoachRequest('I need a week nutrition plan').horizon,
      'week',
    );
    expect(classifyCoachRequest('Please I need a plan').planFocus, isNull);
  });
  test('short plan slots inherit only a real adjacent user plan request', () {
    final request = classifyCoachPlanFollowUp('٣ أشهر', 'بدي خطة غذاء وتمارين');
    expect(request.kind, CoachRequestKind.combinedPlan);
    expect(request.horizon, 'threeMonths');
    expect(
      classifyCoachPlanFollowUp('nutrition only', 'I need a 6 month plan').kind,
      CoachRequestKind.nutritionPlan,
    );
    for (final text in ['60 kg', 'سجل وزني 60', 'done', 'تم', 'yes']) {
      expect(
        classifyCoachPlanFollowUp(text, 'I need a plan').createsPlan,
        isFalse,
        reason: text,
      );
    }
    expect(
      classifyCoachPlanFollowUp(
        '3 months',
        'How much water did I log?',
      ).createsPlan,
      isFalse,
    );
  });
  test(
    'sequential slot answers retain duration and focus, unrelated turns reset them',
    () {
      final request = classifyCoachPlanSequence([
        'Please I need a plan',
        '٣ أشهر',
        'تمارين فقط',
      ]);
      expect(request.kind, CoachRequestKind.trainingPlan);
      expect(request.horizon, 'threeMonths');
      expect(
        classifyCoachPlanSequence([
          'I need a plan',
          'How much water did I log?',
          'three months',
        ]).createsPlan,
        isFalse,
      );
    },
  );
  test(
    'travel Thursday selects next actual uncompleted Thursday, without editing it',
    () {
      final hint = BilSmartPlanRevisionHint.fromUserText(
        'غيّر تمرين الخميس لأني مسافر',
      );
      expect(hint.weekday, DateTime.thursday);
      expect(hint.reason.name, 'travel');
      expect(
        BilSmartPlanRevisionHint.fromUserText(
          'change Monday and Thursday',
        ).weekday,
        isNull,
      );
    },
  );
  test(
    'missed, negated and future targets cannot become completion receipts',
    () {
      for (final text in [
        'ما خلصت التمرين',
        'لم اكمل تمريني',
        'I did not complete my workout',
        'My goal is 60 kg',
      ]) {
        expect(smartPlanIntent(text), BilSmartPlanIntent.none, reason: text);
      }
      expect(
        smartPlanIntent('خلصت التمرين'),
        BilSmartPlanIntent.completedWorkout,
      );
      expect(
        smartPlanIntent('غيّر تمرين الخميس لأني مسافر'),
        BilSmartPlanIntent.revise,
      );
      expect(
        smartPlanIntent('Have I finished my workout?'),
        BilSmartPlanIntent.none,
      );
      expect(smartPlanIntent('خلصت التمرين؟'), BilSmartPlanIntent.none);
    },
  );
}
