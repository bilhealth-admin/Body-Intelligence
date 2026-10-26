import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/food_flow/coach_food_turn_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_cloud_privacy_boundary.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_language_resolver.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_request_intent.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const food = CoachFoodTurnParser();
  final localDay = DateTime(2026, 10, 25);

  test('all four actual English and Arabic starters bypass food logging', () {
    for (final request in <String>[
      'Review my day from my saved BIL data and tell me the most useful next step.',
      'Review today’s nutrition from my saved BIL data. What stands out and what should I focus on next?',
      'Explain my recorded sleep trend and what it may mean for today, without inventing missing data.',
      'Based on my selected BIL context, what is the single best thing to focus on next and why?',
      'راجع يومي من بيانات BIL المحفوظة وأخبرني بأكثر خطوة مفيدة الآن.',
      'راجع تغذية اليوم من بيانات BIL المحفوظة. ما الأبرز وما الذي أركز عليه الآن؟',
      'اشرح اتجاه نومي المسجل وما قد يعنيه لليوم، من دون اختراع بيانات مفقودة.',
      'بناءً على سياق BIL الذي اخترته، ما أفضل شيء واحد أركز عليه الآن ولماذا؟',
    ]) {
      expect(
        food.parse(request, referenceLocal: localDay).kind,
        CoachFoodTurnKind.none,
        reason: request,
      );
      expect(
        classifyCoachRequest(request).createsPlan,
        isFalse,
        reason: request,
      );
    }
  });

  for (final request in <String>[
    'اطلع على سجل أوزاني خلال الفترة الماضية',
    'حلّل وزني خلال آخر 30 يومًا من القياسات المسجلة',
    'أريد جدول نزولي بالوزن لشهر',
    'استعرض سجل أوزاني',
    'View my weight history',
    'سجل وزني 62 كيلو',
  ]) {
    test(
      'BIL39 weight lookup/check-in does not become a food portion: $request',
      () {
        final parsed = food.parse(request, referenceLocal: localDay);
        expect(parsed.kind, CoachFoodTurnKind.none, reason: request);
      },
    );
  }

  test('BIL39 explicit meal logging remains supported for review', () {
    final parsed = food.parse(
      'سجل 3 بيضات 150 غ فطور',
      referenceLocal: localDay,
    );
    expect(parsed.kind, CoachFoodTurnKind.log);
    expect(parsed.items, isNotEmpty);
  });

  test('BIL39 personal-weight chart and negation are never plan creation', () {
    const chart = 'أريد جدول نزولي بالوزن لشهر';
    expect(isCoachWeightHistoryReadRequest(chart), isTrue);
    expect(classifyCoachRequest(chart).kind, CoachRequestKind.savedData);
    expect(isCoachPlanNegated('لا أريد خطة'), isTrue);
    expect(classifyCoachRequest('لا أريد خطة').createsPlan, isFalse);
    expect(classifyCoachPlanFollowUp('شهر', chart).createsPlan, isFalse);
    expect(
      classifyCoachPlanSequence(const <String>[
        'اطلع على سجل أوزاني',
        'شهر',
      ]).createsPlan,
      isFalse,
    );
  });

  test('BIL39 weight follow-ups do not create plans', () {
    for (final (prior, reply) in <(String, String)>[
      ('اطلع على سجل أوزاني', 'شهر'),
      ('Review my weight history', 'last month'),
      ('حلل وزن القياسات المسجلة', 'اسبوعين'),
      ('Show my weight chart', 'two weeks'),
    ]) {
      final resolved = resolveCoachWeightHistoryFollowUp(
        reply,
        previousUserRequest: prior,
      );
      expect(isCoachWeightHistoryReadRequest(resolved), isTrue);
      expect(classifyCoachRequest(resolved).createsPlan, isFalse);
    }
    for (final prior in <String>[
      'أريد خطة تمارين شهرية',
      'سجل وجبتي',
      'Review my nutrition',
    ]) {
      expect(
        resolveCoachWeightHistoryFollowUp('شهر', previousUserRequest: prior),
        'شهر',
      );
    }
    expect(
      resolveCoachWeightHistoryFollowUp(
        'لا أريد خطة',
        previousUserRequest: 'اطلع على سجل أوزاني',
      ),
      'لا أريد خطة',
    );
    for (final (prior, reply) in <(String, String)>[
      ('اطلع على سجل أوزاني آخر شهر', 'اطلع'),
      ('قارن سجل وزني آخر أسبوعين', 'اعرض'),
      ('Show my weight history last month', 'show it'),
    ]) {
      final resumed = resolveCoachWeightHistoryFollowUp(
        reply,
        previousUserRequest: prior,
      );
      expect(resumed, prior, reason: reply);
      expect(classifyCoachRequest(resumed).kind, CoachRequestKind.savedData);
    }
    for (final prior in <String>[
      'سجل 3 بيضات',
      'Create a monthly workout plan',
      'Switch to English',
    ]) {
      expect(
        resolveCoachWeightHistoryFollowUp('اطلع', previousUserRequest: prior),
        'اطلع',
      );
    }
  });

  test('BIL39 review buttons never authorize unsolicited Smart Plan actions', () {
    for (final question in <String>[
      'Review my day from my saved BIL data and tell me the most useful next step.',
      'Review today’s nutrition from my saved BIL data.',
      'راجع تغذية اليوم من بياناتي المحفوظة',
      'Analyze today’s recorded workout.',
      'حلّل تمرين اليوم من السجل',
      'Explain my recorded sleep trend.',
      'Based on my selected BIL context, what should I focus on next?',
      'لا أريد خطة',
      'أريد جدول نزولي بالوزن لشهر',
    ]) {
      expect(
        coachAllowsSuggestedPlanAction(question),
        isFalse,
        reason: question,
      );
    }
    expect(
      coachAllowsSuggestedPlanAction('Create a one month workout plan'),
      isTrue,
    );
    for (final question in <String>[
      'What is my workout today?',
      'شو تمريني اليوم؟',
      'What meals are in my plan today?',
    ]) {
      expect(
        coachAllowsSuggestedPlanAction(question),
        isTrue,
        reason: question,
      );
    }
  });

  test(
    'BIL39 an explicit monthly training and nutrition plan is still valid',
    () {
      final intent = classifyCoachRequest(
        'أريد إنشاء خطة تمارين وتغذية لمدة شهر',
      );
      expect(intent.kind, CoachRequestKind.combinedPlan);
      expect(intent.horizon, 'month');
    },
  );

  test('BIL39 target is not a measured weigh-in', () {
    expect(
      classifyCoachRequest('هدفي 60 كيلو').kind,
      CoachRequestKind.updateFutureGoal,
    );
    expect(
      classifyCoachRequest('سجل وزني 62 كيلو').kind,
      CoachRequestKind.recordObservation,
    );
  });

  test('BIL39 chat language is independent of application settings', () {
    const resolver = CoachLanguageResolver();
    expect(
      resolver
          .resolve(
            input: 'can u talking en lang',
            uiLocale: 'ar',
            previousClearLanguageTag: 'ar',
          )
          .languageTag,
      'en',
    );
    expect(
      resolver.resolve(input: 'reply in English', uiLocale: 'ar').languageTag,
      'en',
    );
    const commands = LocalCoachCommandParser();
    expect(commands.parse('Reply in English language', locale: 'ar'), isEmpty);
    for (final request in <String>[
      'غير لغة التطبيق للانجليزي',
      'غيّر لغة التطبيق للإنجليزي',
      'Change app language to English',
    ]) {
      final appChange = commands.parse(request, locale: 'ar');
      expect(appChange, hasLength(1), reason: request);
      expect(appChange.single.type, IntelligenceActionType.setLanguage);
      expect(appChange.single.payload['locale'], 'en');
    }
  });

  test(
    'BIL39 weight context from Arabic plurals never leaks other categories',
    () {
      final snapshot = CoachContextSnapshot(
        generatedAt: DateTime.utc(2026, 10, 25),
        profile: const <String, Object?>{},
        weights: <CoachWeightPoint>[
          CoachWeightPoint(at: DateTime.utc(2026, 10, 1), kg: 90),
          CoachWeightPoint(at: DateTime.utc(2026, 10, 23), kg: 88),
        ],
        nutritionDays: const <CoachNutritionDay>[],
        waterHistory: const <Map<String, Object?>>[],
        computedHealth: const <String, Object?>{},
      );
      final scoped = projectCoachCloudContext(
        question: 'اطلع على سجل أوزاني خلال الفترة الماضية',
        context: snapshot,
      );
      expect(scoped.context, contains('weight'));
      expect(scoped.context, isNot(contains('nutritionHistory')));
      expect(scoped.context, isNot(contains('activityHistory')));
      final weight = scoped.context['weight'] as Map;
      expect((weight['summary'] as Map)['recordCount'], 2);
      expect(weight['readStatus'], 'verified');
    },
  );

  test('BIL39 an unavailable weight repository is not verified empty', () {
    final failed = CoachContextSnapshot.empty();
    expect(failed.weightReadStatus, CoachWeightReadStatus.unavailable);
    expect((failed.toJson()['weight'] as Map)['readStatus'], 'unavailable');
    final consentOff = CoachContextSnapshot(
      generatedAt: DateTime.utc(2026, 10, 25),
      profile: const <String, Object?>{},
      weights: const <CoachWeightPoint>[],
      weightReadStatus: CoachWeightReadStatus.withheld,
      nutritionDays: const <CoachNutritionDay>[],
      waterHistory: const <Map<String, Object?>>[],
      computedHealth: const <String, Object?>{},
    );
    expect((consentOff.toJson()['weight'] as Map)['readStatus'], 'withheld');
  });
}
