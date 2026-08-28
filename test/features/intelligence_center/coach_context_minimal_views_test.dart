import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_speech_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty context contains no invented personal values', () {
    final snapshot = CoachContextSnapshot.empty(
      generatedAt: DateTime.utc(2026, 8, 14),
    );
    expect(snapshot.minimalIdentity, isEmpty);
    expect(snapshot.weights, isEmpty);
    expect(snapshot.nutritionDays, isEmpty);
    expect(snapshot.waterHistory, isEmpty);
    expect(snapshot.computedHealth, isEmpty);
    expect(snapshot.nutritionRemainingFor(DateTime.utc(2026, 8, 14)), isNull);
  });

  test('identity view exposes only saved display name', () {
    final snapshot = CoachContextSnapshot(
      generatedAt: DateTime(2026, 8, 11),
      profile: const {'displayName': 'Kadem', 'age': 40, 'currentWeightKg': 90},
      weights: const [],
      nutritionDays: const [],
      waterHistory: const [],
      computedHealth: const {},
    );
    expect(snapshot.minimalIdentity, {'displayName': 'Kadem'});
  });

  test('remaining nutrition subtracts same local day and clamps at zero', () {
    final snapshot = CoachContextSnapshot(
      generatedAt: DateTime(2026, 8, 11),
      profile: const {},
      weights: const [],
      nutritionDays: const [
        CoachNutritionDay(
          day: '2026-08-11',
          meals: [],
          calories: 1700,
          protein: 160,
          carbs: 100,
          fat: 30,
          sodium: 800,
        ),
      ],
      waterHistory: const [],
      computedHealth: const {
        'dailyTargets': {
          'caloriesKcal': 2000,
          'proteinG': 150,
          'carbsG': 220,
          'fatG': 70,
        },
      },
    );
    expect(snapshot.nutritionRemainingFor(DateTime(2026, 8, 11)), {
      'caloriesKcal': 300,
      'proteinG': 0,
      'carbsG': 120,
      'fatG': 40,
    });
  });

  test('calorie-only history never invents zero macro evidence', () {
    final day = CoachNutritionDay(
      day: '2026-07-01',
      meals: const [],
      calories: 1252,
      protein: 0,
      carbs: 0,
      fat: 0,
      sodium: 0,
      knownTotals: const {'caloriesKcal'},
    );
    final totals = Map<String, Object?>.from(day.toJson()['totals']! as Map);
    expect(totals, {'caloriesKcal': 1252.0});
    expect(totals, isNot(contains('proteinG')));

    final snapshot = CoachContextSnapshot(
      generatedAt: DateTime.utc(2026, 7, 1),
      profile: const {},
      weights: const [],
      nutritionDays: [day],
      waterHistory: const [],
      computedHealth: const {
        'dailyTargets': {
          'caloriesKcal': 2000,
          'proteinG': 150,
          'carbsG': 200,
          'fatG': 70,
        },
      },
    );
    expect(snapshot.nutritionRemainingFor(DateTime(2026, 7, 1)), isNull);
  });

  test(
    'recorded weight is answered locally in the question language',
    () async {
      final snapshot = CoachContextSnapshot(
        generatedAt: DateTime.utc(2026, 8, 20),
        profile: const {'currentWeightKg': 83.4},
        weights: [CoachWeightPoint(at: DateTime.utc(2026, 8, 20), kg: 82.7)],
        nutritionDays: const [],
        waterHistory: const [],
        computedHealth: const {},
      );
      const engine = IntelligenceCenterEngine();
      final arabic = await engine.answer(
        question: 'كم وزني؟',
        arabic: true,
        localeCode: 'ar',
        coachContext: snapshot,
      );
      final spanish = await engine.answer(
        question: '¿Cuánto peso?',
        arabic: false,
        localeCode: 'es',
        coachContext: snapshot,
      );

      expect(arabic.message.text, contains('82.7'));
      expect(arabic.message.text, contains('كغ'));
      expect(spanish.message.text, contains('82.7 kg'));
      expect(spanish.message.text, isNot(contains('Your latest')));
      expect(arabic.usedExternalKnowledge, isFalse);
    },
  );

  test(
    'weight analysis is not hijacked by the latest-weight shortcut',
    () async {
      const engine = IntelligenceCenterEngine(localApi: _AnsweringLocalApi());
      final reply = await engine.answer(
        question: 'Why is my weight stable?',
        arabic: false,
        localeCode: 'en',
        coachContext: CoachContextSnapshot(
          generatedAt: DateTime.utc(2026, 8, 20),
          profile: const {'currentWeightKg': 83.4},
          weights: [CoachWeightPoint(at: DateTime.utc(2026, 8, 20), kg: 82.7)],
          nutritionDays: const [],
          waterHistory: const [],
          computedHealth: const {},
        ),
      );

      expect(reply.message.text, 'analysis-path');
      expect(reply.message.text, isNot(contains('82.7')));
    },
  );

  test('short sleep question is answered and spoken locally', () async {
    const engine = IntelligenceCenterEngine(localApi: _FailIfCalledLocalApi());
    final reply = await engine.answer(
      question: 'كم لازم أنام؟',
      arabic: true,
      localeCode: 'ar',
    );

    expect(reply.message.text, contains('7–9'));
    expect(reply.spokenText, reply.message.text);
    expect(reply.runtime.name, 'onDevice');
    expect(
      const CoachSpeechPolicy().canSpeakWithinTenSeconds(reply.spokenText!),
      isTrue,
    );
  });
}

class _AnsweringLocalApi implements LocalCoachApi {
  const _AnsweringLocalApi();

  @override
  Future<LocalCoachResult> understand(LocalCoachRequest request) async =>
      const LocalCoachResult(
        actions: [],
        processedOnDevice: false,
        answer: 'analysis-path',
      );
}

class _FailIfCalledLocalApi implements LocalCoachApi {
  const _FailIfCalledLocalApi();

  @override
  Future<LocalCoachResult> understand(LocalCoachRequest request) =>
      throw StateError('Sleep must be answered before any model gateway call.');
}
