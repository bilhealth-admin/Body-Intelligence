import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard typography hierarchy is explicit and presentation-only', () {
    final files = <String>[
      'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      'lib/features/dashboard/widgets/daily_return_card.dart',
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ];
    final source = files
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    expect(source, contains('fontWeight: FontWeight.w800'));
    expect(source, contains('letterSpacing: -0.15'));
    expect(source, contains('height: 1.12'));
    expect(source, contains('height: 1.45'));
    expect(source, isNot(contains('Repository(')));
    expect(source, isNot(contains('ProviderScope(')));
  });
}
