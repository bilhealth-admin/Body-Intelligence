import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protein answer names and evidences its persisted source', () async {
    final context = CoachContextSnapshot(
      generatedAt: DateTime.utc(2026, 8, 20),
      profile: const {},
      weights: const [],
      nutritionDays: const [],
      waterHistory: const [],
      computedHealth: const {
        'dailyTargets': {'proteinG': 162.0},
        'dailyTargetSources': {'proteinG': 'saved_gram_goal'},
      },
    );

    final reply = await const IntelligenceCenterEngine().answer(
      question: 'How much protein do I need?',
      arabic: false,
      coachContext: context,
    );

    expect(reply.message.text, contains('162 g'));
    expect(reply.message.text, contains('saved in Nutrition Goals'));
    expect(reply.message.evidence, contains('dailyTargets.proteinG'));
    expect(reply.message.evidence, contains('saved_gram_goal'));
  });

  test(
    'protein answer does not label a body calculation as a saved plan',
    () async {
      final context = CoachContextSnapshot(
        generatedAt: DateTime.utc(2026, 8, 20),
        profile: const {},
        weights: const [],
        nutritionDays: const [],
        waterHistory: const [],
        computedHealth: const {
          'dailyTargets': {'proteinG': 146.0},
          'dailyTargetSources': {'proteinG': 'body_profile_calculation'},
        },
      );

      final reply = await const IntelligenceCenterEngine().answer(
        question: 'protein',
        arabic: false,
        coachContext: context,
      );

      expect(reply.message.text, contains('body-profile calculation'));
      expect(reply.message.text, isNot(contains('saved in your BIL plan')));
    },
  );
}
