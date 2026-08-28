import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_daily_brief.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = CoachDailyBriefEngine();
  final now = DateTime(2026, 8, 21, 12);

  CoachContextSnapshot snapshot({
    Map<String, Object?> profile = const {'displayName': 'Kadem'},
    List<CoachWeightPoint> weights = const [],
    List<CoachNutritionDay> nutrition = const [],
    Map<String, Object?> computed = const {},
    List<Map<String, Object?>> activity = const [],
    List<Map<String, Object?>> experiments = const [],
  }) => CoachContextSnapshot(
    generatedAt: now,
    profile: profile,
    weights: weights,
    nutritionDays: nutrition,
    waterHistory: const [],
    computedHealth: computed,
    activityHistory: activity,
    personalExperiments: experiments,
  );

  test('gives an immediate protein decision from today data', () {
    final brief = engine.build(
      context: snapshot(
        nutrition: const [
          CoachNutritionDay(
            day: '2026-08-21',
            meals: [],
            calories: 900,
            protein: 45,
            carbs: 90,
            fat: 30,
            sodium: 800,
          ),
        ],
        computed: const {
          'dailyTargets': {
            'caloriesKcal': 2100,
            'proteinG': 140,
            'carbsG': 220,
            'fatG': 70,
          },
        },
      ),
      now: now,
      locale: 'en',
    );

    expect(brief.kind, CoachDailyBriefKind.nutrition);
    expect(brief.message, contains('95 g protein'));
    expect(brief.suggestedPrompt, contains('protein'));
  });

  test('active experiment takes priority and is carried into the brief', () {
    final brief = engine.build(
      context: snapshot(
        experiments: const [
          {
            'status': 'active',
            'hypothesis': 'A protein breakfast improves morning satiety',
            'endsAt': '2026-08-27T12:00:00.000',
          },
        ],
      ),
      now: now,
      locale: 'en',
    );

    expect(brief.kind, CoachDailyBriefKind.experiment);
    expect(brief.message, contains('protein breakfast'));
  });

  test('a new user receives day-one guidance without historical data', () {
    final brief = engine.build(
      context: snapshot(profile: const {}),
      now: now,
      locale: 'en',
    );

    expect(brief.kind, CoachDailyBriefKind.onboarding);
    expect(brief.readiness, 0);
    expect(brief.actionLabel, isNotEmpty);
  });

  test('day-one decision has no English fallback in all 25 locales', () {
    for (final tag in BilLocalePolicy.productionTags) {
      final brief = engine.build(
        context: snapshot(profile: const {}),
        now: now,
        locale: tag,
      );
      expect(brief.title.trim(), isNotEmpty, reason: tag);
      expect(brief.message.trim(), isNotEmpty, reason: tag);
      if (tag != 'en') {
        expect(brief.title, isNot('Let’s make the first decision'), reason: tag);
        expect(
          brief.message,
          isNot(
            'Tell me your goal or photograph your next meal. I can start helping today and become more personal with each check-in.',
          ),
          reason: tag,
        );
      }
    }
  });
}
