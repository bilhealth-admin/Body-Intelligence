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

      expect(
        shell,
        contains('final action = await showBilModalBottomSheet<String>('),
      );
      expect(
        shell,
        contains('if (!context.mounted || action == null) return;'),
      );
      expect(shell, contains('switch (action)'));

      for (final action in const ['barcode', 'voice']) {
        expect(shell, contains('action=$action'));
        expect(diary, contains("case '$action':"));
      }
      // Photo Quick Add opens the meal-vision camera directly. It must never
      // route through the AI Coach conversation.
      expect(
        shell,
        contains(
          "'/daily-log?foodLog=1&action=photo&source=camera&from=\$origin'",
        ),
      );
      expect(shell, isNot(contains('vision=capture&from=\$origin')));
      expect(diary, contains("case 'photo':"));

      // Log food is pushed after dismissing Quick Add so the shell does not
      // briefly rebuild with a blank child while the standalone page mounts.
      expect(shell, contains("context.push('/daily-log?foodLog=1&from="));
      // Quick Add's Log food action is a standalone surface. It exposes the
      // meal selector there while leaving the legacy Daily Log pages intact.
      expect(shell, isNot(contains("focus=meal&meal=dinner")));
      final router = File('lib/app/router/app_router.dart').readAsStringSync();
      expect(
        router,
        contains(
          "final foodLogMode = state.uri.queryParameters['foodLog'] == '1';",
        ),
      );
      expect(router, contains('return FoodLogPage('));
      expect(
        router,
        contains('initialAction: state.uri.queryParameters[\'action\']'),
      );
      expect(
        router,
        contains("state.uri.queryParameters['source'] == 'camera'"),
      );
      expect(
        File('lib/features/daily_log/daily_log_page.dart').readAsStringSync(),
        contains("String mealType = 'breakfast';"),
      );
      expect(shell, contains('/daily-log/body-context?from='));
      expect(diary, contains("case 'notes':"));
      expect(shell, contains("context.push('/wellness/workouts')"));
      expect(
        shell,
        contains("if (currentPath != '/nutrition') context.push('/nutrition')"),
      );

      for (final entry in const [
        ('onFood', 'food'),
        ('onBarcode', 'barcode'),
        ('onVoice', 'voice'),
        ('onPhoto', 'photo'),
        ('onExercise', 'exercise'),
        ('onNotes', 'notes'),
        ('onSearch', 'search'),
      ]) {
        final (callback, action) = entry;
        expect(sheet, contains('required this.$callback'));
        expect(shell, contains('$callback: ()'));
        expect(shell, contains("Navigator.of(sheetContext).pop('$action')"));
        expect(shell, contains("case '$action':"));
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
