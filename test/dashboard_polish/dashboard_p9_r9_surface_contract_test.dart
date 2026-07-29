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
    expect(shell, contains('height: compact ? 68 : 72'));
    expect(shell, contains('final pagerReserve ='));
    expect(shell, contains('? 26.0 : 0.0'));
    expect(shell, contains("Key('dashboard-twin-deck-carousel')"));
    expect(shell, contains('viewportFraction: compact ? .94 : .96'));
    expect(shell, contains('Expanded('));
    expect(shell, contains('LayoutBuilder('));

    expect(carousel, contains("Key('dashboard-carousel-card-frame')"));
    expect(carousel, contains('widthFactor: widget.viewportFraction'));

    const nutritionGradient = 'const Color(0xFF5BDAFF).withValues(alpha: .045)';
    const nutritionBorder =
        'border: Border.all(color: Colors.white.withValues(alpha: .14))';
    const nutritionShadow = 'const Color(0xFF174E8C).withValues(alpha: .08)';

    expect(
      benchmark.split(nutritionGradient).length - 1,
      greaterThanOrEqualTo(2),
    );
    expect(
      benchmark.split(nutritionBorder).length - 1,
      greaterThanOrEqualTo(2),
    );
    expect(
      benchmark.split(nutritionShadow).length - 1,
      greaterThanOrEqualTo(2),
    );

    expect(personal, contains(nutritionGradient));
    expect(personal, contains(nutritionBorder));
    expect(personal, contains(nutritionShadow));
    expect(personal, isNot(contains('Colors.black.withValues(alpha: .14)')));
  });
}
