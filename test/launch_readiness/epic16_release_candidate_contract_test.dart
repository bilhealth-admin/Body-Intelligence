import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release identity is consistent and changes remain owner-gated', () {
    final status =
        jsonDecode(
              File(
                'docs/release/BIL_EPIC16_IDENTIFIER_AND_RC_STATUS.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    expect(status['android_application_id'], 'com.bilhealth.bodyintelligencelog');
    expect(status['ios_bundle_identifier'], 'com.bilhealth.bodyintelligencelog');
    expect(status['identifier_consistency'], 'CONSISTENT');
    expect(
      status['identity_rebranding_decision'],
      'OWNER_APPROVED_COM_BILHEALTH_BODYINTELLIGENCELOG_2026_08_08',
    );
  });

  test('production defaults do not activate advertising', () {
    expect(AppEnvironment.adsEnabled, isFalse);
    expect(AppEnvironment.adProviderReady, isFalse);
    expect(AppEnvironment.adsConfigured, isFalse);
    expect(AppEnvironment.androidContextualAdUnitId, isEmpty);
    expect(AppEnvironment.iosContextualAdUnitId, isEmpty);
  });

  test(
    'external account register preserves verified and external boundaries',
    () {
      final status =
          jsonDecode(
                File(
                  'docs/release/BIL_EPIC16_EXTERNAL_ACCOUNT_STATUS.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final google = status['google_play']! as Map<String, Object?>;
      final apple = status['apple']! as Map<String, Object?>;
      expect(
        google['identity_and_address_review'],
        'OWNER_CONFIRMED_VERIFIED_SUCCESSFULLY',
      );
      expect(google['release'], 'NOT_PUBLISHED');
      expect(apple['developer_program'], 'OWNER_CONFIRMED_ACCOUNT_ACTIVE');
      expect(apple['signed_archive_or_testflight'], 'NOT_CLAIMED');
    },
  );
}
