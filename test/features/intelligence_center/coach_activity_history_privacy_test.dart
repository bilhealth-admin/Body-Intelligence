import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rows = <Map<String, Object?>>[
    {
      'day': '2026-10-26',
      'steps': 3000,
      'exercises': <Object>[],
      'sleepHours': 6.5,
      'sleepSource': 'manual',
      'futureSensitiveField': 'excluded',
    },
    {
      'day': '2026-10-27',
      'sleepHours': 7.25,
      'sleepSource': 'connected_health',
      'sleepDeviceSource': 'Apple Health',
      'sleepObservedAt': '2026-10-27T06:00:00Z',
      'sleepLastSyncAt': '2026-10-27T07:00:00Z',
    },
  ];
  test(
    'all independent training/habits combinations scope manual and connected history',
    () {
      for (final training in [false, true]) {
        for (final habits in [false, true]) {
          final scoped = scopeCoachActivityHistoryForFocus(
            rows,
            includeTraining: training,
            includeHabits: habits,
          );
          expect(scoped.any((r) => r.containsKey('steps')), training);
          expect(scoped.any((r) => r.containsKey('sleepHours')), habits);
          for (final row in scoped) {
            expect(row, isNot(contains('futureSensitiveField')));
            expect(row.length, greaterThan(1));
            if (!training) expect(row.keys, isNot(contains('exercises')));
            if (!habits) {
              expect(row.keys.any((key) => key.startsWith('sleep')), isFalse);
            }
          }
          if (habits) expect(scoped.last['sleepDeviceSource'], 'Apple Health');
        }
      }
      expect(
        rows.first['sleepHours'],
        6.5,
      ); // Scoping never mutates stored input.
    },
  );
}
