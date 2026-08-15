import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress uses real repositories and all requested selectors', () {
    final source = File(
      'lib/features/history/progress_page.dart',
    ).readAsStringSync();
    for (final metric in [
      'steps',
      'weight',
      'neck',
      'waist',
      'hips',
      'chest',
      'arm',
      'thigh',
    ]) {
      expect(source, contains('ProgressMetric.$metric'), reason: metric);
    }
    for (final range in [
      'week',
      'month',
      'twoMonths',
      'threeMonths',
      'sixMonths',
      'year',
      'all',
    ]) {
      expect(source, contains('ProgressRange.$range'), reason: range);
    }
    expect(source, contains('dailyLogRepositoryProvider'));
    expect(source, contains('weightHistoryProvider'));
    expect(source, contains('bodyMeasurementHistoryProvider'));
    for (final field in const [
      'row.neckCm',
      'row.waistCm',
      'row.hipsCm',
      'row.chestCm',
      'row.armCm',
      'row.thighCm',
    ]) {
      expect(source, contains(field));
    }
  });

  test('current progress route preserves real weight management', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(router, contains("path: '/history'"));
    expect(router, contains('const ProgressPage()'));
    expect(router, contains("path: '/weight-history'"));
    expect(router, contains('const HistoryPage()'));
  });
}
