import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_library_source.dart';

void main() {
  test('P9-R15 consolidated approved dashboard contracts are present', () {
    final root = Directory.current.path;
    String read(String relative) =>
        File('$root${Platform.pathSeparator}$relative').readAsStringSync();

    final health = <String>[
      'lib/features/connected_health/widgets/connected_health_card.dart',
      'lib/features/connected_health/widgets/health_hub_empty_state.dart',
      'lib/features/connected_health/widgets/live_health_watch.dart',
    ].map(read).join('\n');
    final grid = read('lib/features/dashboard/widgets/dashboard_grid.dart');
    final analytics = <String>[
      'lib/features/analytics/analytics_page.dart',
      'lib/features/analytics/widgets/analytics_weight_trend_chart.dart',
    ].map(read).join('\n');
    final analyticsCenter = read(
      'lib/features/dashboard/widgets/dashboard_analytics_center.dart',
    );
    final profile = read(
      'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
    );
    final header = readDartLibrarySource(
      'lib/features/dashboard/widgets/dashboard_header.dart',
    );

    expect(health, contains("Key('health-hub-device-carousel')"));
    expect(health, contains('viewportFraction: .88'));
    expect(health, contains('Color(0xFF2D3439)'));
    expect(health, contains('crownCenter'));

    expect(grid, isNot(contains("'kcal/day'")));
    expect(grid, contains("? 'BMI' : ''"));
    expect(grid, contains('weightUnit: UnitConverter.weightUnit(system)'));
    expect(analyticsCenter, contains('textDirection: TextDirection.ltr'));
    expect(profile, contains('mainAxisAlignment: MainAxisAlignment.center'));
    expect(profile, contains('textAlign: TextAlign.center'));

    expect(analytics, contains("analyticsText(context, 'Start', 'البداية')"));
    expect(analytics, contains("analyticsText(context, 'Current', 'الحالي')"));
    expect(analytics, contains("analyticsText(context, 'Change', 'التغيّر')"));
    expect(
      analytics,
      contains('for (var index = 0; index < values.length; index++)'),
    );
    expect(
      analytics,
      contains('for (var index = 1; index < points.length; index++)'),
    );

    expect(header, contains('Color(0xFFCEE2E8)'));
    expect(header, contains('Color(0xFFD8E9ED)'));
    expect(header, contains('Color(0xFFEFF3F5)'));
    expect(header, contains('Color(0xFF53616A)'));
  });
}
