import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_form_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'new form feedback covers every production locale without English fallback',
    () {
      expect(CommunityFormCopy.translations, hasLength(24));
      for (final values in CommunityFormCopy.translations.values) {
        expect(values, hasLength(CommunityFormCopy.englishKeys.length));
      }
      for (final tag in BilLocalePolicy.productionTags) {
        for (final english in CommunityFormCopy.englishKeys) {
          final text = CommunityFormCopy.resolve(english, tag);
          expect(text, isNotNull, reason: '$tag: $english');
          expect(text!.trim(), isNotEmpty);
          if (tag != 'en') {
            expect(text, isNot(english), reason: '$tag: $english');
          }
          expect(
            communityTextForLanguage(
              tag,
              english,
              CommunityFormCopy.resolve(english, 'ar')!,
            ),
            text,
          );
        }
      }
    },
  );
}
