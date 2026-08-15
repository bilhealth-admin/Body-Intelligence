import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
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
}
