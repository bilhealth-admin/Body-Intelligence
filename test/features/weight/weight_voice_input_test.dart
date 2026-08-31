import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_check_in.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/weight/services/weight_voice_input_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpokenWeightParser', () {
    test(
      'accepts localized digits and units for every supported BIL locale',
      () {
        const cases = <(String, String)>[
          ('ar', 'وزني ٨٢٫٥ كيلو'),
          ('en', '82.5 kilograms'),
          ('fr', '82,5 kilogrammes'),
          ('es', '82,5 kilos'),
          ('tr', '82,5 kilo'),
          ('de', '82,5 Kilogramm'),
          ('it', '82,5 kilogrammi'),
          ('pt-BR', '82,5 quilos'),
          ('pt-PT', '82,5 kg'),
          ('ur', '۸۲٫۵ کلوگرام'),
          ('fa', '۸۲٫۵ کیلوگرم'),
          ('hi', '८२.५ किलोग्राम'),
          ('id', '82,5 kilogram'),
          ('ms', '82.5 kilogram'),
          ('ja', '８２．５キログラム'),
          ('ko', '82.5 킬로그램'),
          ('zh-Hans', '82.5公斤'),
          ('zh-Hant', '82.5公斤'),
          ('ru', '82,5 кг'),
          ('bn', '৮২.৫ কিলোগ্রাম'),
          ('vi', '82,5 ký'),
          ('th', '๘๒.๕ กิโลกรัม'),
          ('pl', '82,5 kilogramów'),
          ('nl', '82,5 kilogram'),
          ('uk', '82,5 кілограмів'),
        ];

        for (final (locale, transcript) in cases) {
          final result = SpokenWeightParser.parse(
            transcript,
            fallbackSystem: MeasurementSystem.imperial,
            localeTag: locale,
          );
          expect(result, isNotNull, reason: '$locale: $transcript');
          expect(result!.unit, SpokenWeightUnit.kilograms, reason: locale);
          expect(result.value, closeTo(82.5, 0.001), reason: locale);
        }
      },
    );

    test('accepts pounds across every supported BIL locale', () {
      const cases = <(String, String)>[
        ('ar', 'وزني ١٨٠ رطل'),
        ('en', '180 pounds'),
        ('fr', '180 livres'),
        ('es', '180 libras'),
        ('tr', '180 lb'),
        ('de', '180 Pfund'),
        ('it', '180 libbre'),
        ('pt-BR', '180 libras'),
        ('pt-PT', '180 lb'),
        ('ur', '۱۸۰ پاؤنڈ'),
        ('fa', '۱۸۰ پوند'),
        ('hi', '१८० पाउंड'),
        ('id', '180 pon'),
        ('ms', '180 paun'),
        ('ja', '１８０ポンド'),
        ('ko', '180 파운드'),
        ('zh-Hans', '180磅'),
        ('zh-Hant', '180磅'),
        ('ru', '180 фунтов'),
        ('bn', '১৮০ পাউন্ড'),
        ('vi', '180 lb'),
        ('th', '๑๘๐ ปอนด์'),
        ('pl', '180 funtów'),
        ('nl', '180 pond'),
        ('uk', '180 фунтів'),
      ];

      for (final (locale, transcript) in cases) {
        final result = SpokenWeightParser.parse(
          transcript,
          fallbackSystem: MeasurementSystem.metric,
          localeTag: locale,
        );
        expect(result, isNotNull, reason: '$locale: $transcript');
        expect(result!.unit, SpokenWeightUnit.pounds, reason: locale);
        expect(result.value, closeTo(180, 0.001), reason: locale);
        expect(result.kilograms, closeTo(81.6466, 0.001), reason: locale);
      }
    });

    test('accepts Arabic speech and Arabic-Indic digits', () {
      final result = SpokenWeightParser.parse(
        'وزني ٨٢٫٥ كيلو',
        fallbackSystem: MeasurementSystem.imperial,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.kilograms);
      expect(result.value, 82.5);
    });

    test('accepts English number words and pounds', () {
      final result = SpokenWeightParser.parse(
        'one hundred eighty pounds',
        fallbackSystem: MeasurementSystem.metric,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.pounds);
      expect(result.value, 180);
      expect(result.kilograms, closeTo(81.65, 0.01));
    });

    test('preserves a spoken English decimal instead of summing digits', () {
      final result = SpokenWeightParser.parse(
        'eighty two point five kilograms',
        fallbackSystem: MeasurementSystem.imperial,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.kilograms);
      expect(result.value, 82.5);
    });

    test('accepts Arabic number words and a spoken decimal', () {
      final result = SpokenWeightParser.parse(
        'اثنين وثمانين فاصلة خمسة كيلو',
        fallbackSystem: MeasurementSystem.imperial,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.kilograms);
      expect(result.value, 82.5);
    });

    test(
      'accepts localized number words from representative language families',
      () {
        const cases = <(String, String)>[
          ('es', 'ochenta y dos coma cinco kilos'),
          ('fr', 'quatre-vingt-deux virgule cinq kilogrammes'),
          ('tr', 'seksen iki virgül beş kilo'),
          ('fa', 'هشتاد و دو ممیز پنج کیلوگرم'),
          ('id', 'delapan puluh dua koma lima kilogram'),
          ('ru', 'восемьдесят два запятая пять килограммов'),
          ('vi', 'tám mươi hai phẩy năm ký'),
          ('pl', 'osiemdziesiąt dwa przecinek pięć kilogramów'),
          ('zh-Hans', '八十二点五公斤'),
          ('ja', '八十二点五キロ'),
          ('ko', '팔십이점오 킬로그램'),
        ];

        for (final (locale, transcript) in cases) {
          final result = SpokenWeightParser.parse(
            transcript,
            fallbackSystem: MeasurementSystem.metric,
            localeTag: locale,
          );
          expect(result, isNotNull, reason: '$locale: $transcript');
          expect(result!.value, closeTo(82.5, 0.001), reason: locale);
        }
      },
    );

    test('uses the selected measurement system when unit is omitted', () {
      final result = SpokenWeightParser.parse(
        '72.4',
        fallbackSystem: MeasurementSystem.metric,
      );

      expect(result, isNotNull);
      expect(result!.unit, SpokenWeightUnit.kilograms);
      expect(result.value, 72.4);
    });

    test('rejects implausible values instead of changing the field', () {
      expect(
        SpokenWeightParser.parse(
          '900 kg',
          fallbackSystem: MeasurementSystem.metric,
        ),
        isNull,
      );
      expect(
        SpokenWeightParser.parse(
          'nothing useful',
          fallbackSystem: MeasurementSystem.metric,
        ),
        isNull,
      );
      expect(
        SpokenWeightParser.parse(
          'weight was 82, then 85 kilograms',
          fallbackSystem: MeasurementSystem.metric,
        ),
        isNull,
        reason: 'two plausible values must never be guessed between',
      );
      expect(
        SpokenWeightParser.parse(
          '82 kilograms, repeat 82 kilograms',
          fallbackSystem: MeasurementSystem.metric,
        ),
        isNull,
        reason: 'repeated equal numbers are still multiple observations',
      );
    });

    test('uses the same reviewed range as manual entry and persistence', () {
      expect(
        SpokenWeightParser.parse(
          '450 kilograms',
          fallbackSystem: MeasurementSystem.metric,
        )?.kilograms,
        closeTo(450, 0.001),
      );
      expect(
        SpokenWeightParser.parse(
          '1000 pounds',
          fallbackSystem: MeasurementSystem.imperial,
        )?.kilograms,
        closeTo(453.592, 0.001),
      );
      expect(
        SpokenWeightParser.parse(
          '501 kilograms',
          fallbackSystem: MeasurementSystem.metric,
        ),
        isNull,
      );
    });

    test('rejects signed, ambiguous, date-like, and conflicting input', () {
      const unsafe = <(String, String?)>[
        ('-82 kg', 'en'),
        ('−82 kg', 'en'),
        ('minus eighty two kilograms', 'en'),
        ('ناقص ٨٢ كيلو', 'ar'),
        ('30/08/2026', 'en'),
        ('at 7:30', 'en'),
        ('at five thirty', 'en'),
        ('August thirty', 'en'),
        ('five pm, weight eighty two kilograms', 'en'),
        ('82 point five kilograms', 'en'),
        ('82 five kilograms', 'en'),
        ('born in 1990, now 82 kg', 'en'),
        ('82 kg or 181 pounds', 'en'),
        ('82 kilograms pounds', 'en'),
        ('八月三十日，体重八十二公斤', 'zh-Hans'),
      ];

      for (final (transcript, locale) in unsafe) {
        expect(
          SpokenWeightParser.parse(
            transcript,
            fallbackSystem: MeasurementSystem.metric,
            localeTag: locale,
          ),
          isNull,
          reason: transcript,
        );
      }
    });

    test('handles locale mismatch and safe pound conversion', () {
      final arabicUnderEnglish = SpokenWeightParser.parse(
        'اثنين وثمانين فاصلة خمسة كيلو',
        fallbackSystem: MeasurementSystem.imperial,
        localeTag: 'en-US',
      );
      final englishUnderArabic = SpokenWeightParser.parse(
        'one hundred eighty pounds',
        fallbackSystem: MeasurementSystem.metric,
        localeTag: 'ar-EG',
      );
      final unitlessWords = SpokenWeightParser.parse(
        'eighty two point five',
        fallbackSystem: MeasurementSystem.metric,
        localeTag: 'en-US',
      );

      expect(arabicUnderEnglish?.kilograms, closeTo(82.5, 0.001));
      expect(englishUnderArabic?.kilograms, closeTo(81.6466, 0.001));
      expect(unitlessWords?.kilograms, closeTo(82.5, 0.001));
    });

    test('all release locales have safe invalid-weight feedback', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toLanguageTag();
        expect(
          CheckInRuntimeCopy.resolve('Enter a valid weight.', tag),
          isNotNull,
          reason: tag,
        );
      }
    });

    test('iOS microphone and speech disclosures include weight entry', () {
      const weightTerms = <String, String>{
        'ar': 'وزن',
        'bn': 'ওজন',
        'de': 'Gewicht',
        'en': 'weight',
        'es': 'peso',
        'fa': 'وزن',
        'fr': 'poids',
        'hi': 'वज़न',
        'id': 'berat',
        'it': 'peso',
        'ja': '体重',
        'ko': '체중',
        'ms': 'berat',
        'nl': 'gewicht',
        'pl': 'masy ciała',
        'pt-BR': 'peso',
        'pt-PT': 'peso',
        'ru': 'веса',
        'th': 'น้ำหนัก',
        'tr': 'kilo',
        'uk': 'ваги',
        'ur': 'وزن',
        'vi': 'cân nặng',
        'zh-Hans': '体重',
        'zh-Hant': '體重',
      };

      for (final entry in weightTerms.entries) {
        final source = File(
          'ios/Runner/${entry.key}.lproj/InfoPlist.strings',
        ).readAsStringSync();
        expect(
          entry.value.allMatches(source).length,
          greaterThanOrEqualTo(2),
          reason: entry.key,
        );
      }
      final fallback = File('ios/Runner/Info.plist').readAsStringSync();
      expect('weight'.allMatches(fallback).length, greaterThanOrEqualTo(2));
    });

    test('voice review contract never puts raw speech in the weight field', () {
      final source = File(
        'lib/features/weight/services/weight_voice_input_service.dart',
      ).readAsStringSync();
      final candidateSource = File(
        'lib/features/weight/services/spoken_weight_parser.dart',
      ).readAsStringSync();

      expect(source, contains('text: reviewedNumber'));
      expect(source, isNot(contains('text: transcript')));
      expect(
        source,
        contains("CheckInRuntimeCopy.resolve('Enter a valid weight.'"),
      );
      expect(source, contains('localeId: preferredLocale'));
      expect(candidateSource, isNot(contains('final String transcript')));
    });
  });
}
