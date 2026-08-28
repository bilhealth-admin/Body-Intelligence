import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/nutrition/domain/product_identity.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/product_identity_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product identification never falls back to English in 25 locales', () {
    final languageCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    const product = ProductIdentity(
      barcode: '4006381333931',
      kind: ProductKind.unknown,
      name: 'BIL test product',
      source: 'test',
      confidence: ProductIdentityConfidence.high,
    );

    for (final code in languageCodes) {
      final label = productKindLabel(
        ProductKind.unknown,
        arabic: code == 'ar',
        languageCode: code,
      );
      final explanation = productIdentityExplanation(
        product,
        arabic: code == 'ar',
        languageCode: code,
      );
      expect(label.trim(), isNotEmpty, reason: code);
      expect(explanation.trim(), isNotEmpty, reason: code);
      if (code != 'en') {
        expect(label, isNot('Unclassified product'), reason: code);
        expect(
          explanation,
          isNot(contains('complete trusted nutrition data is unavailable')),
          reason: code,
        );
      }
    }
  });
}
