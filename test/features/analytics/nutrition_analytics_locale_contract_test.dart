import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nutrition analytics surface has direct copy in 20 extended locales', () {
    const keys = <String>{
      'Nutrition',
      'Calories',
      'Nutrients',
      'Macros',
      'Food analysis',
      'Export',
      'Previous day',
      'Next day',
      'No foods logged for this day.',
      'Log food',
      'Your recorded nutrients',
      'Calorie total includes evidenced entries only; some entries are unknown.',
      'Macro distribution uses evidenced carbohydrate, protein, and fat only.',
      'Top contributors',
      'Unknown food',
      'Entries with unknown values',
      'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.',
    };

    expect(RuntimeCopy.supported, hasLength(25));
    for (final key in keys) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = ExtendedRuntimeCopy.values[key]?[locale];
        expect(value, isNotNull, reason: 'missing $locale/$key');
        expect(value!.trim(), isNotEmpty, reason: 'empty $locale/$key');
        // A direct catalog entry is the contract. Cognates such as “Macros”
        // are legitimately identical in several supported languages.
        expect(
          ExtendedRuntimeCopy.values[key]!.containsKey(locale),
          isTrue,
          reason: 'fallback instead of direct copy $locale/$key',
        );
      }
    }
  });
}
