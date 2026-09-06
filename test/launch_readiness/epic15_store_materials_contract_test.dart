import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  test(
    'rights manifest preserves current art and real production captures',
    () {
      final rights =
          jsonDecode(
                File(
                  'docs/release/BIL_EPIC15_CONTENT_RIGHTS.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final generated = rights['generated_for_bil_2026_08_05'] as List<dynamic>;
      final identity =
          rights['canonical_brand_identity'] as Map<String, dynamic>;
      final appIcon = identity['app_icon'] as Map<String, dynamic>;
      final wordmark = identity['full_wordmark'] as Map<String, dynamic>;
      final existing = (rights['existing_bil_assets'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final retired = rights['retired_brand_archive'] as Map<String, dynamic>;

      expect(
        generated,
        isEmpty,
        reason: 'Owner-rejected 2026-08-05 derivatives are not approved art.',
      );
      expect(appIcon['status'], 'OWNER_APPROVED_CURRENT');
      expect(appIcon['path'], 'assets/branding/bil_app_icon.png');
      final appIconFile = File(appIcon['path'] as String);
      expect(appIconFile.existsSync(), isTrue);
      expect(
        sha256.convert(appIconFile.readAsBytesSync()).toString(),
        appIcon['sha256'],
      );
      expect(wordmark['status'], 'OWNER_APPROVED_CURRENT');
      expect(wordmark['symbol'], 'BilFullWordmark');
      expect(wordmark['text'], 'BODY INTELLIGENCE LOG');
      expect(wordmark['trademark'], '™');
      final wordmarkSource = File(
        wordmark['path'] as String,
      ).readAsStringSync();
      expect(wordmarkSource, contains('class BilFullWordmark'));
      expect(wordmarkSource, contains("'BODY INTELLIGENCE LOG'"));
      expect(wordmarkSource, contains("'™'"));

      expect(existing, isNotEmpty);
      for (final item in existing) {
        expect(item['owner'], 'BIL');
        expect('${item['rights']}', isNotEmpty);
        expect(
          FileSystemEntity.typeSync(item['path'] as String),
          isNot(FileSystemEntityType.notFound),
          reason: item['path'] as String,
        );
      }

      expect(retired['status'], 'OWNER_REJECTED_DO_NOT_SHIP_2026_09_06');
      expect(
        File(retired['source_readme'] as String).existsSync(),
        isTrue,
        reason: 'The retirement tombstone must remain as recovery provenance.',
      );
      for (final path in const <String>[
        'assets/branding/bil_icon_master.png',
        'store_assets/graphics/google_play/feature_graphic.png',
        'store_assets/graphics/plans/free.png',
        'store_assets/graphics/plans/plus.png',
        'store_assets/graphics/plans/pro.png',
      ]) {
        expect(
          FileSystemEntity.typeSync(path),
          FileSystemEntityType.notFound,
          reason: 'Retired artwork must not be restored: $path',
        );
      }

      expect(rights['screenshots']['mockup'], isFalse);
      expect(
        rights['screenshots']['source'],
        contains('epic15_store_screenshot_golden_test.dart'),
      );
    },
  );

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
    final plans =
        platform['subscription_copy']['plans'] as Map<String, dynamic>;
    expect(
      plans.keys,
      containsAll(<String>['free', 'premium', 'premium_ai_coach']),
    );
    expect(plans.keys, isNot(contains('plus')));
    expect(plans.keys, isNot(contains('pro')));
    final descriptions =
        platform['subscription_copy']['localized_descriptions']
            as Map<String, dynamic>;
    expect(descriptions, hasLength(5));
    for (final localized in descriptions.values.cast<Map<String, dynamic>>()) {
      expect(
        localized.keys,
        containsAll(<String>['free', 'premium', 'premium_ai_coach']),
      );
    }
    expect(descriptions['en']['premium'], contains('community'));
    expect(descriptions['en']['premium_ai_coach'], contains('Everything'));
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
