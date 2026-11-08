import 'package:body_intelligence_log/features/intelligence_center/services/coach_request_intent.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const physical42WeightConceptQuestion =
    'Reply in Arabic: explain target weight versus measured weight in a short '
    'Markdown table. Do not change my data.';

void main() {
  for (final question in const [
    physical42WeightConceptQuestion,
    'Explain target weight versus measured weight.',
    'What is the difference between target weight and measured weight?',
    'اشرح الفرق بين الوزن المستهدف والوزن المقاس في جدول قصير دون تعديل بياناتي.',
  ]) {
    test('weight concept reaches an answer, not a history read: $question', () {
      expect(isCoachWeightConceptQuestion(question), isTrue);
      expect(isCoachWeightHistoryReadRequest(question), isFalse);
      expect(classifyCoachRequest(question).kind, CoachRequestKind.information);
      expect(
        const LocalCoachCommandParser().parse(question, locale: 'ar'),
        isEmpty,
      );
      expect(coachAllowsSuggestedPlanAction(question), isFalse);
    });
  }

  for (final question in const [
    'Show my recorded weight in a table.',
    'Show my weight history last month as a table.',
    'Compare my saved weight measurements last month in a table.',
    'Explain my recorded weight trend in a table.',
    'Explain my weight changes last month in a table.',
    'What does my weight chart mean?',
    'اشرح تطور وزني بجدول',
    'اشرح تغير وزني خلال آخر أسبوعين بجدول.',
    'اشرح اتجاه وزني من سجلي آخر شهر في جدول.',
    'أريد جدول نزولي بالوزن لشهر',
  ]) {
    test(
      'explanation or table preserves a real weight-history read: $question',
      () {
        expect(isCoachWeightConceptQuestion(question), isFalse);
        expect(isCoachWeightHistoryReadRequest(question), isTrue);
        expect(classifyCoachRequest(question).kind, CoachRequestKind.savedData);
      },
    );
  }

  test('explicit data veto covers my data without erasing a scoped action', () {
    expect(
      coachExplicitlyForbidsActions(physical42WeightConceptQuestion),
      isTrue,
    );
    expect(coachExplicitlyForbidsActions('دون تعديل بياناتي'), isTrue);
    expect(
      coachExplicitlyForbidsActions(
        'Do not log my weight; update my goal to 60 kg.',
      ),
      isFalse,
    );
  });

  test('a table does not reclassify explicit weight writes as history', () {
    for (final question in const [
      'Log my measured weight as 62 kg and explain in a table.',
      'سجل وزني 62 كغ واشرح النتيجة في جدول.',
      'Update my target weight to 60 kg and explain in a table.',
    ]) {
      expect(isCoachWeightHistoryReadRequest(question), isFalse);
      expect(isCoachWeightConceptQuestion(question), isFalse);
    }
    for (final request in const [
      'Log my weight as 62 kg',
      'Log my weight as 62',
      'Log my measured weight as 62 kg',
      'Record my current weight as 62 kg',
    ]) {
      final action = const LocalCoachCommandParser().parse(
        request,
        locale: 'en',
      );
      expect(action, hasLength(1), reason: request);
      expect(action.single.toolId, 'log_weight');
      expect(action.single.requiresConfirmation, isTrue);
      expect(action.single.payload['weightKg'], 62);
    }
    for (final request in const [
      'Log my measured weight as 60 kg 70 kg',
      'Log my measured weight as 60 g',
      'Log my measured weight as 60 kg and rice 200 g',
    ]) {
      expect(
        const LocalCoachCommandParser().parse(request, locale: 'en'),
        isEmpty,
        reason: request,
      );
    }
    expect(
      classifyCoachRequest('My goal is 60 kg.').kind,
      CoachRequestKind.updateFutureGoal,
    );
    expect(
      const LocalCoachCommandParser()
          .parse('My goal is 60 kg.', locale: 'en')
          .where((action) => action.toolId == 'log_weight'),
      isEmpty,
    );
  });
}
