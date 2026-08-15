import 'dart:io';

import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:body_intelligence_log/shared/widgets/premium_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PremiumSurface exposes three semantic hierarchy levels', (
    tester,
  ) async {
    for (final level in PremiumSurfaceLevel.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeData.lightTheme(Brightness.light),
          home: Scaffold(
            body: PremiumSurface(level: level, child: Text(level.name)),
          ),
        ),
      );

      final surface = tester.widget<PremiumSurface>(
        find.byType(PremiumSurface),
      );
      expect(surface.level, level);
    }
  });

  test('mobile decision is primary and body twin is detail', () {
    final benchmark =
        [
              'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
              'lib/features/dashboard/widgets/premium_dashboard_command_center.dart',
            ]
            .map((path) => File(path).readAsStringSync())
            .join('\n')
            .replaceAll('\r\n', '\n');
    final mobileTwin = File(
      'lib/features/dashboard/widgets/dashboard_mobile_body_twin_snapshot.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(
      benchmark,
      contains(
        "key: const Key('dashboard-mobile-command-center'),\n"
        '        level: PremiumSurfaceLevel.primary,',
      ),
    );
    expect(
      mobileTwin,
      contains(
        "key: const Key('dashboard-mobile-body-twin-snapshot'),\n"
        '      level: PremiumSurfaceLevel.detail,',
      ),
    );
  });
}
