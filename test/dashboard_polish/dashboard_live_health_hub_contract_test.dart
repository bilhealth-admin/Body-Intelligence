import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9-R9 live Health Hub and paired deck contracts are present', () {
    final watch = File(
      'lib/features/connected_health/widgets/live_health_watch.dart',
    ).readAsStringSync();
    final emptyState = File(
      'lib/features/connected_health/widgets/health_hub_empty_state.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final mobileTwin = File(
      'lib/features/dashboard/widgets/dashboard_mobile_body_twin_snapshot.dart',
    ).readAsStringSync();

    expect(emptyState, contains("Key('health-hub-fixed-square-watch')"));
    expect(emptyState, contains('SizedBox.square'));
    expect(watch, contains("Key('bil-live-health-watch')"));
    expect(watch, contains('Timer.periodic(const Duration(seconds: 1)'));
    expect(watch, contains('StackFit.expand'));
    expect(watch, isNot(contains('bil_wordmark.dart')));
    expect(watch, isNot(contains('BilWordmark(')));
    final painter = watch.substring(watch.indexOf('class _WatchPainter'));
    for (final brightEdge in const [
      'Color(0xFFFFFFFF)',
      'Color(0xFFF4F6F7)',
      'Color(0xFFF7F8F8)',
      'Color(0xFFD9DEE1)',
    ]) {
      expect(painter, isNot(contains(brightEdge)), reason: brightEdge);
    }
    expect(painter, contains('final shell = RRect.fromRectAndRadius('));
    expect(painter, contains('Color(0xFF07131B)'));
    expect(painter, contains('Color(0xFF163442)'));
    expect(emptyState, contains("Text(tr('Connect now', 'ربط الآن'))"));

    expect(shell, contains("Key('dashboard-twin-header-slot')"));
    expect(shell, contains("Key('dashboard-twin-deck-carousel')"));
    expect(shell, contains('viewportFraction: widget.compact ? .94 : .96'));

    expect(grid, isNot(contains('DashboardAnalyticsCenter(')));
    expect(grid, contains("context.go('/analytics')"));
    expect(grid, contains('bodyTwinSummary: twinCopy.summary'));
    expect(mobileTwin, contains("Key('dashboard-mobile-body-twin-snapshot')"));
    expect(
      shell,
      contains('final headerBaseHeight = widget.compact ? 68.0 : 72.0'),
    );
  });
}
