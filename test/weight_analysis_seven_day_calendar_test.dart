import 'package:body_intelligence_log/engine/progress_analysis.dart';
import 'package:body_intelligence_log/engine/weight_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

ProgressSample _sample(
  int day,
  double kg, {
  int month = 11,
  int hour = 0,
  int minute = 0,
}) => ProgressSample(
  date: DateTime.utc(2026, month, day, hour, minute),
  weightKg: kg,
);

List<ProgressSample> _fourWeekSeries() => [
  _sample(20, 73, month: 10),
  _sample(27, 72.25, month: 10),
  _sample(3, 71.5),
  _sample(10, 70.75),
  _sample(17, 70),
];

void main() {
  final today = DateTime.utc(2026, 11, 17);
  double? change(List<ProgressSample> samples, {DateTime? endingOn}) =>
      WeightAnalysis.calculateSevenDayChange(
        samples: samples,
        endingOn: endingOn ?? today,
      );

  test('legacy numeric observation helper remains compatible', () {
    expect(
      WeightAnalysis.calculateWeeklyTrend([73, 72.25, 71.5, 70.75, 70]),
      -3,
    );
  });

  test('no observations cannot certify a seven-day change', () {
    expect(change([]), isNull);
  });

  test('one current observation cannot certify a seven-day change', () {
    expect(change([_sample(17, 70)]), isNull);
  });

  test('actual 73-to-70 over28days is not a seven-day change', () {
    expect(change([_sample(20, 73, month: 10), _sample(17, 70)]), isNull);
  });

  test('actual four weekly intervals report last observed week minus0.75', () {
    expect(change(_fourWeekSeries()), closeTo(-0.75, 1e-10));
  });

  test('eight daily endpoints cover seven days rather than six', () {
    final samples = [
      for (var offset = 0; offset <= 7; offset++)
        _sample(10 + offset, 80 - offset * 0.1),
    ];
    expect(change(samples), closeTo(-0.7, 1e-10));
  });

  test('seven consecutive daily observations span only six days', () {
    final samples = [
      for (var offset = 0; offset < 7; offset++)
        _sample(11 + offset, 80 - offset * 0.1),
    ];
    expect(change(samples), isNull);
  });

  test('nearby days cannot replace the missing seven-day endpoint', () {
    expect(
      change([_sample(9, 71), _sample(11, 70.75), _sample(17, 70)]),
      isNull,
    );
  });

  test('an old completed week cannot claim the current displayed week', () {
    final oldWeek = [_sample(3, 71.5), _sample(10, 70.75)];
    expect(change(oldWeek), isNull);
    expect(
      change(oldWeek, endingOn: DateTime.utc(2026, 11, 10)),
      closeTo(-0.75, 1e-10),
    );
  });

  test('unordered observations retain exact calendar endpoint meaning', () {
    final source = _fourWeekSeries();
    expect(
      change([source[4], source[1], source[3], source[0], source[2]]),
      closeTo(-0.75, 1e-10),
    );
  });

  test(
    'latest actual timestamp within each endpoint day wins in either order',
    () {
      final samples = [
        _sample(10, 70.9, hour: 8),
        _sample(10, 70.75, hour: 20),
        _sample(17, 70.2, hour: 8),
        _sample(17, 70, hour: 20),
      ];
      expect(change(samples), closeTo(-0.75, 1e-10));
      expect(change(samples.reversed.toList()), closeTo(-0.75, 1e-10));
    },
  );

  test('identical timestamp and value duplicates do not create extra days', () {
    expect(
      change([
        _sample(10, 70.75),
        _sample(10, 70.75),
        _sample(17, 70),
        _sample(17, 70),
      ]),
      closeTo(-0.75, 1e-10),
    );
  });

  test(
    'conflicting equal latest timestamps withhold rather than choose order',
    () {
      final samples = [_sample(10, 70.75), _sample(17, 70), _sample(17, 71)];
      expect(change(samples), isNull);
      expect(change(samples.reversed.toList()), isNull);
    },
  );

  test('many measurements in the same day are not a week', () {
    expect(
      change([_sample(17, 73, hour: 7), _sample(17, 70, hour: 20)]),
      isNull,
    );
  });

  test('calendar days do not require identical measurement times', () {
    expect(
      change([
        _sample(10, 70.75, hour: 23, minute: 59),
        _sample(17, 70, hour: 0, minute: 1),
      ]),
      closeTo(-0.75, 1e-10),
    );
  });

  test('unusable endpoint values cannot produce a numeric change', () {
    for (final invalid in [double.nan, double.infinity, 0.0, -1.0]) {
      expect(change([_sample(10, invalid), _sample(17, 70)]), isNull);
    }
  });
}
