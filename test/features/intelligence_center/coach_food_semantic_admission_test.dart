import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/food_flow/coach_food_turn_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_request_intent.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_coach.dart';
import 'package:flutter_test/flutter_test.dart';

const factualMarkdownRequest =
    'Explain fact versus opinion using a short Markdown heading, two bullets, '
    'bold text, and a two-row table. Add a brief Arabic translation. '
    'Do not use personal data.';

void main() {
  const parser = CoachFoodTurnParser();
  final day = DateTime(2026, 11, 6, 13);

  for (final input in const [
    factualMarkdownRequest,
    'Add a brief Arabic translation.',
    'Translate the words add, log, and record into Arabic.',
    'Add a translation of the words add, log, and record.',
    'Explain how to log rice and add an Arabic translation.',
    'Record a short definition of a fact versus an opinion.',
    'Add two bullet points explaining the difference.',
    'Explain what actually means. Add a translation.',
    'اشرح الفرق بين الحقيقة والرأي. أضف ترجمة إنجليزية قصيرة.',
    'أضف ترجمة عربية مختصرة.',
    'ترجم عبارة سجل الطعام إلى الإنجليزية.',
    'وضح معنى كلمة سجل وضيف ترجمة صغيرة.',
    'What is the difference between a fact and an opinion?',
    'Add a workout scheduled for tomorrow',
    'ضيف تمرين لبكرة',
  ]) {
    test('answer purpose does not declare a food: $input', () {
      expect(
        parser.parse(input, referenceLocal: day).kind,
        CoachFoodTurnKind.none,
      );
      expect(
        const LocalCoachCommandParser().parse(input, locale: 'en'),
        isEmpty,
      );
      expect(smartPlanIntent(input), BilSmartPlanIntent.none);
    });
  }

  for (final input in const [
    'I ate 100g rice',
    'I had 100g rice',
    'Log 100g rice',
    'Add 100g rice',
    'Record 100g rice',
    'Please log 100g rice',
    'Could you add 100g rice',
    'أكلت ١٠٠غ rice',
    'تناولت ١٠٠ غرام rice',
    'سجل ١٠٠غ rice',
    'سجلي ١٠٠غ rice',
    'سجللي ١٠٠غ rice',
    'أضف ١٠٠غ rice',
    'ضيف ١٠٠غ rice',
  ]) {
    test('affirmative food declaration owns its quantity: $input', () {
      final result = parser.parse(input, referenceLocal: day);
      expect(result.kind, CoachFoodTurnKind.log);
      expect(result.items, hasLength(1));
      expect(result.items.single.concept, 'rice');
      expect(result.items.single.amount, 100);
      expect(result.items.single.unit, 'g');
    });
  }

  test('unknown declared foods retain amount clarification', () {
    for (final input in const [
      'I ate homemade nebula stew',
      'Add homemade nebula stew',
      'اكلت يخنة بيتية جديدة',
      'ضيف يخنة بيتية جديدة',
    ]) {
      final result = parser.parse(input, referenceLocal: day);
      expect(result.kind, CoachFoodTurnKind.log, reason: input);
      expect(result.items.single.amount, isNull, reason: input);
      expect(result.items.single.concept, isNotEmpty, reason: input);
    }
  });

  test('branded food punctuation remains part of the declared identity', () {
    for (final entry in const {
      'Log 100g Dr. Oetker pudding': 'dr oetker pudding',
      'Add 100g Mr. Goodbar': 'mr goodbar',
      'Log 100g P.F. Chang pudding': 'p f chang pudding',
    }.entries) {
      final result = parser.parse(entry.key, referenceLocal: day);
      expect(result.kind, CoachFoodTurnKind.log, reason: entry.key);
      expect(result.items.single.concept, entry.value, reason: entry.key);
      expect(result.items.single.amount, 100, reason: entry.key);
    }
  });

  test('decimal portion punctuation cannot split a food command', () {
    for (final input in const [
      'Log 100.5g rice',
      'Add 100,5g rice',
      'اكلت ١٠٠٫٥غ rice',
    ]) {
      final result = parser.parse(input, referenceLocal: day);
      expect(result.kind, CoachFoodTurnKind.log, reason: input);
      expect(result.items.single.concept, 'rice', reason: input);
      expect(result.items.single.amount, 100.5, reason: input);
      expect(result.items.single.unit, 'g', reason: input);
    }
  });

  test('mixed food directives keep answer modifiers out of food identity', () {
    for (final input in const [
      'Log 100g rice and explain the nutrition in a table.',
      'Log 100g rice and give a short summary.',
      'Explain nutrition. Add 100g rice. Add a brief Arabic translation.',
      'Log 100g rice in a Markdown table.',
      'اكلت ١٠٠غ rice واشرح التغذية في جدول.',
      'اكلت ١٠٠غ rice وضيف ترجمة قصيرة.',
      'أضف ١٠٠غ rice في جدول.',
    ]) {
      final result = parser.parse(input, referenceLocal: day);
      expect(result.kind, CoachFoodTurnKind.log, reason: input);
      expect(result.items, hasLength(1), reason: input);
      expect(result.items.single.concept, 'rice', reason: input);
      expect(result.items.single.amount, 100, reason: input);
    }
    final multiple = parser.parse(
      'Log 100g rice, 200g chicken; add 50g beans.',
      referenceLocal: day,
    );
    expect(multiple.items.map((item) => item.concept), [
      'rice',
      'chicken',
      'beans',
    ]);
    expect(multiple.items.map((item) => item.amount), [100, 200, 50]);
  });

  test('food admission respects global restrictions and clause negation', () {
    for (final input in const [
      'Only answer: I ate 100g rice. Add an Arabic translation.',
      'Do not log anything. I ate 100g rice.',
      'لا تسجل اي شيء. اكلت ١٠٠غ rice.',
      'Do not log 100g rice; explain its nutrition.',
      'لا تسجل ١٠٠غ rice؛ اشرح التغذية.',
    ]) {
      expect(
        parser.parse(input, referenceLocal: day).kind,
        CoachFoodTurnKind.none,
        reason: input,
      );
    }
  });

  test(
    'correction, date and yesterday commands keep their owned semantics',
    () {
      for (final input in const [
        'Actually, 80g',
        'I meant, 80g',
        'Correction, 80g',
        'Actually:\n80g',
        'قصدي، ٨٠غ',
        'لا، قصدي ٨٠غ',
        'قصدي:\n٨٠غ',
      ]) {
        final correction = parser.parse(input, referenceLocal: day);
        expect(correction.kind, CoachFoodTurnKind.correction, reason: input);
        expect(correction.items.single.amount, 80, reason: input);
        expect(correction.items.single.unit, 'g', reason: input);
      }
      expect(
        parser.parse('Actually 80g', referenceLocal: day).kind,
        CoachFoodTurnKind.correction,
      );
      expect(
        parser.parse('نصها', referenceLocal: day).correctionKind,
        CoachFoodCorrectionKind.half,
      );
      expect(
        parser.parse('same as yesterday', referenceLocal: day).kind,
        CoachFoodTurnKind.likeYesterday,
      );
      final dated = parser.parse(
        'Log 100g rice on 2026-11-05',
        referenceLocal: day,
      );
      expect(dated.kind, CoachFoodTurnKind.log);
      expect(dated.date, DateTime(2026, 11, 5));
      expect(dated.invalidExplicitDate, isFalse);
    },
  );

  test('a scheduled workout never asserts a completion', () {
    for (final input in const [
      'My workout is scheduled for tomorrow.',
      'I plan to complete my workout tomorrow.',
      'Tomorrow I will have completed my workout.',
      'تمريني مقرر لبكرة',
      'بكرة راح اكون خلصت التمرين',
      'لم يكتمل التمرين بعد',
      'My workout is not completed yet.',
      'When my workout is completed tomorrow, remind me to stretch.',
      'If my workout is completed, show a recovery plan.',
    ]) {
      expect(
        classifyCoachRequest(input).kind,
        isNot(CoachRequestKind.completeWorkout),
        reason: input,
      );
      expect(
        smartPlanIntent(input),
        isNot(BilSmartPlanIntent.completedWorkout),
        reason: input,
      );
      expect(
        parser.parse(input, referenceLocal: day).kind,
        CoachFoodTurnKind.none,
        reason: input,
      );
    }
    expect(
      smartPlanIntent('I completed my workout'),
      BilSmartPlanIntent.completedWorkout,
    );
    for (final input in const [
      'I completed my workout and will complete another tomorrow.',
      'خلصت التمرين وراح اكمل تمرين ثاني بكرة',
    ]) {
      expect(
        classifyCoachRequest(input).kind,
        CoachRequestKind.completeWorkout,
        reason: input,
      );
      expect(
        smartPlanIntent(input),
        BilSmartPlanIntent.completedWorkout,
        reason: input,
      );
    }
    expect(
      smartPlanIntent(
        'Create a training plan to complete my workouts next week',
      ),
      BilSmartPlanIntent.open,
    );
    expect(
      smartPlanIntent('خلصت التمرين'),
      BilSmartPlanIntent.completedWorkout,
    );
  });

  test('future targets cannot become observed body weights', () {
    const commands = LocalCoachCommandParser();
    for (final input in const [
      'My goal is 60 kg',
      'I want to weigh 60 kg',
      'هدفي ٦٠ كيلو',
      'بدي اوصل ٦٠ كيلو',
      'Update my goal to 60 kg',
      'غير الهدف الى ٦٠ كيلو',
    ]) {
      expect(
        commands.parse(input, locale: 'en').map((action) => action.type),
        isNot(contains(IntelligenceActionType.addWeight)),
        reason: input,
      );
      expect(
        parser.parse(input, referenceLocal: day).kind,
        CoachFoodTurnKind.none,
        reason: input,
      );
    }
    for (final input in const ['Log my weight 62 kg', 'سجل وزني ٦٢ كيلو']) {
      final action = commands.parse(input, locale: 'en').single;
      expect(action.type, IntelligenceActionType.addWeight);
      expect(action.payload['weightKg'], 62);
      expect(action.requiresConfirmation, isTrue);
    }
  });
}
