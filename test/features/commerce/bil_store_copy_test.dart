import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store/paywall copy is balanced across five production locales', () {
    expect(BilStoreCopy.catalogs.keys.toSet(), {'ar', 'en', 'fr', 'es', 'tr'});
    final keys = BilStoreCopy.catalogs['en']!.keys.toSet();
    for (final catalog in BilStoreCopy.catalogs.values) {
      expect(catalog.keys.toSet(), keys);
      expect(catalog.values.every((value) => value.trim().isNotEmpty), isTrue);
    }
  });

  test('catalog has final tier vocabulary and no monetary literals', () {
    for (final catalog in BilStoreCopy.catalogs.values) {
      expect(catalog['free'], isNotEmpty);
      expect(catalog['premium'], isNotEmpty);
      expect(catalog['premium_ai_coach'], isNotEmpty);
      expect(catalog['ai_boost'], contains('BIL AI'));
      expect(
        catalog.values.join(' '),
        isNot(matches(RegExp(r'[$€£]\s*\d|\d+[.,]\d{2}\s*(USD|EUR|GBP)'))),
      );
    }
  });
}
