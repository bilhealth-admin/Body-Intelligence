import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical theme owns compact world-class mobile geometry', () {
    final source = File('lib/app/theme/app_theme_data.dart').readAsStringSync();
    expect(source, contains('centerTitle: true'));
    expect(source, contains('minTileHeight: 54'));
    expect(source, contains('height: 68'));
    expect(source, contains('BottomSheetThemeData'));
    expect(source, contains('TabBarThemeData'));
  });

  test('all supplied references have a deterministic BIL mapping', () {
    final source = File(
      'tool/visual_reference_manifest.dart',
    ).readAsStringSync();
    for (final route in <String>[
      '/dashboard',
      '/daily-log',
      '/nutrition',
      '/analytics',
      '/weekly-report',
      '/profile-settings',
      '/wellness/recipes',
      '/wellness/workouts',
      '/community',
      '/connected-health',
      '/notification-settings',
      '/trust-support',
      '/plans',
    ]) {
      expect(
        source,
        contains(route),
        reason: 'missing visual mapping for $route',
      );
    }
    expect(source, contains('records.length != 177'));
  });
}
