import 'package:flutter/widgets.dart';

import 'bil_locale_policy.dart';
import 'runtime_copy.dart';

/// Small, typed localization surface for newly shipped product modules.
/// Keeping keys centralized prevents new hard-coded bilingual branches while
/// the legacy screens are migrated to generated application localizations.
class FeatureStrings {
  FeatureStrings._(this.locale);

  final Locale locale;
  String get languageCode => locale.languageCode;

  static FeatureStrings of(BuildContext context) =>
      FeatureStrings._(Localizations.localeOf(context));

  static const _values = <String, Map<String, String>>{
    'weekly_report': {
      'ar': 'تقريرك الأسبوعي',
      'en': 'Your weekly report',
      'fr': 'Votre rapport hebdomadaire',
      'es': 'Tu informe semanal',
      'tr': 'Haftalık raporunuz',
    },
    'last_7_days': {
      'ar': 'آخر 7 أيام',
      'en': 'Last 7 days',
      'fr': '7 derniers jours',
      'es': 'Últimos 7 días',
      'tr': 'Son 7 gün',
    },
    'logged_days': {
      'ar': 'أيام مسجلة',
      'en': 'Logged days',
      'fr': 'Jours enregistrés',
      'es': 'Días registrados',
      'tr': 'Kayıtlı günler',
    },
    'meals': {
      'ar': 'الوجبات',
      'en': 'Meals',
      'fr': 'Repas',
      'es': 'Comidas',
      'tr': 'Öğünler',
    },
    'water': {
      'ar': 'الماء',
      'en': 'Water',
      'fr': 'Eau',
      'es': 'Agua',
      'tr': 'Su',
    },
    'weight': {
      'ar': 'الوزن',
      'en': 'Weight',
      'fr': 'Poids',
      'es': 'Peso',
      'tr': 'Kilo',
    },
    'calories': {
      'ar': 'السعرات',
      'en': 'Calories',
      'fr': 'Calories',
      'es': 'Calorías',
      'tr': 'Kalori',
    },
    'protein': {
      'ar': 'البروتين',
      'en': 'Protein',
      'fr': 'Protéines',
      'es': 'Proteína',
      'tr': 'Protein',
    },
    'sodium': {
      'ar': 'الصوديوم',
      'en': 'Sodium',
      'fr': 'Sodium',
      'es': 'Sodio',
      'tr': 'Sodyum',
    },
    'no_data': {
      'ar': 'سجّل بياناتك هذا الأسبوع ليظهر تقرير موثوق.',
      'en': 'Log data this week to build a trustworthy report.',
      'fr': 'Enregistrez vos données pour créer un rapport fiable.',
      'es': 'Registra datos para crear un informe fiable.',
      'tr': 'Güvenilir bir rapor için bu hafta veri kaydedin.',
    },
    'measured_only': {
      'ar': 'يعرض BIL ما تم تسجيله فقط، ولا يقدّر أيامًا مفقودة.',
      'en': 'BIL shows logged data only and never estimates missing days.',
      'fr': 'BIL affiche uniquement les données saisies, sans estimation.',
      'es': 'BIL solo muestra datos registrados, sin estimar días faltantes.',
      'tr': 'BIL yalnızca kayıtlı verileri gösterir; eksikleri tahmin etmez.',
    },
    'content_library': {
      'ar': 'مكتبة العافية',
      'en': 'Wellness library',
      'fr': 'Bibliothèque bien-être',
      'es': 'Biblioteca de bienestar',
      'tr': 'Sağlık kitaplığı',
    },
  };

  static const supportedLanguageCodes = RuntimeCopy.supported;
  static Set<String> get englishValues =>
      _values.values.map((translations) => translations['en']!).toSet();

  static bool get catalogsBalanced => _values.values.every((translations) {
    const base = <String>{'ar', 'en', 'fr', 'es', 'tr'};
    final source = translations['en'];
    return translations.keys.toSet().containsAll(base) &&
        base.containsAll(translations.keys) &&
        source != null &&
        RuntimeCopy.supported.every(
          (tag) =>
              base.contains(tag) || RuntimeCopy.resolve(source, tag) != null,
        );
  });

  String get(String key) {
    final translations = _values[key];
    final value =
        translations?[languageCode] ??
        (translations?['en'] == null
            ? null
            : RuntimeCopy.resolve(
                translations!['en']!,
                BilLocalePolicy.canonicalTag(locale),
              ));
    assert(translations != null, 'Unknown feature translation key: $key');
    assert(value != null, 'Missing feature translation: $languageCode:$key');
    // Never replace useful authored copy with a visible localization error.
    // Assertions and localization audits still report missing catalog keys in
    // development, while release users receive the English source fallback.
    return value ?? translations?['en'] ?? key;
  }
}
