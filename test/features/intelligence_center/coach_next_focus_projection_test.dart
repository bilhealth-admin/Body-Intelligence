import 'dart:convert';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_cloud_privacy_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final selectedTraining = CoachContextSnapshot(
    generatedAt: DateTime.utc(2026, 10, 28),
    profile: const {},
    weights: const [],
    weightReadStatus: CoachWeightReadStatus.withheld,
    nutritionDays: const [],
    waterHistory: const [],
    computedHealth: const {
      'today': {
        'day': '2026-10-28',
        'exerciseEnergy': {
          'verifiedBurnedKcal': 177.0,
          'burnSource': 'connected_health',
        },
      },
    },
    activityHistory: const [
      {'day': '2026-10-28', 'steps': 3000},
    ],
  );
  for (final question in [
    'Based on my selected BIL context, what is the single best thing to focus on next and why?',
    'بناءً على سياق BIL الذي اخترته، ما أفضل شيء واحد أركز عليه الآن ولماذا؟',
  ]) {
    test(
      'explicit selected-context Overview retains available verified activity: $question',
      () {
        final projected = projectCoachCloudContext(
          question: question,
          context: selectedTraining,
        );
        final today =
            (projected.context['computedHealth']! as Map)['today'] as Map;
        expect((today['exerciseEnergy'] as Map)['verifiedBurnedKcal'], 177.0);
        expect(projected.context['activityHistory'], [
          {'day': '2026-10-28', 'steps': 3000},
        ]);
        expect(today, isNot(contains('sleep')));
        expect(jsonEncode(projected.context), isNot(contains('sleepHours')));
      },
    );
  }
  test('ordinary general question still receives no activity context', () {
    final projected = projectCoachCloudContext(
      question: 'Hello',
      context: selectedTraining,
    );
    expect(projected.context, isNot(contains('activityHistory')));
    expect(projected.context, isNot(contains('computedHealth')));
  });
}
