import 'package:body_intelligence_log/app/localization/runtime_copy_food_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Food Log release copy is complete in all 25 shipped locales', () {
    expect(FoodLogRuntimeCopy.supported, hasLength(25));
    expect(FoodLogRuntimeCopy.balanced, isTrue);
    for (final source in FoodLogRuntimeCopy.sources) {
      for (final locale in FoodLogRuntimeCopy.supported) {
        final copy = FoodLogRuntimeCopy.resolve(source, locale);
        expect(copy, isNotNull, reason: '$locale: $source');
        expect(copy!.trim(), isNotEmpty, reason: '$locale: $source');
        if (locale != 'en') {
          expect(
            copy,
            isNot(source),
            reason: 'English fallback leaked in $locale',
          );
        }
      }
    }
  });
}
