import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quick add keeps the approved seven actions without diary duplicates',
    () {
      final shell = File(
        'lib/app/router/responsive_app_shell.dart',
      ).readAsStringSync();
      final sheet = File(
        'lib/app/router/bil_quick_add_sheet.dart',
      ).readAsStringSync();
      final diary = [
        'lib/features/daily_log/daily_log_page.dart',
        'lib/features/daily_log/daily_log_navigation_actions.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      for (final action in const ['barcode', 'voice', 'photo']) {
        expect(shell, contains('action=$action'));
        expect(diary, contains("case '$action':"));
      }

      expect(shell, contains("context.go('/daily-log?focus=meal&from="));
      expect(shell, contains('/daily-log/body-context?from='));
      expect(diary, contains("case 'notes':"));
      expect(shell, contains("context.push('/wellness/workouts')"));
      expect(shell, contains("context.go('/nutrition')"));

      for (final callback in const [
        'onFood',
        'onBarcode',
        'onVoice',
        'onPhoto',
        'onExercise',
        'onNotes',
        'onSearch',
      ]) {
        expect(sheet, contains('required this.$callback'));
        expect(shell, contains('$callback: ()'));
      }

      // Water, weight and check-in stay on their diary surfaces. Repeating them
      // in this global sheet recreates the reported clutter.
      for (final duplicate in const [
        'onWater',
        'onWeight',
        'onCheckIn',
        'onQuickMacros',
      ]) {
        expect(sheet, isNot(contains(duplicate)));
      }
      expect(shell, isNot(contains("context.go('/daily-log/water?from=")));
      expect(shell, isNot(contains("context.push('/daily-check-in')")));
      expect(sheet, isNot(contains('Ã')));
    },
  );
}
