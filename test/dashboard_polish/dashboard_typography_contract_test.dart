import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard typography hierarchy is explicit and presentation-only', () {
    final files = <String>[
      'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      'lib/features/dashboard/widgets/daily_return_card.dart',
      'lib/features/dashboard/widgets/dashboard_grid.dart',
      'lib/features/dashboard/widgets/dashboard_section_heading.dart',
    ];
    final source = files
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    expect(source, isNot(contains('FontWeight.w800')));
    expect(source, isNot(contains('FontWeight.w900')));
    expect(source, contains('FontWeight.w700'));
    expect(source, contains('letterSpacing: -0.15'));
    expect(source, contains('height: 1.12'));
    expect(source, contains('height: 1.45'));
    expect(source, isNot(contains('Repository(')));
    expect(source, isNot(contains('ProviderScope(')));
  });

  test('flagship theme keeps the approved mobile typography and geometry', () {
    final source = File(
      'lib/app/theme/bil_flagship_theme.dart',
    ).readAsStringSync();
    final tokens = File(
      'lib/app/theme/bil_flagship_tokens.dart',
    ).readAsStringSync();

    expect(source, contains('centerTitle: true'));
    expect(source, isNot(contains('FontWeight.w300')));
    expect(source, isNot(contains('FontWeight.w500')));
    expect(source, isNot(contains('FontWeight.w800')));
    expect(source, isNot(contains('FontWeight.w900')));
    expect(tokens, contains('static const double radiusMd = 14'));
    expect(
      tokens,
      contains('static const Color canvasLight = Color(0xFFF5F5F8)'),
    );
  });
}
