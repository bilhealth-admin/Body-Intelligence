import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlapping HealthKit in-bed and stages produce one asleep total', () {
    final day = DateTime.utc(2026, 8, 22, 22);
    GlobalHealthSignal row(
      String id,
      String stage,
      int startMinutes,
      int durationMinutes,
    ) => GlobalHealthSignal(
      key: 'sleep',
      canonicalValue: durationMinutes / 60,
      canonicalUnit: 'h',
      provenance: GlobalProvenance(
        providerId: 'apple-health',
        sourceId: 'com.apple.health',
        recordId: id,
        observedAt: day.add(Duration(minutes: startMinutes)),
        confidence: 1,
        timeZoneId: 'Africa/Cairo',
      ),
      attributes: {
        'sleepStage': stage,
        'endedAt': day
            .add(Duration(minutes: startMinutes + durationMinutes))
            .toIso8601String(),
      },
    );

    final result = aggregateConnectedSleepSignals([
      row('bed', 'inBed', 0, 540),
      row('core-1', 'core', 30, 180),
      row('deep', 'deep', 210, 120),
      row('awake', 'awake', 330, 30),
      row('core-2', 'core', 360, 120),
      row('rem', 'rem', 480, 60),
    ]);

    expect(result, hasLength(1));
    expect(result.single.canonicalUnit, 'h');
    expect(result.single.canonicalValue, 8);
    expect(result.single.attributes['measuredStages'], isNotEmpty);
    expect(
      result.single.attributes['sourceSessionIds'],
      isNot(contains('bed')),
    );
    expect(
      result.single.attributes['sourceSessionIds'],
      isNot(contains('awake')),
    );
  });

  test(
    'Android session total with optional nested stages is not re-summed',
    () {
      final signal = GlobalHealthSignal(
        key: 'sleep',
        canonicalValue: 7.25,
        canonicalUnit: 'h',
        provenance: GlobalProvenance(
          providerId: 'android-health-connect',
          sourceId: 'watch',
          recordId: 'session-1',
          observedAt: DateTime.utc(2026, 8, 22, 22),
          confidence: 1,
        ),
        attributes: const {
          'endedAt': '2026-08-23T05:15:00.000Z',
          'stages': <Object?>[],
        },
      );

      final result = aggregateConnectedSleepSignals([signal]);
      expect(result, [same(signal)]);
    },
  );
}
