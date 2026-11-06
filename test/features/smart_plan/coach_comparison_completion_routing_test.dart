import 'package:body_intelligence_log/features/intelligence_center/services/coach_request_intent.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_coach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comparison without a global veto never becomes workout completion', () {
    const input = 'Compare a planned workout with a completed workout.';
    expect(classifyCoachRequest(input).kind, CoachRequestKind.information);
    expect(smartPlanIntent(input), BilSmartPlanIntent.none);
  });

  for (final input in const [
    'Compare planned vs completed workouts in two rows and three columns.',
    'Explain the difference between a planned workout and a completed workout.',
    'What does completed workout mean? Explain without logging it.',
    'Show a two-row table of planned and completed workouts.',
    'Explain a completed workout in a table.',
    'Reply in English. Show a two-row Markdown table comparing a planned '
        'workout with a completed workout. Do not save or change any data.',
    'قارن عبارة «خلصت التمرين» بتمرين مخطط.',
    'اشرح معنى عبارة «أكملت تمرين اليوم» بجدول.',
    'ما معنى عبارة «انهيت تمرين»؟ اشرحها في جدول.',
  ]) {
    test('informational comparison reaches no Smart Plan action: $input', () {
      expect(classifyCoachRequest(input).kind, CoachRequestKind.information);
      expect(smartPlanIntent(input), BilSmartPlanIntent.none);
    });
  }

  for (final input in const [
    'Log my completed workout.',
    'Log my completed workout in a table.',
    'Record my completed workout as a table.',
    'I completed my workout. Show it in a table.',
    'I have finished my workout. Show a table.',
    'Finished my workout. Show a table.',
    'خلصت التمرين',
    'خلصت التمرين، اعرضه في جدول.',
    'أنا خلصت التمرين، اعرضه في جدول.',
    'سجل أني خلصت التمرين في جدول.',
  ]) {
    test('an actual completion keeps the existing review route: $input', () {
      expect(
        classifyCoachRequest(input).kind,
        CoachRequestKind.completeWorkout,
      );
      expect(smartPlanIntent(input), BilSmartPlanIntent.completedWorkout);
    });
  }

  for (final entry in const <String, CoachRequestKind>{
    'Create a training plan for a week as a table.':
        CoachRequestKind.trainingPlan,
    'Create a nutrition and training plan for a month as a table.':
        CoachRequestKind.combinedPlan,
    'أنشئ خطة تمارين لأسبوع في جدول.': CoachRequestKind.trainingPlan,
  }.entries) {
    test('a plan draft request keeps its review route: ${entry.key}', () {
      expect(classifyCoachRequest(entry.key).kind, entry.value);
      expect(smartPlanIntent(entry.key), BilSmartPlanIntent.open);
    });
  }

  test('temporal completion assertions keep the existing review route', () {
    for (final input in const [
      'Yesterday I completed my workout. Show it in a table.',
      'اليوم خلصت التمرين اعرضه في جدول',
      'Just completed my workout. Show a table.',
    ]) {
      expect(
        classifyCoachRequest(input).kind,
        CoachRequestKind.completeWorkout,
        reason: input,
      );
      expect(smartPlanIntent(input), BilSmartPlanIntent.completedWorkout);
    }
  });

  test(
    'recorded history questions keep their existing read-only semantics',
    () {
      for (final input in const [
        'Have I finished my workout?',
        'هل خلصت التمرين؟',
        'Show my weight history in a table.',
      ]) {
        expect(classifyCoachRequest(input).kind, CoachRequestKind.savedData);
        expect(smartPlanIntent(input), BilSmartPlanIntent.none);
      }
    },
  );
}
