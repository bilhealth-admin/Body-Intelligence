import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('body profile keeps existing values and adds honest engine metrics', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
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
      expect(source, contains(label), reason: 'Missing profile metric: $label');
    }

    expect(source, contains('bil.tdee.round()'));
    expect(source, contains('BodyCompositionEngine.calculate('));
    expect(source, contains('profile.neck'));
    expect(source, contains('profile.waist'));
    expect(source, contains('محيط الرقبة غير مسجل'));
    expect(source, contains('محيط الخصر غير مسجل'));
    expect(source, contains("'سعرة حرارية/يوم'"));
    expect(source, isNot(contains("'BMI'")));
    expect(source, isNot(contains("'TDEE'")));
  });
}
