import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_invite_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contact invitation is authored for every production locale', () {
    for (final tag in BilLocalePolicy.productionTags) {
      final message = bilCommunityInviteMessage(tag, name: 'Sam');
      expect(message, contains('Sam'), reason: tag);
      expect(message, contains(bilCommunityInviteDownloadUrl), reason: tag);
      expect(message, isNot(contains('{name}')), reason: tag);
      expect(message, isNot(contains('{url}')), reason: tag);
      expect(message, isNot(contains('\uFFFD')), reason: tag);
      final privacy = bilCommunityContactPrivacy(tag);
      expect(privacy.trim(), isNotEmpty, reason: tag);
      expect(privacy, isNot(contains('\uFFFD')), reason: tag);
      if (tag != 'en') {
        expect(
          privacy,
          isNot(bilCommunityContactPrivacy('en')),
          reason: '$tag privacy copy must not fall back to English',
        );
      }
      if (tag != 'en') {
        expect(
          message,
          isNot(startsWith('Hi Sam!')),
          reason: '$tag must not fall back to English',
        );
      }
    }
  });

  test('download invitation uses the verified BIL Health HTTPS domain', () {
    final uri = Uri.parse(bilCommunityInviteDownloadUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.bilhealth.com');
    expect(uri.path, '/download');
  });
}
