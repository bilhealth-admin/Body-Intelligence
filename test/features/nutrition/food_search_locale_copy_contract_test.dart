import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food search UI copy is complete for all 25 supported locales', () {
    expect(FoodSearchRuntimeCopy.supported, hasLength(25));
    expect(FoodSearchRuntimeCopy.rows, hasLength(25));
    expect(FoodSearchRuntimeCopy.balanced, isTrue);

    for (final locale in FoodSearchRuntimeCopy.supported) {
      for (final source in FoodSearchRuntimeCopy.sources) {
        final translated = FoodSearchRuntimeCopy.resolve(source, locale);
        expect(
          translated,
          isNotNull,
          reason: 'Missing food-search copy for $locale: $source',
        );
        expect(translated!.trim(), isNotEmpty);
      }
    }
  });
}
