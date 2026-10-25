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

  test('BIL39 short weight history follow-ups never become a plan or write', () {
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
        resolveCoachWeightHistoryFollowUp(
          'شهر',
          previousUserRequest: prior,
        ),
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
  });

  test('BIL39 review buttons never authorize unsolicited Smart Plan actions', () {
    for (final question in <String>[
      'Review my day from my saved BIL data and tell me the most useful next step.',
      'Review today’s nutrition from my saved BIL data.',
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
    final appChange = commands.parse('غير لغة التطبيق للانجليزي', locale: 'ar');
    expect(appChange, hasLength(1));
    expect(appChange.single.type, IntelligenceActionType.setLanguage);
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
