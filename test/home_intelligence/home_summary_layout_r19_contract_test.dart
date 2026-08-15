@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary tiles are larger with smaller text', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();

    expect(summary, contains('childAspectRatio: phone ? .94'));
    expect(summary, contains('minHeight: compact ? 150'));
    expect(summary, contains('fontSize: phone ? 9 : null'));
    expect(summary, contains('fontSize: phone ? 10 : 13'));
    expect(summary, contains('fontSize: phone ? 8.5 : 11'));
    expect(summary, contains('Icon(icon, size: compact ? 13 : 18'));
  });

  test('lower summary row sits below the inner arrows', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();

    expect(summary, contains('mainAxisSpacing: phone ? 18'));
    expect(summary, contains('viewportFraction: .94'));
    expect(summary, contains("Key('dashboard-summary-inner-carousel')"));
  });
}
