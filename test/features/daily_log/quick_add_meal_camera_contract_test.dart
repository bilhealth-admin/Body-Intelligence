import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Quick Add photo selects source on current tab, then mounts Food Log',
    () {
      final shell = File(
        'lib/app/router/responsive_app_shell.dart',
      ).readAsStringSync();
      final presenter = File(
        'lib/app/router/bil_quick_add_presenter.dart',
      ).readAsStringSync();
      final photo = File(
        'lib/app/router/bil_quick_add_photo_flow.dart',
      ).readAsStringSync();
      final foodPage = File(
        'lib/features/daily_log/food_log_page.dart',
      ).readAsStringSync();
      final foodActions = File(
        'lib/features/daily_log/food_log_actions.dart',
      ).readAsStringSync();

      expect(shell, contains('await showBilQuickAdd('));
      expect(presenter, contains('await openBilQuickAddMealPhoto('));
      expect(
        presenter,
        isNot(contains("context.push('/quick-add/meal-camera")),
      );
      expect(photo, contains('showBilModalBottomSheet<ImageSource>'));
      expect(
        photo,
        contains('key: const Key(\'quick-add-meal-photo-source-sheet\')'),
      );
      expect(photo, contains('ImageSource.camera'));
      expect(photo, contains('ImageSource.gallery'));
      expect(photo, contains('showBilMediaReviewSheet<XFile>'));
      expect(photo, contains('ensureMealVisionConsent(context)'));
      expect(photo, contains('aiBoostVisionAccessProvider.future'));
      expect(photo, contains("context.push("));
      expect(photo, contains('extra: image'));
      expect(foodPage, contains('bool mealPhotoRequestInFlight = false'));
      expect(foodActions, contains('if (mealPhotoRequestInFlight) return;'));
      expect(foodActions, contains('if (image == null || !mounted) return;'));
      expect(
        foodActions,
        contains('_updateState(() => mealImageBusy = true);'),
      );
      expect(
        foodActions,
        contains('final analysis = await service.analyze(image);'),
      );
      expect(foodPage, contains("Key('food-log-meal-analysis-progress')"));

      final selection = foodActions.indexOf(
        'if (image == null || !mounted) return;',
      );
      final progress = foodActions.indexOf(
        '_updateState(() => mealImageBusy = true);',
      );
      final analysis = foodActions.indexOf(
        'final analysis = await service.analyze(image);',
      );
      expect(selection, greaterThanOrEqualTo(0));
      expect(progress, greaterThan(selection));
      expect(analysis, greaterThan(progress));
    },
  );
}
