import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard exposes explicit priority hierarchy', () {
    final page = File(
      'lib/features/dashboard/dashboard_page.dart',
    ).readAsStringSync();
    final composition = File(
      'lib/features/dashboard/widgets/dashboard_composition.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_shell.dart',
    ).readAsStringSync();

    expect(page, contains('DashboardShell('));
    expect(page, contains('DashboardComposition('));
    expect(page, contains('hero: hero'));
    expect(page, contains('content: const DashboardGrid('));
    expect(composition, contains("Key('dashboard-composition-wide')"));
    expect(composition, contains("Key('dashboard-composition-stacked')"));
    expect(shell, contains("Key('dashboard-scroll-view')"));
  });
}
