import 'bil_locale_policy.dart';
import 'runtime_copy_profile_catalog_a.dart';
import 'runtime_copy_profile_catalog_b.dart';
import 'runtime_copy_profile_catalog_c.dart';

/// Reviewed copy shared by every Profile surface.
///
/// Keep the regional Portuguese and scripted Chinese tags separate. Profile
/// previously rebuilt locales from [Locale.languageCode], which collapsed
/// these variants and exposed English fallback copy.
abstract final class ProfileRuntimeCopy {
  static const supported = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt-BR',
    'pt-PT',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh-Hans',
    'zh-Hant',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  };

  static const values = <String, Map<String, String>>{
    ...profileRuntimeCopyCatalogA,
    ...profileRuntimeCopyCatalogB,
    ...profileRuntimeCopyCatalogC,
  };

  static String? resolve(String english, String localeTag) {
    final canonical = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (canonical == null) return null;
    return values[english]?[canonical];
  }

  static bool get balanced =>
      supported.length == 25 &&
      values.values.every(
        (translations) =>
            translations.length == supported.length &&
            translations.keys.toSet().containsAll(supported) &&
            supported.containsAll(translations.keys) &&
            translations.values.every((value) => value.trim().isNotEmpty),
      );
}
