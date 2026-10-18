import 'package:flutter_test/flutter_test.dart';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_coach_quick_prompts.dart';

void main() {
  test('Coach quick prompts are complete in all 25 production locales', () {
    expect(CoachQuickPromptRuntimeCopy.balanced, isTrue);
    expect(CoachQuickPromptRuntimeCopy.sources, hasLength(16));
    for (final locale in BilLocalePolicy.productionTags) {
      for (final source in CoachQuickPromptRuntimeCopy.sources) {
        final copy = RuntimeCopy.resolve(source, locale);
        expect(copy, isNotNull, reason: '$locale: $source');
        expect(copy!.trim(), isNotEmpty, reason: '$locale: $source');
        if (locale != 'en') {
          expect(copy, isNot(source), reason: '$locale: $source');
        }
      }
    }
  });
}
