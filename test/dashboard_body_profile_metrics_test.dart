import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('body profile keeps existing values and adds honest engine metrics', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
    ).readAsStringSync();
    final composer = File(
      'lib/features/dashboard/domain/dashboard_intelligence_composer.dart',
    ).readAsStringSync();

    for (final label in [
      'الوزن الحالي',
      'الوزن المستهدف',
      'الطول',
      'هدف البروتين',
      'هدف الماء',
      'خطة الطاقة اليومية',
      'معدل الأيض اليومي',
      'مؤشر كتلة الجسم',
      'نسبة دهون الجسم',
      'الكتلة الخالية من الدهون',
    ]) {
      expect(
        profile,
        contains(label),
        reason: 'Missing profile metric: $label',
      );
    }

    expect(grid, contains('bil.tdee.round()'));
    expect(composer, contains('BodyCompositionEngine.calculate('));
    expect(grid, contains('profile.neck'));
    expect(grid, contains('profile.waist'));
    expect(grid, contains('محيط الرقبة غير مسجل'));
    expect(grid, contains('محيط الخصر غير مسجل'));
    expect(profile, isNot(contains('BodyCompositionEngine.calculate(')));
    expect(profile, isNot(contains('DashboardIntelligenceComposer')));
  });
}
