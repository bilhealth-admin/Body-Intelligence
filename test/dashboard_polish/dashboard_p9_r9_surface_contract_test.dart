import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9-R9 paired decks share geometry and nutrition-card surface', () {
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
    ).readAsStringSync();
    final personal = File(
      'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final carousel = File(
      'lib/features/dashboard/widgets/dashboard_carousel.dart',
    ).readAsStringSync();

    expect(personal, contains('DashboardTwinDeckShell('));
    expect(benchmark, contains('DashboardTwinDeckShell('));
    expect(benchmark, isNot(contains('class _KeyInsightsDeck')));

    expect(shell, contains("Key('dashboard-twin-header-slot')"));
    expect(
      shell,
      contains('final headerBaseHeight = widget.compact ? 68.0 : 72.0'),
    );
    expect(shell, contains('height: headerHeight'));
    expect(shell, contains('final pagerReserve ='));
    expect(shell, contains('final pagerReserve = widget.pages.length > 1'));
    expect(shell, contains('.scale(26.0).clamp(26.0, 48.0)'));
    expect(shell, contains("Key('dashboard-twin-deck-carousel')"));
    expect(shell, contains('viewportFraction: widget.compact ? .94 : .96'));
    expect(shell, contains('Expanded('));
    expect(shell, contains('LayoutBuilder('));

    expect(carousel, contains("Key('dashboard-carousel-card-frame')"));
    expect(carousel, contains('widthFactor: widget.viewportFraction'));

    expect(benchmark, contains('dashboardGlass: true'));
    expect(personal, contains('DashboardTwinDeckShell('));
    expect(personal, isNot(contains('Colors.black.withValues(alpha: .14)')));
  });
}
