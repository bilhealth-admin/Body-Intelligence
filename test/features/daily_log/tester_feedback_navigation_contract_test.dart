import 'dart:io';

import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:flutter_test/flutter_test.dart';

String _librarySource(String path) {
  final library = File(path);
  final entrypoint = library.readAsStringSync();
  final parts = RegExp(r"part '([^']+)';")
      .allMatches(entrypoint)
      .map((match) => File('${library.parent.path}/${match.group(1)!}'));
  return <String>[
    entrypoint,
    for (final part in parts) part.readAsStringSync(),
  ].join('\n');
}

void main() {
  test('diary permits future planning and keeps both date directions', () {
    final source = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();

    expect(source, contains('today.year + 1'));
    expect(source, contains('date.subtract('));
    expect(source, contains('date.add('));
    expect(source, contains('lastDate: latestPlannableDate'));

    final mutations = File(
      'lib/features/daily_log/daily_log_mutation_actions.dart',
    ).readAsStringSync();
    expect(mutations, contains('committedDate: committedDate'));
    expect(mutations, contains('dailyLogShouldExportNutritionSample('));

    final today = DateTime(2026, 8, 30, 9);
    expect(
      dailyLogShouldExportNutritionSample(
        selectedDate: today.subtract(const Duration(days: 1)),
        now: today,
      ),
      isTrue,
    );
    expect(
      dailyLogShouldExportNutritionSample(selectedDate: today, now: today),
      isTrue,
    );
    expect(
      dailyLogShouldExportNutritionSample(
        selectedDate: today.add(const Duration(days: 1)),
        now: today,
      ),
      isFalse,
      reason:
          'A planned future meal must not be exported as consumed health data.',
    );
  });

  test('Today summary uses the real calorie target and raised ring layout', () {
    final source = File(
      'lib/features/daily_log/presentation/daily_log_summary_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('calorieGoal: calorieGoal'));
    expect(source, contains("Key('daily-log-summary-ring-raised')"));
    expect(source, contains('offset: const Offset(0, -3)'));
  });

  test(
    'meal logging opens a focused meal page without duplicate capture UI',
    () {
      final page = File(
        'lib/features/daily_log/daily_log_page.dart',
      ).readAsStringSync();
      final entry = File(
        'lib/features/daily_log/daily_log_meal_entry.dart',
      ).readAsStringSync();

      expect(page, contains("Key('daily-log-focused-meal-page')"));
      expect(page, contains("Key('daily-meal-detail-title')"));
      expect(entry, contains('SearchAnchor('));
      expect(entry, isNot(contains("Key('daily-search-barcode')")));
      expect(entry, isNot(contains("Key('daily-search-voice')")));
      expect(entry, isNot(contains("Key('daily-search-meal-selector')")));
    },
  );

  test('dashboard Android back exits instead of revealing auth history', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('canPop: !isDashboard'));
    expect(shell, contains('defaultTargetPlatform == TargetPlatform.android'));
    expect(shell, contains('SystemNavigator.pop()'));
  });

  test('weight context uses one selected icon and local condition labels', () {
    final checkIn = File(
      'lib/features/daily_check_in/daily_check_in_page.dart',
    ).readAsStringSync();

    expect(
      checkIn,
      contains("('morning', 'Morning', Icons.wb_sunny_outlined)"),
    );
    expect(checkIn, contains("'After eating',"));
    expect(checkIn, contains('Icons.restaurant_outlined'));
    expect(checkIn, contains("'Different time',"));
    expect(checkIn, contains('Icons.schedule_rounded'));
    expect(checkIn, contains('showCheckmark: false'));
  });

  test('workout library exposes verified inventory and programs together', () {
    final source = File(
      'lib/features/wellness/presentation/bil_workout_routines_library.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'wellnessVerifiedWorkoutVideoCount\s*\(\s*context\s*,\s*verifiedVideoCount\s*,?\s*\)',
      ).allMatches(source),
      hasLength(1),
    );
    expect(
      RegExp(
        r'''["'][^"'\r\n]*\$(?:\{[A-Za-z_]\w*\}|[A-Za-z_]\w*)[^"'\r\n]*\bvideos?\b[^"'\r\n]*["']|["'][^"'\r\n]*\bvideos?\b[^"'\r\n]*\$(?:\{[A-Za-z_]\w*\}|[A-Za-z_]\w*)[^"'\r\n]*["']''',
        caseSensitive: false,
      ).allMatches(source),
      isEmpty,
    );
    expect(source, contains("'Verified workout video library'"));
    expect(source, isNot(contains("'300+ home workout videos'")));
    expect(source, contains("ValueKey('workout-programs-inline-action')"));
    expect(source, contains("context.push('/wellness/workouts/log')"));
  });

  test(
    'dashboard keeps Premium copy at the route gate instead of every tile',
    () {
      final benchmark = _librarySource(
        'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      );
      final sections = File(
        'lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'PremiumLabelBadge\(').allMatches(benchmark),
        hasLength(1),
      );
      expect(benchmark, contains("Key('dashboard-premium-page-label')"));
      expect(sections, isNot(contains('PremiumLabelBadge')));
      expect(sections, isNot(contains('Icons.lock')));
      expect(sections, isNot(contains('Icons.lock_outline')));
    },
  );

  test(
    'dashboard fitness widget keeps live readings inside the watch and link below',
    () {
      final source = File(
        'lib/features/connected_health/widgets/connected_health_card.dart',
      ).readAsStringSync();

      expect(source, contains("Key('dashboard-live-fitness-watch-slot')"));
      expect(source, contains('LiveHealthWatch('));
      expect(source, contains('showMetrics: true'));
      expect(source, contains('onStepsTap:'));
      expect(source, contains('onHeartTap:'));
      expect(source, contains("Key('dashboard-fitness-link-action')"));
      final watch = source.indexOf("Key('dashboard-live-fitness-watch-slot')");
      final link = source.lastIndexOf("Key('dashboard-fitness-link-action')");
      expect(link, greaterThan(watch));
    },
  );

  test('shipping BLE and Android permissions remain fitness-only', () {
    final androidBridge = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFitnessBleBridge.kt',
    ).readAsStringSync();
    final iosBridge = File(
      'ios/Runner/BILFitnessBleBridge.swift',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    for (final bridge in [androidBridge, iosBridge]) {
      expect(bridge, contains('181D'));
      expect(bridge, contains('181B'));
      expect(bridge, contains('180D'));
      expect(bridge, contains('2A9D'));
      expect(bridge, contains('2A9C'));
      expect(bridge, contains('2A37'));
      for (final clinicalGatt in ['1810', '1808', '1822', '1809']) {
        expect(bridge, isNot(contains('"$clinicalGatt"')));
      }
      for (final clinicalCharacteristic in ['2A35', '2A18', '2A5F', '2A6E']) {
        expect(bridge, isNot(contains('"$clinicalCharacteristic"')));
      }
    }
    for (final permission in [
      'READ_BLOOD_PRESSURE',
      'READ_BLOOD_GLUCOSE',
      'READ_OXYGEN_SATURATION',
      'READ_BODY_TEMPERATURE',
    ]) {
      expect(manifest, isNot(contains(permission)));
    }
  });
}
