import 'dart:io';

import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete weight summary survives a bounded recent history sample', () {
    final recent = List<CoachWeightPoint>.generate(
      61,
      (index) => CoachWeightPoint(
        at: DateTime.utc(2026, 6, 20).add(Duration(days: index)),
        kg: 101 - (index * 0.18),
      ),
    );
    final snapshot = CoachContextSnapshot(
      generatedAt: DateTime.utc(2026, 8, 22),
      profile: const <String, Object?>{},
      weights: <CoachWeightPoint>[
        CoachWeightPoint(at: DateTime.utc(2026, 8, 20), kg: 89.2),
        ...recent.reversed,
        CoachWeightPoint(at: DateTime.utc(2026, 2, 9), kg: 123),
      ],
      nutritionDays: const <CoachNutritionDay>[],
      waterHistory: const <Map<String, Object?>>[],
      computedHealth: const <String, Object?>{},
    );

    final weight = Map<String, Object?>.from(
      snapshot.toJson()['weight']! as Map,
    );
    final summary = Map<String, Object?>.from(weight['summary']! as Map);
    final first = Map<String, Object?>.from(summary['firstRecorded']! as Map);
    final latest = Map<String, Object?>.from(summary['latestRecorded']! as Map);
    final months = (summary['monthly']! as List)
        .map((value) => (value as Map)['month'])
        .toList(growable: false);

    expect(summary['recordCount'], 63);
    expect(first['at'], '2026-02-09T00:00:00.000Z');
    expect(first['kg'], 123);
    expect(latest['at'], '2026-08-20T00:00:00.000Z');
    expect(latest['kg'], 89.2);
    expect(summary['totalChangeKg'], closeTo(-33.8, 0.0001));
    expect(
      months,
      containsAllInOrder(<String>['2026-02', '2026-06', '2026-07', '2026-08']),
    );
    expect(summary['monthlyCoverageComplete'], isTrue);
  });

  test('remote context retains summary while limiting raw weight rows', () {
    final source = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();
    expect(
      source,
      contains(
        "final weight = Map<String, Object?>.from(full['weight']! as Map)",
      ),
    );
    expect(source, contains("weight['history'] = context.weights"));
    expect(source, contains('.take(60)'));
    expect(source, isNot(contains("weight['summary'] =")));

    final server = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();
    expect(server, contains('weight.summary is authoritative'));
    expect(server, contains('weight.summary.firstRecorded is earlier'));
  });
}
