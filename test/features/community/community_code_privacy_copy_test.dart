import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_code_privacy_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('own-code privacy guidance covers every exact production locale', () {
    expect(
      CommunityCodePrivacyCopy.rows.keys.toSet(),
      BilLocalePolicy.productionTags,
    );
    final english = CommunityCodePrivacyCopy.forTag('en');
    for (final tag in BilLocalePolicy.productionTags) {
      final copy = CommunityCodePrivacyCopy.forTag(tag);
      expect(
        [
          copy.intro,
          copy.blocked,
          copy.check,
        ].every((value) => value.trim().isNotEmpty),
        isTrue,
      );
      if (tag != 'en') {
        expect(copy.intro, isNot(english.intro), reason: tag);
        expect(copy.blocked, isNot(english.blocked), reason: tag);
        expect(copy.check, isNot(english.check), reason: tag);
      }
    }
  });
}
