import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_daily_history.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_daily_history_view.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';

void main() {
  final end = DateTime(2026, 9, 30, 8);
  GlobalHealthSignal row(
    String id,
    String key,
    double value,
    DateTime at, {
    String source = 'watch',
    String? unit,
    double confidence = 1,
    bool deleted = false,
    Map<String, Object?> attributes = const {},
  }) => GlobalHealthSignal(
    key: key,
    canonicalValue: value,
    canonicalUnit: unit ?? (key == 'activeEnergy' ? 'kcal' : 'count/min'),
    deleted: deleted,
    provenance: GlobalProvenance(
      providerId: 'bil/apple_health',
      sourceId: source,
      recordId: id,
      observedAt: at,
      confidence: confidence,
    ),
    attributes: attributes,
  );
  GlobalHealthSignal hr(String id, double value, int hour) =>
      row(id, 'heartRate', value, DateTime(2026, 9, 29, hour));
  List<GlobalHealthSignal> project(
    List<GlobalHealthSignal> rows, {
    List<GlobalHealthSignal> retained = const [],
    List<GlobalHealthSignal> native = const [],
    List<GlobalHealthSignal> evidence = const [],
    DateTime? at,
  }) => projectConnectedDailyHistory(
    ConnectedDailyHistoryInput(
      samples: rows,
      retained: retained,
      nativeTotals: native,
      selectedEvidence: evidence,
      asOf: at ?? end,
    ),
  );
  GlobalHealthSignal energy(String id, double value, int hour) => row(
    id,
    'activeEnergy',
    value,
    DateTime(2026, 9, 29, hour),
    attributes: const {'aggregation': 'native_daily'},
  );

  test('sample mean, peak and first threshold instant are factual', () {
    final result = project([
      hr('c', 140, 14),
      hr('a', 80, 8),
      hr('b', 110, 10),
    ]).single;
    expect(result.canonicalValue, 110);
    expect(result.attributes['sampleCount'], 3);
    expect(result.attributes['aboveThresholdCount'], 2);
    expect(result.attributes['dailyMaximum'], 140);
    expect(
      result.attributes['firstAboveThresholdAt'],
      DateTime(2026, 9, 29, 10).toUtc().toIso8601String(),
    );
    expect(
      result.attributes['peakObservedAt'],
      DateTime(2026, 9, 29, 14).toUtc().toIso8601String(),
    );
  });
  test('exactly 100 is not above the threshold', () {
    expect(
      project([hr('a', 100, 8)]).single.attributes['aboveThresholdCount'],
      0,
    );
  });
  test('fractional over-100 readings retain the exact peak', () {
    final value = project([hr('a', 100.1, 8)]).single;
    expect(value.attributes['aboveThresholdCount'], 1);
    expect(value.attributes['dailyMaximum'], 100.1);
  });
  test('duplicate record identities do not weight the mean twice', () {
    final a = hr('a', 80, 8);
    final b = hr('b', 120, 9);
    expect(project([a, a, b, b]).single.canonicalValue, 100);
    expect(project([a, a, b, b]).single.attributes['sampleCount'], 2);
  });
  test('corrected raw identity replaces previous value', () {
    expect(project([hr('a', 80, 8), hr('a', 90, 8)]).single.canonicalValue, 90);
  });
  test('new samples replace a summary, never average previous averages', () {
    final raw = [hr('a', 60, 8), hr('b', 120, 9)];
    final prior = project(raw).single;
    final current = project(
      [...raw, hr('c', 120, 10)],
      retained: [prior],
    ).single;
    expect(current.canonicalValue, 100);
    expect(current.attributes['sampleCount'], 3);
    expect(current.identity, prior.identity);
  });
  test('1000 samples aggregate before a preview bound', () {
    final values = [
      for (var i = 0; i < 1000; i++)
        row('$i', 'heartRate', i < 500 ? 60 : 120, DateTime(2026, 9, 29, 0, i)),
    ];
    expect(project(values).single.attributes['sampleCount'], 1000);
    expect(project(values).single.canonicalValue, 90);
  });
  test('two days produce exactly two rows', () {
    final result = project([
      hr('a', 80, 8),
      hr('b', 90, 9),
      row('c', 'heartRate', 70, DateTime(2026, 9, 28, 8)),
    ]);
    expect(result, hasLength(2));
    expect(result.first.attributes['historyLocalDay'], '2026-09-29');
  });
  test('native energy is never added to samples or other daily totals', () {
    final result = project(
      [row('raw', 'activeEnergy', 25, DateTime(2026, 9, 29, 8))],
      native: [energy('late', 600, 12), energy('early', 400, 9)],
    );
    expect(result, hasLength(1));
    expect(result.single.canonicalValue, 600);
  });
  test('same-timestamp downward native correction is honored', () {
    final prior = project([], native: [energy('day', 600, 12)]).single;
    expect(
      project(
        [],
        retained: [prior],
        native: [energy('day', 450, 12)],
      ).single.canonicalValue,
      450,
    );
  });
  test('empty native refresh preserves a trusted total', () {
    final prior = project([], native: [energy('day', 600, 12)]).single;
    expect(
      project(
        [row('raw', 'activeEnergy', 25, DateTime(2026, 9, 29, 8))],
        retained: [prior],
      ).single.canonicalValue,
      600,
    );
  });
  test('raw-only energy is explicitly an imported interval sum', () {
    final a = row('a', 'activeEnergy', 20, DateTime(2026, 9, 29, 8));
    final result = project([
      a,
      a,
      row('b', 'activeEnergy', 30, DateTime(2026, 9, 29, 9)),
    ]).single;
    expect(result.canonicalValue, 50);
    expect(result.attributes['historyAggregation'], 'imported_interval_sum');
  });
  test('zero energy is valid evidence but absent energy is not zero', () {
    expect(project([], native: [energy('a', 0, 12)]).single.canonicalValue, 0);
    expect(project([]), isEmpty);
  });
  test('only the selected source contributes in a conflicted minute', () {
    final first = row('a', 'heartRate', 60, DateTime(2026, 9, 29, 8, 0, 1));
    final second = row('b', 'heartRate', 100, DateTime(2026, 9, 29, 8, 0, 30));
    final other = row(
      'x',
      'heartRate',
      180,
      DateTime(2026, 9, 29, 8, 0, 5),
      source: 'other',
    );
    final result = project([first, second, other], evidence: [first]).single;
    expect(result.canonicalValue, 80);
    expect(result.attributes['sampleCount'], 2);
  });
  test('resting and ordinary heart observations are not blended', () {
    final result = project([
      hr('a', 100, 8),
      row('rest', 'restingHeartRate', 60, DateTime(2026, 9, 29, 8)),
    ]);
    expect(result, hasLength(2));
    final views = result.map(ConnectedHealthSignalView.fromSignal);
    expect(closedHeartHistory(views, end).single.key, 'heartRate');
    expect(closedHeartHistory(views, end).single.value, 100);
  });
  test('resting-only day remains explicitly resting', () {
    final result = project([
      row('rest', 'restingHeartRate', 60, DateTime(2026, 9, 29, 8)),
    ]);
    expect(
      closedHeartHistory(
        result.map(ConnectedHealthSignalView.fromSignal),
        end,
      ).single.key,
      'restingHeartRate',
    );
  });
  test('today average stays hidden until local day ends', () {
    final at = DateTime(2026, 9, 29, 23, 59);
    final views = project([
      hr('a', 80, 8),
    ], at: at).map(ConnectedHealthSignalView.fromSignal);
    expect(closedHeartHistory(views, at), isEmpty);
    expect(closedHeartHistory(views, DateTime(2026, 9, 30)), hasLength(1));
  });
  test('local midnight closes the previous day', () {
    expect(
      connectedHistoryDayComplete(
        '2026-09-29',
        DateTime(2026, 9, 29, 23, 59, 59),
      ),
      isFalse,
    );
    expect(
      connectedHistoryDayComplete('2026-09-29', DateTime(2026, 9, 30)),
      isTrue,
    );
  });
  test('invalid calendar days are rejected', () {
    expect(connectedHistoryDate('2026-02-30'), isNull);
    expect(connectedHistoryDate('2026-13-01'), isNull);
    expect(connectedHistoryDayComplete('not-a-day', end), isFalse);
  });
  test(
    'future, wrong-unit, nonfinite, deleted and unverified samples are excluded',
    () {
      expect(
        project([
          row('future', 'heartRate', 80, DateTime(2027)),
          row('bad', 'heartRate', 80, DateTime(2026, 9, 29), unit: 'kg'),
          row('nan', 'heartRate', double.nan, DateTime(2026, 9, 29)),
          row('deleted', 'heartRate', 80, DateTime(2026, 9, 29), deleted: true),
          row(
            'unverified',
            'heartRate',
            80,
            DateTime(2026, 9, 29),
            confidence: 0,
          ),
        ]),
        isEmpty,
      );
    },
  );
  test('projection keeps provenance and never mutates raw observations', () {
    final a = hr('a', 80, 8);
    final before = a.toMap();
    final result = project([a]).single;
    expect(result.provenance.providerId, a.provenance.providerId);
    expect(result.attributes['sourceSessionIds'], ['a']);
    expect(a.toMap(), before);
  });
  test('pre-upgrade bpm rows compact without changing the live value', () {
    final a = ConnectedHealthSignalView(
      key: 'heartRate',
      value: 80,
      unit: 'bpm',
      source: 'Apple Watch',
      observedAt: DateTime(2026, 9, 29, 8),
      confidence: 1,
    );
    final b = ConnectedHealthSignalView(
      key: 'heartRate',
      value: 100,
      unit: 'bpm',
      source: 'Apple Watch',
      observedAt: DateTime(2026, 9, 29, 9),
      confidence: 1,
    );
    final result = compactConnectedHistoryViews([a, b], end);
    expect(result, hasLength(1));
    expect(result.single.value, 90);
    expect(b.value, 100);
  });
}
