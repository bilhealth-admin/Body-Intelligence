import 'package:body_intelligence_log/features/history/progress_page.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary is derived only from recorded repository values', () {
    final stats = ProgressSeriesStats.fromChronologicalValues([
      1000,
      2500,
      1500,
    ])!;
    expect(stats.total, 5000);
    expect(stats.average, closeTo(1666.666, 0.01));
    expect(stats.best, 2500);
    expect(stats.start, 1000);
    expect(stats.current, 1500);
    expect(stats.change, 500);
  });

  test('empty is unavailable and a single record has zero change', () {
    expect(ProgressSeriesStats.fromChronologicalValues(const []), isNull);
    final stats = ProgressSeriesStats.fromChronologicalValues([72.4])!;
    expect(stats.average, 72.4);
    expect(stats.best, 72.4);
    expect(stats.total, 72.4);
    expect(stats.change, 0);
  });

  test('invalid, negative, or non-finite values fail closed', () {
    for (final values in <List<double>>[
      [-1],
      [double.nan],
      [double.infinity],
    ]) {
      expect(
        () => ProgressSeriesStats.fromChronologicalValues(values),
        throwsArgumentError,
      );
    }
    expect(progressValidMeasurementCm(null), isFalse);
    expect(progressValidMeasurementCm(0), isFalse);
    expect(progressValidMeasurementCm(-1), isFalse);
    expect(progressValidMeasurementCm(double.nan), isFalse);
    expect(progressValidMeasurementCm(double.infinity), isFalse);
    expect(progressValidMeasurementCm(87.2), isTrue);
  });

  test('all seven ranges have deterministic inclusive cutoffs', () {
    final now = DateTime.utc(2026, 8, 13, 12);
    expect(
      progressRangeCutoff(ProgressRange.week, now),
      DateTime.utc(2026, 8, 7),
    );
    expect(
      progressRangeCutoff(ProgressRange.month, now),
      DateTime.utc(2026, 7, 15),
    );
    expect(
      progressRangeCutoff(ProgressRange.twoMonths, now),
      DateTime.utc(2026, 6, 15),
    );
    expect(
      progressRangeCutoff(ProgressRange.threeMonths, now),
      DateTime.utc(2026, 5, 16),
    );
    expect(
      progressRangeCutoff(ProgressRange.sixMonths, now),
      DateTime.utc(2026, 2, 15),
    );
    expect(
      progressRangeCutoff(ProgressRange.year, now),
      DateTime.utc(2025, 8, 14),
    );
    expect(progressRangeCutoff(ProgressRange.all, now), isNull);
    expect(
      progressDateInRange(DateTime.utc(2026, 8, 7), ProgressRange.week, now),
      isTrue,
    );
    expect(
      progressDateInRange(
        DateTime.utc(2026, 8, 6, 23, 59),
        ProgressRange.week,
        now,
      ),
      isFalse,
    );
    expect(
      progressDateInRange(
        DateTime.utc(2026, 8, 13, 13),
        ProgressRange.all,
        now,
      ),
      isFalse,
      reason: 'future records never enter summaries or sharing',
    );
  });

  test('progress surface resolves directly in all 25 locales', () {
    const visibleKeys = <String>{
      'progress',
      'metric',
      'range',
      'selectMetric',
      'selectRange',
      'steps',
      'weight',
      'neck',
      'waist',
      'hips',
      'chest',
      'arm',
      'thigh',
      'week',
      'month',
      'twoMonths',
      'threeMonths',
      'sixMonths',
      'year',
      'all',
      'latest',
      'records',
      'noRecords',
      'unavailable',
      'addEditWeight',
      'editMeasurements',
      'shareProgress',
      'average',
      'best',
      'total',
      'start',
      'current',
      'change',
      'entries',
      'retry',
      'minimum',
      'maximum',
      'shareUnavailable',
    };
    for (final locale in RuntimeCopy.supported) {
      final copy = progressCopyForLocale(locale);
      for (final key in visibleKeys) {
        expect(copy[key], isNotNull, reason: '$locale/$key');
        expect(copy[key]!.trim(), isNotEmpty, reason: '$locale/$key');
        if (ExtendedRuntimeCopy.supported.contains(locale)) {
          final english = progressCopyForLocale('en')[key]!;
          expect(
            ExtendedRuntimeCopy.values[english]?.containsKey(locale),
            isTrue,
            reason: 'direct catalog entry $locale/$english',
          );
        }
      }
    }
  });
}
