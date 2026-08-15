@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary numbers are small and only slightly larger than units', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();

    expect(summary, contains('fontSize: phone ? 11 : 13'));
    expect(summary, contains('fontSize: phone ? 9.5 : 11'));
    expect(summary, contains('fontWeight: FontWeight.w900'));
    expect(summary, contains('fontWeight: FontWeight.w700'));

    expect(summary, isNot(contains('textTheme.titleLarge')));
    expect(summary, isNot(contains('textTheme.headlineSmall')));
  });

  test('R16 card geometry remains unchanged', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();

    expect(summary, contains('childAspectRatio: phone ? 1.02'));
    expect(summary, contains('compact ? 142'));
    expect(summary, contains('viewportFraction: .94'));
    expect(summary, contains("Key('dashboard-summary-inner-carousel')"));
  });
}
