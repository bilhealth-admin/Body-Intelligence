import 'package:body_intelligence_log/features/intelligence_center/services/coach_request_intent.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const physical43WeightConceptQuestion =
    'What is the difference between target weight and measured weight? '
    'Explain concepts only. Do not show my history or save anything.';

const coordinatedWeightConceptQuestions = [
  'Explain target weight versus measured weight. '
      'Do not show, review or compare my history.',
  'Explain target weight versus measured weight '
      'without reading, reviewing or using my history.',
  'اشرح الفرق بين الوزن المستهدف والوزن المقاس. '
      'لا تعرض، تراجع أو تقارن سجل وزني.',
];

void main() {
  for (final question in const [
    physical43WeightConceptQuestion,
    ...coordinatedWeightConceptQuestions,
    'Explain target weight versus measured weight. '
        "Don't review my recorded weight history or save anything.",
    'Do not show my history; explain target weight versus measured weight.',
    'Explain target weight versus measured weight without using my history.',
    'اشرح الفرق بين الوزن المستهدف والوزن المقاس. '
        'لا تعرض سجل وزني ولا تحفظ أي شيء.',
    'ما الفرق بين الوزن المستهدف والوزن المقاس؟ '
        'اشرح المفاهيم فقط ولا تستعرض سجل وزني أو تحفظ أي شيء.',
    'لا تعرض سجل وزني؛ اشرح الفرق بين الوزن المستهدف والوزن المقاس.',
    'اشرح الفرق بين الوزن المستهدف والوزن المقاس دون عرض سجل وزني.',
    'Explain target weight versus measured weight. '
        'The phrase “show my weight history” is only an example.',
    'I previously said "show my weight history". '
        'Now explain target weight versus measured weight.',
    'اشرح الفرق بين الوزن المستهدف والوزن المقاس. '
        'عبارة «اعرض سجل وزني» مثال فقط.',
    'قلت سابقا «اعرض سجل وزني». '
        'الآن اشرح الفرق بين الوزن المستهدف والوزن المقاس.',
    'Explain “target weight” versus “measured weight”. '
        'Don’t show my weight history.',
    'اشرح الفرق بين «الوزن المستهدف» و«الوزن المقاس» ولا تعرض سجل وزني.',
    'What is the difference between target weight and measured weight? '
        'Do not explain my recorded weight trend. Explain concepts only.',
    "Explain the phrase 'show my weight history'; concepts only.",
    'ما الفرق بين الوزن المستهدف والوزن المقاس؟ '
        'لا تشرح اتجاه وزني المسجل. اشرح المفاهيم فقط.',
    'Explain target weight versus measured weight. '
        'Do not show, review, or compare my recorded weight history.',
    'Explain target weight versus measured weight. '
        'Do not explain, review or compare my recorded weight trend.',
    'اشرح الفرق بين الوزن المستهدف والوزن المقاس '
        'دون عرض، مراجعة أو مقارنة سجل وزني.',
  ]) {
    test(
      'concepts do not read negated or quoted personal history: $question',
      () {
        expect(isCoachWeightConceptQuestion(question), isTrue);
        expect(isCoachWeightHistoryReadRequest(question), isFalse);
        expect(
          classifyCoachRequest(question).kind,
          CoachRequestKind.information,
        );
        expect(
          const LocalCoachCommandParser().parse(question, locale: 'en'),
          isEmpty,
        );
        expect(coachAllowsSuggestedPlanAction(question), isFalse);
      },
    );
  }

  for (final question in const [
    'Do not change my target weight; review my recorded weight history.',
    'Do not show my history as a chart, but compare my recorded weight last month.',
    'Explain target weight versus measured weight, then show my weight history.',
    'Explain the phrase "do not show my history", then show my recorded weights.',
    'اعرض سجل وزني آخر شهر ولا تحفظ أي شيء.',
    'لا تغير الوزن المستهدف؛ راجع سجل وزني آخر شهر.',
    'لا تعرض سجل وزني كرسم لكن قارن قياسات وزني خلال آخر شهر.',
    'اشرح الفرق بين الوزن المستهدف والوزن المقاس ثم اعرض سجل وزني.',
    'اشرح عبارة «لا تعرض سجل وزني» ثم اعرض سجل وزني آخر شهر.',
    'Show "my weight history" last month.',
    'Review my recorded “weight” measurements.',
    'اعرض «سجل وزني» آخر شهر.',
    'Do not show, review or compare my history, '
        'but show my recorded weights last month.',
    'Without reading, reviewing or using my history, '
        'however compare my saved weight measurements last month.',
    'Do not show, review or compare my history, '
        'then show my recorded weight history last month.',
    'لا تعرض، تراجع أو تقارن سجل وزني، لكن اعرض سجل وزني آخر شهر.',
    'دون عرض، مراجعة أو مقارنة سجل وزني، ثم اعرض سجل وزني آخر شهر.',
    'لا تعرض، تراجع أو تقارن سجل وزني،ولكن اعرض سجل وزني آخر شهر.',
  ]) {
    test('a distinct positive history request is retained: $question', () {
      expect(isCoachWeightConceptQuestion(question), isFalse);
      expect(isCoachWeightHistoryReadRequest(question), isTrue);
      expect(classifyCoachRequest(question).kind, CoachRequestKind.savedData);
    });
  }

  test(
    'a write veto still permits the requested read without admitting an action',
    () {
      const question =
          'Show my weight history last month. Do not save anything.';
      expect(isCoachWeightConceptQuestion(question), isFalse);
      expect(isCoachWeightHistoryReadRequest(question), isTrue);
      expect(classifyCoachRequest(question).kind, CoachRequestKind.information);
      expect(
        const LocalCoachCommandParser().parse(question, locale: 'en'),
        isEmpty,
      );
    },
  );

  for (final question in const [
    'Do not show my weight history.',
    'Do not review my recorded weight measurements.',
    'لا تعرض سجل وزني.',
    'لا تستعرض سجل وزني.',
    'Do not show, review or compare my weight history.',
    'Without reading, reviewing or using my recorded weight history.',
    'لا تعرض، تراجع أو تقارن سجل وزني.',
  ]) {
    test(
      'a negated read alone is not a personal history request: $question',
      () {
        expect(isCoachWeightHistoryReadRequest(question), isFalse);
      },
    );
  }
}
