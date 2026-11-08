import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_recipe_editor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Arabic recipe carbohydrate label resolves without fallback diagnostic',
    () {
      final original = debugPrint;
      final diagnostics = <String>[];
      try {
        debugPrint = (message, {wrapWidth}) => diagnostics.add(message ?? '');
        expect(
          AppLocalizations(const Locale('ar')).text('Carbs'),
          'الكربوهيدرات',
        );
        expect(RuntimeCopy.resolve('Carbs', 'ar-EG'), 'الكربوهيدرات');
        expect(diagnostics, isEmpty);
      } finally {
        debugPrint = original;
      }
    },
  );

  test(
    'the narrow Arabic addition preserves English and other locale paths',
    () {
      expect(AppLocalizations(const Locale('en')).text('Carbs'), 'Carbs');
      for (final tag in BilLocalePolicy.productionTags.where(
        (tag) => tag != 'ar',
      )) {
        expect(
          RecipeEditorRuntimeCopy.resolve('Carbs', tag),
          isNull,
          reason: tag,
        );
      }
      for (final tag in ExtendedRuntimeCopy.supported) {
        expect(
          RuntimeCopy.resolve('Carbs', tag),
          ExtendedRuntimeCopy.values['Carbs']![tag],
          reason: tag,
        );
      }
    },
  );
}
