@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('three primary pages use one exact Bio Intelligence shell', () {
    final primary = File(
      'lib/features/dashboard/widgets/dashboard_primary_carousel.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
    ).readAsStringSync();
    final carousel = File(
      'lib/features/dashboard/widgets/dashboard_carousel.dart',
    ).readAsStringSync();

    expect(primary, contains('child: DashboardTwinDeckShell('));
    expect(primary, contains('twinBaseHeight(width)'));
    expect(primary, contains('maximumTwinHeight'));
    expect(primary, isNot(contains('DashboardCarousel(')));
    expect(primary, isNot(contains('compact: true')));

    expect(shell, contains('final List<String>? pageTitles'));
    expect(shell, contains('final List<String?>? pageSubtitles'));
    expect(shell, contains("key: const Key('dashboard-twin-deck-carousel')"));
    expect(shell, contains('viewportFraction: widget.compact ? .94 : .96'));
    expect(shell, contains('compactControls: widget.compact'));

    expect(carousel, contains('final ValueChanged<int>? onPageChanged'));
    expect(carousel, contains('widget.onPageChanged?.call'));
  });
}
