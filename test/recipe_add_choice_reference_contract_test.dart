import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'recipe add sheet exposes web import and manual entry in five languages',
    () {
      final source = [
        'lib/features/nutrition/presentation/meals_recipes_foods_page.dart',
        'lib/features/nutrition/presentation/meals_recipes_components.dart',
        'lib/features/nutrition/presentation/recipes_tab.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(source, contains("Key('add-recipe-choice-sheet')"));
      expect(source, contains("Key('import-recipe-from-web')"));
      expect(source, contains("Key('enter-recipe-manually')"));
      for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
        expect(source, contains("'$locale': {"));
      }
    },
  );
}
