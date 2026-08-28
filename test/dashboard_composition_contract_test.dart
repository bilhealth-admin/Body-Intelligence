import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'DashboardPage delegates environment and composition responsibilities',
    () {
      final source = File(
        'lib/features/dashboard/dashboard_page.dart',
      ).readAsStringSync();

      expect(source, contains('DashboardShell('));
      expect(source, contains('DashboardComposition('));
      expect(source, isNot(contains('Stack(')));
      expect(source, isNot(contains('LayoutBuilder(')));
      expect(source, isNot(contains('SingleChildScrollView(')));
      expect(source, isNot(contains('class _DashboardTopBar')));
      expect(source, isNot(contains('class FirstValueHandoffCard')));
    },
  );

  test('weight and steps use real three-zone crystalline Cartesian bars', () {
    final source = File(
      'lib/features/dashboard/widgets/'
      'dashboard_reference_phone_components.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(source, contains('final slotWidth = size.width / values.length'));
    expect(source, contains('canvas.drawRRect'));
    expect(source, contains('LinearGradient('));
    expect(source, contains('AppColors.protein'));
    expect(source, contains('AppColors.carbs'));
    expect(source, contains('AppColors.fats'));
    expect(source, contains('((index * 3) ~/ values.length).clamp(0, 2)'));
    expect(source, isNot(contains('canvas.drawPath(')));
    expect(grid, contains('weightTrendValues: weights'));
    expect(grid, contains('stepTrendValues: dailyLogs'));
  });
}
