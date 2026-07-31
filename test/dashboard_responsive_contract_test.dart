import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composition and shell share one responsive source of truth', () {
    final composition = File(
      'lib/features/dashboard/widgets/dashboard_composition.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_shell.dart',
    ).readAsStringSync();

    expect(composition, contains("import 'dashboard_layout_metrics.dart';"));
    expect(shell, contains("import 'dashboard_layout_metrics.dart';"));

    final resolverPattern = RegExp(
      r'DashboardLayoutMetrics\.resolve\(\s*constraints\.maxWidth\s*,?\s*\)',
      multiLine: true,
    );

    expect(resolverPattern.hasMatch(composition), isTrue);
    expect(resolverPattern.hasMatch(shell), isTrue);
  });

  test('legacy premature breakpoint and fixed max width are removed', () {
    final composition = File(
      'lib/features/dashboard/widgets/dashboard_composition.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_shell.dart',
    ).readAsStringSync();

    expect(composition, isNot(contains('wideBreakpoint = 1180')));
    expect(shell, isNot(contains('maxWidth: 1380')));
  });
}
