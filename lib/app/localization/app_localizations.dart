import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'runtime_copy.dart';
import 'bil_locale_policy.dart';
part 'app_localizations_base_catalog.dart';
part 'app_localizations_arabic_runtime.dart';

class AppLocalizations {
  AppLocalizations(this.locale) {
    _activeLocale = locale;
  }

  final Locale locale;
  static Locale _activeLocale = const Locale('en');
  static Locale get activeLocale => _activeLocale;
  static void activate(Locale locale) => _activeLocale = locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
    Locale('es'),
    Locale('tr'),
    Locale('de'),
    Locale('it'),
    Locale('pt', 'BR'),
    Locale('pt', 'PT'),
    Locale('ur'),
    Locale('fa'),
    Locale('hi'),
    Locale('id'),
    Locale('ms'),
    Locale('ja'),
    Locale('ko'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ru'),
    Locale('bn'),
    Locale('vi'),
    Locale('th'),
    Locale('pl'),
    Locale('nl'),
    Locale('uk'),
  ];

  static const supportedLanguageCodes = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  };

  static bool isRtl(Locale locale) =>
      BilLocalePolicy.isRtlTag(BilLocalePolicy.canonicalTag(locale));

  static bool get baseCatalogsBalanced {
    final catalogs = <Map<String, String>>[_ar, _en, _fr, _es, _tr];
    final reference = _en.keys.toSet();
    return catalogs.every(
      (catalog) =>
          catalog.keys.toSet().containsAll(reference) &&
          reference.containsAll(catalog.keys) &&
          catalog.values.every((value) => value.trim().isNotEmpty),
    );
  }

  static Set<String> get baseKeys => _en.keys.toSet();
  static Set<String> get baseEnglishValues => _en.values.toSet();

  static const Map<String, String> _ar = _appLocaleAr;
  static const Map<String, String> _en = _appLocaleEn;
  static const Map<String, String> _fr = _appLocaleFr;
  static const Map<String, String> _es = _appLocaleEs;
  static const Map<String, String> _tr = _appLocaleTr;

  String get(String key) {
    final translations = switch (locale.languageCode) {
      'ar' => _ar,
      'fr' => _fr,
      'es' => _es,
      'tr' => _tr,
      _ => _en,
    };
    final source = _en[key];
    final extended = !const {
      'ar',
      'en',
      'fr',
      'es',
      'tr',
    }.contains(locale.languageCode);
    final value = extended
        ? source == null
              ? null
              : RuntimeCopy.resolve(
                  source,
                  BilLocalePolicy.canonicalTag(locale),
                )
        : translations[key];
    assert(
      value != null,
      'Missing production translation: ${locale.languageCode}:$key',
    );
    // Preserve usable copy in release builds. Missing keys remain assertions
    // in development, but a user must never see a translation-system error.
    return value ?? _en[key] ?? key;
  }

  bool has(String key) => switch (locale.languageCode) {
    'ar' => _ar.containsKey(key),
    'fr' => _fr.containsKey(key),
    'es' => _es.containsKey(key),
    'tr' => _tr.containsKey(key),
    'en' => _en.containsKey(key),
    _ =>
      _en[key] != null &&
          RuntimeCopy.resolve(
                _en[key]!,
                BilLocalePolicy.canonicalTag(locale),
              ) !=
              null,
  };

  String isolate(Object value) => '\u2068$value\u2069';

  String number(num value, {int? decimalDigits}) =>
      NumberFormat.decimalPatternDigits(
        locale: locale.toLanguageTag(),
        decimalDigits: decimalDigits,
      ).format(value);

  String date(DateTime value) =>
      DateFormat.yMMMd(locale.toLanguageTag()).format(value.toLocal());

  String time(DateTime value, {bool use24Hour = false}) => DateFormat(
    use24Hour ? 'HH:mm' : 'jm',
    locale.toLanguageTag(),
  ).format(value.toLocal());

  String plural(
    num count, {
    required String zero,
    required String one,
    required String other,
  }) => Intl.plural(
    count,
    zero: zero,
    one: one,
    other: other,
    locale: locale.languageCode,
    args: <Object>[count],
    name: 'bil_plural',
  );

  static const Map<String, String> _arabicText = _appLocaleArabicRuntime;

  String text(String english) {
    final reviewed = RuntimeCopy.resolve(
      english,
      BilLocalePolicy.canonicalTag(locale),
    );
    if (reviewed != null) return reviewed;
    if (locale.languageCode == 'en') return english;
    if (locale.languageCode == 'ar') {
      final exact = _arabicText[english];
      if (exact != null) return exact;
    }

    // Engine evidence can contain a measured numeric value rather than a
    // translatable sentence. Preserve the measured number and localize only
    // its unit; treating the whole value as a copy key causes a debug-time
    // assertion and incorrectly marks valid evidence as untranslated.
    final measurement = RegExp(
      r'^([+-]?\d+(?:\.\d+)?)\s+(kg|lb|g|mg|ml|L|cm|in|%)$',
    ).firstMatch(english);
    if (measurement != null) {
      final value = measurement.group(1)!;
      final sourceUnit = measurement.group(2)!;
      final unit = locale.languageCode == 'ar'
          ? switch (sourceUnit) {
              'kg' => 'كجم',
              'lb' => 'رطل',
              'g' => 'غ',
              'mg' => 'ملغ',
              'ml' => 'مل',
              'L' => 'لتر',
              'cm' => 'سم',
              'in' => 'بوصة',
              _ => sourceUnit,
            }
          : sourceUnit;
      return '$value $unit';
    }

    final weightChange = RegExp(
      r'^([+-]?\d+(?:\.\d+)?) kg since the previous check-in$',
    ).firstMatch(english);
    if (weightChange != null) {
      return '${weightChange.group(1)} كجم منذ القياس السابق';
    }

    final weightDays = RegExp(r'^(\d+) days with weight$').firstMatch(english);
    if (weightDays != null) {
      return '${weightDays.group(1)} أيام مسجلة للوزن';
    }

    final mealDays = RegExp(r'^(\d+) days with meal data$').firstMatch(english);
    if (mealDays != null) {
      return '${mealDays.group(1)} أيام ببيانات وجبات';
    }

    final hydrationDays = RegExp(
      r'^(\d+) days with hydration data$',
    ).firstMatch(english);
    if (hydrationDays != null) {
      return '${hydrationDays.group(1)} أيام ببيانات شرب الماء';
    }

    final comparable = RegExp(
      r'^(\d+) comparable weigh-ins$',
    ).firstMatch(english);
    if (comparable != null) {
      return '${comparable.group(1)} قياسات وزن قابلة للمقارنة';
    }

    final moreWeight = RegExp(
      r'^(\d+) more weight days for a useful trend$',
    ).firstMatch(english);
    if (moreWeight != null) {
      return 'نحتاج ${moreWeight.group(1)} أيام وزن إضافية لاتجاه مفيد';
    }

    final moreMeals = RegExp(
      r'^(\d+) more complete meal days for intake context$',
    ).firstMatch(english);
    if (moreMeals != null) {
      return 'نحتاج ${moreMeals.group(1)} أيام وجبات مكتملة إضافية';
    }

    // Runtime copy can contain user-derived values and server evidence. Keep
    // the English source visible until a reviewed translation is supplied;
    // never show an internal localization failure to the user.
    assert(() {
      debugPrint(
        'Missing reviewed runtime translation: '
        '${locale.languageCode}: $english',
      );
      return true;
    }());
    return english;
  }
}

extension AppLocalizationContext on BuildContext {
  AppLocalizations get strings => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (candidate) =>
        BilLocalePolicy.canonicalTag(candidate) ==
        BilLocalePolicy.canonicalTag(locale),
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
