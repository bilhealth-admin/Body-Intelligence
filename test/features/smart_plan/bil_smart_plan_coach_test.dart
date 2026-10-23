import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_action_truth.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_admission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_cloud_privacy_boundary.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_coach.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bil_smart_plan_engine_test.dart' show buildRequest;

void main() {
  final now = DateTime(2026, 10, 22);
  test(
    'plan navigation cannot hide urgent symptoms or accept a week weight deadline as an observation',
    () {
      expect(
        const IntelligenceCenterEngine().requiresSafetyResponse(
          'I need a plan but have chest pain',
        ),
        isTrue,
      );
      expect(
        const IntelligenceCenterEngine().requiresSafetyResponse(
          'أريد خطة وعندي ألم صدر',
        ),
        isTrue,
      );
      expect(
        smartPlanGoalNeedsReview('أريد خطة حتى أوصل 60 خلال أسبوع'),
        isTrue,
      );
      expect(
        smartPlanGoalNeedsReview('a plan to reach my target 60kg in one week'),
        isTrue,
      );
      expect(smartPlanGoalNeedsReview('a 7 day workout plan'), isFalse);
      expect(smartPlanGoalNeedsReview('أريد خطة تمارين لأسبوع'), isFalse);
    },
  );
  test(
    'unverified first-person saves are blocked without blocking instructions or safety advice',
    () {
      for (final text in [
        'I have saved your plan.',
        'I have initiated a draft Smart Plan.',
        'I have drafted a plan for your review.',
        'جهزت لك الخطة.',
        'تم إنشاء المسودة.',
        "I've logged your workout.",
        'تم حفظ الخطة.',
        'لقد سجلت لك الوزن.',
        'حفظت الخطة بنجاح.',
      ]) {
        expect(modelClaimsUnverifiedAction(text), isTrue, reason: text);
      }
      for (final text in [
        'Please review this plan before saving.',
        'Save the plan using the button.',
        'I cannot save your plan.',
        'لم يتم حفظ الخطة.',
        'يمكنك حفظ الخطة بعد المراجعة.',
      ]) {
        expect(modelClaimsUnverifiedAction(text), isFalse, reason: text);
      }
    },
  );
  test(
    'model action is only a proposal and a false save is never spoken as a receipt',
    () async {
      final api = ModelBackedLocalCoachApi(
        gateway: _PlanModel(),
        context: CoachContextSnapshot(
          generatedAt: now,
          profile: const {},
          weights: const [],
          nutritionDays: const [],
          waterHistory: const [],
          computedHealth: const {},
        ),
      );
      final result = await api.understand(
        const LocalCoachRequest(
          text: 'Could you help organize this week?',
          locale: 'en',
        ),
      );
      expect(result.answer, contains('no verified save receipt'));
      expect(result.spokenAnswer, isNull);
      expect(result.actions.single.toolId, 'create_smart_plan_draft');
    },
  );
  test(
    'natural plan and today requests are recognized without inventing a weight log',
    () {
      expect(smartPlanIntent('please i need to plan'), BilSmartPlanIntent.open);
      expect(
        smartPlanIntent('أريد خطة حتى أوصل 60 خلال أسبوع'),
        BilSmartPlanIntent.open,
      );
      expect(
        smartPlanIntent('what is my workout today?'),
        BilSmartPlanIntent.today,
      );
      expect(smartPlanIntent('أريد تمرين اليوم'), BilSmartPlanIntent.today);
      for (final input in [
        'goal aim or target 60kg',
        'I weigh 83 kg',
        'هدفي 60 كيلو',
        'what are calories?',
        'اكلت 100غ Rice و 200غ Chicken غداء اليوم',
        'أكلت وجباتي اليوم',
        'تناولت الغداء اليوم',
        'سجل طعام اليوم',
        'Log my food today',
        'I ate my meals today',
        'What food have I eaten today?',
        'Show my logged meals today',
        'Record my workout today',
      ]) {
        expect(smartPlanIntent(input), BilSmartPlanIntent.none, reason: input);
      }
    },
  );
  test(
    'registry rejects injected identity, authorization, confirmation and malformed dates',
    () {
      const registry = BilToolRegistry();
      final record = registry.lookup('record_smart_plan_workout')!;
      final valid = <String, Object?>{
        'planId': 'plan-456',
        'revision': 2,
        'date': '2026-10-22',
      };
      expect(record.validateArguments(valid), isNotNull);
      for (final key in [
        'ownerId',
        'owner_id',
        'confirmed',
        'premium',
        'healthKit',
        'skipConsent',
        'sql',
      ]) {
        expect(
          record.validateArguments({...valid, key: true}),
          isNull,
          reason: key,
        );
      }
      for (final date in [
        '2026-02-30',
        '2026-1-2',
        '2026-10-22T00:00:00Z',
        ';drop table users',
      ]) {
        expect(record.validateArguments({...valid, 'date': date}), isNull);
      }
      expect(record.validateArguments({...valid, 'revision': 2.4}), isNull);
      expect(
        record.validateArguments({...valid, 'planId': '../other-owner'}),
        isNull,
      );
      expect(record.minimumTier, BilToolTier.premium);
      expect(record.requiresConfirmation, isTrue);
    },
  );
  test(
    'writes retain an app-owned operation identity and reads remain read only',
    () {
      const registry = BilToolRegistry();
      final action = registry.createAction(
        name: 'create_smart_plan_draft',
        arguments: const {},
        label: 'Review',
      )!;
      const admission = CoachActionAdmission();
      expect(admission.bind(action, requireOperationId: true), isNull);
      final admitted = admission.admitProposal(
        action,
        createOperationId: () => 'plan-operation-1',
      )!;
      expect(admitted.operationId, 'plan-operation-1');
      expect(
        admission.bind(admitted, requireOperationId: true)!.writesData,
        isTrue,
      );
      final read = registry.createAction(
        name: 'read_active_smart_plan',
        arguments: const {},
        label: 'Read',
      )!;
      expect(admission.bind(read)!.writesData, isFalse);
    },
  );
  test(
    'memory contains provenance and today, not six months of private history',
    () {
      final plan = const BilSmartPlanEngine().generate(
        buildRequest(horizon: BilPlanHorizon.sixMonths),
        now,
      );
      final memory = smartPlanContext(
        plan,
        now,
        includeTraining: true,
        includeNutrition: false,
      );
      expect(memory['revision'], 1);
      expect(memory['provenance'], 'owner_scoped_saved_smart_plan');
      expect(memory.containsKey('mealSuggestions'), isFalse);
      expect(memory.containsKey('days'), isFalse);
      expect(memory['dueWorkouts'], 1);
      expect(memory['confirmedWorkouts'], 0);
      expect(
        smartPlanContext(
          plan,
          now,
          includeTraining: false,
          includeNutrition: false,
        ),
        isEmpty,
      );
    },
  );
  test(
    'cloud context respects separate training/nutrition question boundaries',
    () {
      final plan = const BilSmartPlanEngine().generate(buildRequest(), now);
      final context = CoachContextSnapshot(
        generatedAt: now,
        profile: const {},
        weights: const [],
        nutritionDays: const [],
        waterHistory: const [],
        computedHealth: const {},
        smartPlan: smartPlanContext(
          plan,
          now,
          includeTraining: true,
          includeNutrition: true,
        ),
      );
      final sleep = projectCoachCloudContext(
        question: 'How did I sleep?',
        context: context,
      );
      expect(sleep.context.containsKey('smartPlan'), isFalse);
      final workout = projectCoachCloudContext(
        question: 'Which workout is in my plan?',
        context: context,
      );
      final training = workout.context['smartPlan']! as Map;
      expect(training.containsKey('plannedWorkout'), isTrue);
      expect(training.containsKey('mealSuggestions'), isFalse);
      expect(
        workout.disclosure['included_context_fields'],
        contains('smartPlan'),
      );
      final nutrition = projectCoachCloudContext(
        question: 'Which meals are in my plan?',
        context: context,
      );
      final meals = nutrition.context['smartPlan']! as Map;
      expect(meals.containsKey('mealSuggestions'), isTrue);
      expect(meals.containsKey('plannedWorkout'), isFalse);
      final noOptIn = projectCoachCloudContext(
        question: 'workout plan',
        context: CoachContextSnapshot.empty(),
      );
      expect(noOptIn.context.containsKey('smartPlan'), isFalse);
    },
  );
  test(
    'postponement changes only uncompleted schedule with explicit revision',
    () {
      final plan = const BilSmartPlanEngine()
          .generate(buildRequest(), now)
          .withStatus(BilPlanStatus.active, now);
      final next = plan.deferWorkout(date: now, now: now);
      expect(next.revision, plan.revision + 1);
      expect(next.days.first.workout, isNull);
      expect(
        next.days[1].workout!.templateId,
        plan.days.first.workout!.templateId,
      );
      expect(
        next.days.first.meals.first.recipeId,
        plan.days.first.meals.first.recipeId,
      );
      final completed = plan.recordWorkout(
        date: now,
        now: now,
        completed: true,
      );
      expect(
        () => completed.deferWorkout(date: now, now: now),
        throwsStateError,
      );
      expect(
        () =>
            plan.deferWorkout(date: now, now: now.add(const Duration(days: 1))),
        throwsStateError,
      );
    },
  );
  test(
    'additional training context needs its own explicit scope and never leaks to a meals question',
    () {
      final plan = const BilSmartPlanEngine()
          .generate(buildRequest(), now)
          .withStatus(BilPlanStatus.active, now);
      final basic = smartPlanContext(
        plan,
        now,
        includeTraining: true,
        includeNutrition: true,
      );
      expect(basic.containsKey('trainingWeek'), isFalse);
      expect(basic.containsKey('recentChanges'), isFalse);
      final extended = smartPlanContext(
        plan,
        now,
        includeTraining: true,
        includeNutrition: true,
        includeExtendedContext: true,
      );
      expect((extended['trainingWeek'] as List).length, lessThanOrEqualTo(7));
      final context = CoachContextSnapshot(
        generatedAt: now,
        profile: const {},
        weights: const [],
        nutritionDays: const [],
        waterHistory: const [],
        computedHealth: const {},
        smartPlan: {
          ...extended,
          'trainingPreferences': {
            'environment': 'home',
            'experience': 'beginner',
            'equipment': ['none', 'secret equipment'],
            'preferredTime': '18:00',
            'privateMedicalNote': 'must not leave',
          },
          'trainingWeek': [
            {
              'date': '2026-10-22',
              'workout': {
                'templateId': 'push-a',
                'exerciseIds': ['ex-1'],
                'minutes': 30,
                'completed': false,
                'ownerId': 'foreign',
                'privateMedicalNote': 'must not leave',
              },
            },
          ],
        },
      );
      final training =
          projectCoachCloudContext(
                question: 'workout plan',
                context: context,
              ).context['smartPlan']!
              as Map;
      expect(
        (training['trainingPreferences'] as Map).containsKey(
          'privateMedicalNote',
        ),
        isFalse,
      );
      expect((training['trainingPreferences'] as Map)['equipment'], ['none']);
      expect(
        (((training['trainingWeek'] as List).first as Map)['workout'] as Map)
            .containsKey('ownerId'),
        isFalse,
      );
      final nutrition =
          projectCoachCloudContext(
                question: 'meals in my plan',
                context: context,
              ).context['smartPlan']!
              as Map;
      expect(nutrition.containsKey('trainingWeek'), isFalse);
      expect(nutrition.containsKey('trainingPreferences'), isFalse);
    },
  );
}

class _PlanModel implements LocalModelGateway {
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async => const LocalModelResult.answer(
    LocalModelAnswer(
      text: 'I have saved your plan.',
      spokenText: 'I have activated your plan.',
      action: {
        'name': 'create_smart_plan_draft',
        'arguments': <String, Object?>{},
      },
    ),
  );
}
