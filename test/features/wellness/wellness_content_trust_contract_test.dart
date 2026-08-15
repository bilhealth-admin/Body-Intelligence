import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> trustedItem() => <String, dynamic>{
    'id': 'recipe-1',
    'type': 'recipes',
    'locale': 'ar',
    'title': 'وصفة موثقة',
    'description': 'وصفة منشورة من مصدر معروف.',
    'publisher': 'Verified Publisher',
    'source_url': 'https://example.org/recipes/1',
    'license_name': 'Licensed content',
    'license_url': 'https://example.org/license',
    'image_url': 'https://example.org/images/1.jpg',
    'verified': true,
    'duration_minutes': 20,
    'instructions': <String>['Step one'],
  };

  test('trusted wellness content requires attribution and HTTPS media', () {
    final item = WellnessContentItem.fromJson(
      trustedItem(),
      expectedType: WellnessContentType.recipes,
    );

    expect(item.verified, isTrue);
    expect(item.publisher, 'Verified Publisher');
    expect(item.sourceUrl.scheme, 'https');
    expect(item.licenseName, isNotEmpty);
  });

  test('unverified or unattributed content fails closed', () {
    final unverified = trustedItem()..['verified'] = false;
    final unattributed = trustedItem()..remove('publisher');
    final insecure = trustedItem()
      ..['image_url'] = 'http://example.org/image.jpg';

    for (final payload in <Map<String, dynamic>>[
      unverified,
      unattributed,
      insecure,
    ]) {
      expect(
        () => WellnessContentItem.fromJson(
          payload,
          expectedType: WellnessContentType.recipes,
        ),
        throwsFormatException,
      );
    }
  });

  test('content pack manifest requires integrity and provenance', () {
    final pack = <String, dynamic>{
      'id': 'recipes-ar',
      'version': 1,
      'type': 'recipes',
      'title': 'Arabic recipes',
      'download_url': 'https://example.org/recipes.json',
      'size_bytes': 42,
      'sha256': List<String>.filled(64, 'a').join(),
      'item_count': 1,
      'publisher': 'Verified Publisher',
      'source_url': 'https://example.org/catalog',
      'license_name': 'Licensed content',
      'license_url': 'https://example.org/license',
    };

    expect(WellnessContentPack.fromJson(pack).publisher, isNotEmpty);
    expect(
      () => WellnessContentPack.fromJson(
        Map<String, dynamic>.from(pack)..remove('license_name'),
      ),
      throwsFormatException,
    );
  });

  test('production library consumes trusted items and exposes activity log', () {
    final source = File(
      'lib/features/wellness/presentation/professional_content_library_page.dart',
    ).readAsStringSync();

    expect(source, contains('loadTrustedInstalledItems'));
    expect(source, contains("/wellness/workouts/log"));
    expect(source, isNot(contains("List<Map<String, dynamic>>")));
  });
}
