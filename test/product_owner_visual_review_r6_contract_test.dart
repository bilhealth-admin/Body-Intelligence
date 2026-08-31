import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily summary uses larger phone tiles', () {
    final composition = File(
      'lib/features/dashboard/composition/dashboard_composition.dart',
    ).readAsStringSync();
    final summary = [
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
      'lib/features/dashboard/widgets/dashboard_metric_grid.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(composition, contains('contentWidth < 420 ? 0.82 : 1.08'));
    expect(composition, contains(': 470'));
    expect(summary, contains('minHeight: compact ? 150 : (phone ? 176 : 172)'));
    expect(summary, contains('phone ? .94 : layout.metricChildAspectRatio'));
    expect(summary, contains('maxLines: 2'));
  });

  test('mobile shell has adaptive glass without artificial black spacer', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(shell, isNot(contains('EdgeInsets.only(bottom: 82)')));
    expect(shell, contains('Theme.of(context).scaffoldBackgroundColor'));
    expect(shell, contains('Brightness.dark'));
    expect(shell, contains('Color(0xF20B1725)'));
    expect(shell, contains('Color(0xF7FFFFFF)'));
    expect(shell, contains('BackdropFilter('));
  });

  test('dashboard dynamic evidence is localized', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(grid, contains('localizedList(honesty.missing)'));
    expect(grid, contains('localizedList(changed.evidence)'));
    expect(grid, contains('weightUnit: UnitConverter.weightUnit(system)'));
  });
}
