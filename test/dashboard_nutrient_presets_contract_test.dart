import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard nutrient presets use the MyFitnessPal reference nutrients',
    () {
      final source = File(
        'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
      ).readAsStringSync();

      expect(source, contains("tr('Heart Healthy'"));
      expect(source, contains("tr('Saturated fat'"));
      expect(source, contains("tr('Sodium'"));
      expect(source, contains("tr('Fiber'"));
      expect(source, contains("tr('Carb Conscious'"));
      expect(source, contains("tr('Sugar'"));
      expect(source, contains("tr('Fiber'"));
      expect(source, contains('/analytics/nutrition?tab=nutrients'));
    },
  );

  test('saved diary nutrient dashboard choice is consumed by Today', () {
    final provider = File(
      'lib/features/dashboard/providers/dashboard_preferences_provider.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(provider, contains("watch('diary.nutrientDashboard')"));
    expect(grid, contains('dashboardNutrientDashboardProvider'));
    expect(grid, contains('nutrientDashboardPreset:'));
  });
}
