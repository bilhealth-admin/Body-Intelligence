import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';

void main() {
  test(
    'license-only feedback and action resolve in all 25 supported locales',
    () {
      const locales = [
        'en',
        'ar',
        'fr',
        'es',
        'tr',
        'de',
        'it',
        'pt-br',
        'pt-pt',
        'ur',
        'fa',
        'hi',
        'id',
        'ms',
        'ja',
        'ko',
        'zh-hans',
        'zh-hant',
        'ru',
        'bn',
        'vi',
        'th',
        'pl',
        'nl',
        'uk',
      ];
      const keys = [
        'license_unlicensed',
        'play_license_recovered',
        'play_readiness_unavailable',
        'fix_play_license',
        'play_license_recovered_pending',
      ];
      for (final locale in locales) {
        for (final key in keys) {
          final text = BilStoreCopy.text(locale, key);
          expect(text, isNotEmpty);
          expect(text, isNot(key));
        }
      }
    },
  );
}
