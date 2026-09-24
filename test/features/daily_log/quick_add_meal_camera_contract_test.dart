import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quick Add photo captures before Food Log analysis', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final foodLog = File(
      'lib/features/daily_log/food_log_page.dart',
    ).readAsStringSync();

    expect(shell, contains('/quick-add/meal-camera?from='));
    expect(shell, isNot(contains('source=camera')));
    expect(router, contains("path: '/quick-add/meal-camera'"));
    expect(router, contains('QuickAddMealCameraPage'));
    final cameraPage = File(
      'lib/features/daily_log/quick_add_meal_camera_page.dart',
    ).readAsStringSync();
    expect(cameraPage, contains('extra: image'));
    expect(foodLog, contains("Key('food-log-meal-analysis-progress')"));
  });
}
