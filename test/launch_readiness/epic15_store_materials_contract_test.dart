import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'store metadata covers every shipped locale with honest owner boundaries',
    () {
      final metadata =
          jsonDecode(
                File(
                  'docs/release/BIL_EPIC15_STORE_METADATA.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final locales = metadata['locales'] as Map<String, dynamic>;

      expect(locales.keys.toSet(), {'ar', 'en-US', 'fr-FR', 'es-ES', 'tr-TR'});
      for (final copy in locales.values.cast<Map<String, dynamic>>()) {
        expect((copy['title'] as String).runes.length, lessThanOrEqualTo(30));
        expect(
          (copy['short_description'] as String).runes.length,
          lessThanOrEqualTo(80),
        );
        expect(copy['full_description'], contains('BIL'));
        expect(copy['release_notes'], isNotEmpty);
      }
      expect(metadata['legal_and_support']['domain'], 'bilhealth.com');
      expect(
        metadata['review']['credentials'],
        'NEVER_STORE_IN_GIT_ENTER_ONLY_IN_STORE_REVIEW_CONSOLE',
      );
    },
  );

  test('rights manifest records original art and real production captures', () {
    final rights =
        jsonDecode(
              File(
                'docs/release/BIL_EPIC15_CONTENT_RIGHTS.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final generated = rights['generated_for_bil_2026_08_05'] as List<dynamic>;

    expect(generated, hasLength(4));
    expect(
      generated.every((item) => item['rights'] == 'original_generated_for_BIL'),
      isTrue,
    );
    expect(rights['screenshots']['mockup'], isFalse);
    expect(
      rights['screenshots']['source'],
      contains('epic15_store_screenshot_golden_test.dart'),
    );
  });

  test('Apple and Google have independent launch checklists', () {
    final checklists = File(
      'docs/release/BIL_EPIC15_STORE_CHECKLISTS.md',
    ).readAsStringSync();

    expect(checklists, contains('Google Play'));
    expect(checklists, contains('Apple App Store'));
    expect(checklists, contains('OWNER_INPUT_REQUIRED'));
    expect(checklists, contains('actual production'));
    expect(checklists, contains('No preview video is claimed'));
  });

  test('platform declarations and public pages cover release obligations', () {
    final platform =
        jsonDecode(
              File(
                'docs/release/BIL_EPIC15_PLATFORM_METADATA.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final publicPages = File(
      'docs/release/BIL_EPIC15_PUBLIC_PAGES.md',
    ).readAsStringSync();

    expect(
      platform['google_play']['ads_declaration'],
      'CONTEXTUAL_NON_PERSONALIZED_FREE_TIER_ONLY_DISABLED_UNTIL_REVIEWED_PROVIDER_CONFIGURATION',
    );
    expect(platform['google_play']['data_safety'], isA<Map>());
    expect(platform['apple_app_store']['app_privacy'], isA<Map>());
    expect(platform['subscription_copy']['trial'], contains('NOT_CLAIMED'));
    expect(
      platform['subscription_copy']['localized_descriptions'],
      hasLength(5),
    );
    for (final route in [
      '/privacy',
      '/terms',
      '/support',
      '/contact',
      '/account-deletion',
      '/data-deletion',
      '/subscription-terms',
      '/content-rights',
    ]) {
      expect(publicPages, contains(route));
    }
  });
}
