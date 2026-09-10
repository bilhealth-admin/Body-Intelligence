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
    final watch = readDartLibrarySource(
      'lib/features/connected_health/widgets/live_health_watch.dart',
    );
    final dashboard = readDartLibrarySource(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    );
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
    // The approved watch is a dark fitness surface. Keep its exact dark shell
    // palette and crown while preventing the retired white metallic frame and
    // in-watch BIL logo from returning.
    expect(watch, contains("Key('bil-live-health-watch')"));
    expect(watch, contains('final shell = RRect.fromRectAndRadius('));
    expect(watch, contains('Color(0xFF07131B)'));
    expect(watch, contains('Color(0xFF163442)'));
    expect(watch, contains('Color(0xFF0B202C)'));
    expect(watch, contains('Color(0xFF050D13)'));
    expect(watch, contains('stops: [0, .33, .68, 1]'));
    expect(watch, contains('crownCenter'));
    expect(watch, isNot(contains('Color(0xFF2D3439)')));
    expect(watch, isNot(contains('Color(0xFFF4F6F7)')));
    expect(watch, isNot(contains('Color(0xFFFFFFFF)')));
    expect(watch, isNot(contains('Color(0xFFF7F8F8)')));
    expect(watch, isNot(contains('BilWordmark')));
    expect(watch, isNot(contains("bil_wordmark.dart")));

    expect(dashboard, isNot(contains("'kcal/day'")));
    // The approved public dashboard keeps weight trends unit-aware but omits
    // the retired BMR, TDEE, BMI, body-fat, and fat-free-mass presentation.
    expect(dashboard, isNot(contains("? 'BMI' : ''")));
    expect(dashboard, isNot(contains('DashboardBodyProfileSnapshot(')));
    expect(dashboard, isNot(contains('bodyFatUnit:')));
    expect(dashboard, isNot(contains('fatFreeMass:')));
    expect(dashboard, isNot(contains('dailyMetabolism:')));
    expect(dashboard, contains('weightUnit: UnitConverter.weightUnit(system)'));
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
