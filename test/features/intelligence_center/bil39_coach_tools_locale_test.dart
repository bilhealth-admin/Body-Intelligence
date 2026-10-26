import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_tools_locale_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Coach tools have native copy in every one of the 25 release locales',
    () {
      expect(CoachToolsLocaleCopy.complete, isTrue);
      expect(
        CoachToolsLocaleCopy.rows.keys.toSet(),
        BilLocalePolicy.productionTags.toSet(),
      );
      for (final tag in BilLocalePolicy.productionTags) {
        for (final source in CoachToolsLocaleCopy.keys) {
          final copy = CoachToolsLocaleCopy.resolve(source, tag);
          expect(copy.trim(), isNotEmpty, reason: '$tag: $source');
          if (tag != 'en') {
            expect(copy, isNot(source), reason: '$tag: $source');
          } else {
            expect(copy, source, reason: tag);
          }
        }
      }
    },
  );

  test('Arabic and English distinguish all three Coach tools labels', () {
    expect(CoachToolsLocaleCopy.resolve('Coach tools', 'ar'), 'أدوات المدرب');
    expect(CoachToolsLocaleCopy.resolve('Food diary', 'ar'), 'سجل الطعام');
    expect(
      CoachToolsLocaleCopy.resolve('Nutrition analysis', 'ar'),
      'تحليل التغذية',
    );
    expect(CoachToolsLocaleCopy.resolve('Coach tools', 'en'), 'Coach tools');
    expect(CoachToolsLocaleCopy.resolve('Food diary', 'en'), 'Food diary');
    expect(
      CoachToolsLocaleCopy.resolve('Nutrition analysis', 'en'),
      'Nutrition analysis',
    );
  });

  test('Unknown labels fail closed; unsupported locale uses English', () {
    expect(
      () => CoachToolsLocaleCopy.resolve('Unknown tools label', 'ar'),
      throwsArgumentError,
    );
    expect(CoachToolsLocaleCopy.resolve('Food diary', 'xx'), 'Food diary');
  });
}
