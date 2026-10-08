import 'package:body_intelligence_log/app/analytics/bil_launch_deep_link.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_bil_code_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_member_share.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

const code = '0123456789abcdef0123456789abcdef';

void main() {
  final public = CommunityPublicCode(
    code: code,
    uri: Uri.parse('bil://community/member/$code'),
    handle: 'bil.friend',
  );

  test('member share uses an HTTPS, rotatable public code only', () {
    final link = CommunityMemberShare.linkFor(public);
    expect(link.toString(), 'https://www.bilhealth.com/download?member=$code');
    expect(link.queryParameters, {'member': code});
    for (final locale in ['en', 'ar']) {
      final message = CommunityMemberShare.messageFor(public, locale: locale);
      expect(message, contains('BIL'));
      expect(message, contains('@bil.friend'));
      expect(message, contains(link.toString()));
      expect(message, isNot(contains('bil://')));
      expect(message, isNot(contains('Add @')));
    }
  });

  test('trusted incoming HTTPS resolves to the canonical member route', () {
    final link = CommunityMemberShare.linkFor(public);
    expect(CommunityDeepLink.routeFor(link), '/community/member/$code');
    expect(BilLaunchDeepLink.parse(link)?.route, '/community/member/$code');
    expect(CommunityCodeScannerPage.codeFromPayload(link.toString()), code);
    expect(
      CommunityCodeScannerPage.codeFromPayload('bil://community/member/$code'),
      code,
    );
  });

  test(
    'forged origins, insecure links, fragments and query injection fail closed',
    () {
      for (final invalid in [
        'https://evil.test/download?member=$code',
        'https://www.bilhealth.com.evil.test/download?member=$code',
        'https://www.bilhealth.com@evil.test/download?member=$code',
        'https://evil.test@www.bilhealth.com/download?member=$code',
        'http://www.bilhealth.com/download?member=$code',
        'https://bilhealth.com/download?member=$code',
        'https://www.bilhealth.com/download?member=$code&member=$code',
        'https://www.bilhealth.com/download?member=$code&redirect=evil',
        'https://www.bilhealth.com/download?member=$code#evil',
        'https://www.bilhealth.com/download?member=not-an-id',
      ]) {
        final link = Uri.parse(invalid);
        expect(CommunityDeepLink.routeFor(link), isNull, reason: invalid);
        expect(
          CommunityCodeScannerPage.codeFromPayload(invalid),
          isNull,
          reason: invalid,
        );
        expect(
          BilLaunchDeepLink.parse(link)?.route,
          isNot('/community/member/$code'),
          reason: invalid,
        );
      }
    },
  );

  test('explicit default HTTPS port canonicalizes to the same safe URI', () {
    // Dart Uri drops an explicit :443 while parsing because it is equivalent
    // to the default HTTPS port. Callers taking a Uri cannot distinguish them.
    final canonical = CommunityMemberShare.linkFor(public);
    final withDefaultPort = Uri.parse(
      'https://www.bilhealth.com:443/download?member=$code',
    );
    expect(withDefaultPort, canonical);
    expect(
      CommunityDeepLink.routeFor(withDefaultPort),
      '/community/member/$code',
    );
  });

  test('public share does not weaken the existing QR code contract', () {
    expect(
      CommunityCodeScannerPage.codeFromPayload(
        'bil://community/member/$code?token=x',
      ),
      isNull,
    );
    expect(
      CommunityCodeScannerPage.codeFromPayload(
        'https://example.invalid/community/member/$code',
      ),
      isNull,
    );
  });
}
