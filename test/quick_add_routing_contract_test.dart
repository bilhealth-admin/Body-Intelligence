import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick add exposes every approved R2 entry point', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/app/router/bil_quick_add_sheet.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final diary = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();

    for (final action in const ['barcode', 'voice', 'photo', 'water']) {
      expect(shell, contains('action=$action'));
      expect(diary, contains("case '$action':"));
    }

    expect(shell, contains("/daily-log/body-context?from="));
    expect(router, contains("path: '/daily-log/body-context'"));
    expect(diary, contains("case 'notes':"));

    expect(shell, contains("context.push('/daily-check-in')"));
    expect(shell, contains("context.push('/wellness/workouts')"));
    expect(router, contains("path: '/wellness/workouts'"));
    expect(router, contains("path: '/wellness/workouts/routines'"));
    expect(router, contains("initialCategory:"));
    expect(router, contains("queryParameters['category']"));
    expect(shell, contains('focus=meal'));
    expect(router, contains("queryParameters['action']"));
    expect(sheet, contains('تسجيل الطعام بالصوت'));
    expect(sheet, contains('تحليل صورة وجبة'));
    expect(sheet, isNot(contains('Ø')));
  });
}
