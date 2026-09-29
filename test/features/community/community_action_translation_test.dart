import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in BilLocalePolicy.productionTags) {
    test('Community actions resolve without English fallback in $locale', () {
      for (final source in const ['Add emoji', 'Like']) {
        final text = CommunityReviewCopy.resolve(source, locale);
        expect(text, isNotNull, reason: '$locale: $source');
        expect(text!.trim(), isNotEmpty);
        expect(RuntimeCopy.resolve(source, locale), text);
        if (locale != 'en') {
          expect(text, isNot(source));
        }
      }
      expect(
        CommunityReviewCopy.translations[locale],
        hasLength(CommunityReviewCopy.keys.length),
      );
    });
  }
}
