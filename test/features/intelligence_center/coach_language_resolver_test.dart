import 'package:body_intelligence_log/features/intelligence_center/services/coach_language_resolver.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = CoachLanguageResolver();

  test('language detection is independent from UI locale', () {
    expect(
      resolver.resolve(input: 'كم بقي من السعرات؟', uiLocale: 'en').languageTag,
      'ar',
    );
    expect(
      resolver
          .resolve(input: 'Сколько калорий осталось?', uiLocale: 'ar')
          .languageTag,
      'ru',
    );
    expect(
      resolver
          .resolve(input: 'Скільки калорій залишилось?', uiLocale: 'en')
          .languageTag,
      'uk',
    );
    expect(
      resolver.resolve(input: '今日の残りカロリーは？', uiLocale: 'en').languageTag,
      'ja',
    );
    expect(
      resolver.resolve(input: '오늘 칼로리가 얼마나 남았나요?', uiLocale: 'en').languageTag,
      'ko',
    );
    expect(
      resolver
          .resolve(input: 'आज कितनी कैलोरी बची है?', uiLocale: 'en')
          .languageTag,
      'hi',
    );
    expect(
      resolver
          .resolve(input: 'আজ কত ক্যালোরি বাকি?', uiLocale: 'en')
          .languageTag,
      'bn',
    );
    expect(
      resolver
          .resolve(input: 'วันนี้เหลือกี่แคลอรี', uiLocale: 'en')
          .languageTag,
      'th',
    );
  });

  test('Latin ambiguity safely falls back to UI locale', () {
    final result = resolver.resolve(input: 'protein 30 g', uiLocale: 'tr');
    expect(result.languageTag, 'tr');
    expect(result.detected, isFalse);
  });

  test(
    'romanized speech and native speech hints override interface locale',
    () {
      final greeting = resolver.resolve(
        input: 'assalamualaikum',
        uiLocale: 'en',
      );
      expect(greeting.languageTag, 'ar');
      expect(greeting.detected, isTrue);

      final spokenGreek = resolver.resolve(
        input: 'protein 30 g',
        uiLocale: 'en',
        detectedLanguageTag: 'el-GR',
      );
      expect(spokenGreek.languageTag, 'el-GR');
      expect(spokenGreek.detected, isTrue);
    },
  );

  test('global scripts are detected outside the 25 interface locales', () {
    const cases = <String, String>{
      'Πόση πρωτεΐνη χρειάζομαι;': 'el',
      'כמה חלבון אני צריך?': 'he',
      'எனக்கு எவ்வளவு புரதம் தேவை?': 'ta',
      'എനിക്ക് എത്ര പ്രോട്ടീൻ വേണം?': 'ml',
    };
    for (final entry in cases.entries) {
      final result = resolver.resolve(input: entry.key, uiLocale: 'en');
      expect(result.languageTag, entry.value, reason: entry.key);
      expect(result.detected, isTrue, reason: entry.key);
    }
  });

  test('romanized Arabic greeting replies immediately in Arabic', () async {
    final reply = await const IntelligenceCenterEngine().answer(
      question: 'assalamualaikum',
      arabic: false,
      localeCode: 'en',
      detectedLanguageTag: 'ar-SA',
    );
    expect(reply.message.text, contains('أنا جاهز'));
  });

  test('preserves Chinese script and distinguishes Arabic-script locales', () {
    expect(
      resolver
          .resolve(input: '\u4eca\u65e5\u71b1\u91cf', uiLocale: 'zh-Hant')
          .languageTag,
      'zh-Hant',
    );
    expect(
      resolver
          .resolve(input: '\u4eca\u5929\u70ed\u91cf', uiLocale: 'zh-Hans')
          .languageTag,
      'zh-Hans',
    );
    expect(
      resolver
          .resolve(
            input: '\u0645\u06cc\u0631\u0627 \u0648\u0632\u0646',
            uiLocale: 'fa',
          )
          .languageTag,
      'fa',
    );
    expect(
      resolver
          .resolve(
            input: '\u0645\u06cc\u0631\u0627 \u0648\u0632\u0646 \u06c1\u06d2',
            uiLocale: 'en',
          )
          .languageTag,
      'ur',
    );
  });

  test('canonicalizes script and region fallback tags', () {
    expect(
      resolver.resolve(input: '30 g protein', uiLocale: 'zh_hant').languageTag,
      'zh-Hant',
    );
    expect(
      resolver.resolve(input: '30 g protein', uiLocale: 'pt_br').languageTag,
      'pt-BR',
    );
  });

  test('Portuguese detection preserves the selected regional contract', () {
    const phrase = 'Quantas calorias restam hoje?';
    expect(
      resolver.resolve(input: phrase, uiLocale: 'pt-BR').languageTag,
      'pt-BR',
    );
    expect(
      resolver.resolve(input: phrase, uiLocale: 'pt-PT').languageTag,
      'pt-PT',
    );
  });

  test('high-signal Latin phrases route independently without guessing', () {
    const cases = <String, String>{
      'Wie viele Kalorien sind heute übrig?': 'de',
      'Quante calorie rimangono oggi?': 'it',
      'Quantas calorias restam hoje?': 'pt-BR',
      'Combien de calories reste aujourd hui?': 'fr',
      'Cuántas calorías quedan hoy?': 'es',
      'Bugün kaç kalori kaldı?': 'tr',
      'Hôm nay còn lại bao nhiêu calo?': 'vi',
      'Ile kalorii zostało dzisiaj?': 'pl',
      'Hoeveel calorieën over vandaag?': 'nl',
    };
    for (final entry in cases.entries) {
      final result = resolver.resolve(
        input: entry.key,
        uiLocale: entry.value.startsWith('pt') ? 'pt-BR' : 'en',
      );
      expect(result.languageTag, entry.value, reason: entry.key);
      expect(result.detected, isTrue, reason: entry.key);
    }
  });

  test('Indonesian and Malay use distinct high-signal vocabulary', () {
    expect(
      resolver
          .resolve(
            input: 'Berapa asupan yang tersisa dari kebutuhan saya?',
            uiLocale: 'en',
          )
          .languageTag,
      'id',
    );
    expect(
      resolver
          .resolve(
            input: 'Berapa pengambilan berbaki daripada keperluan saya?',
            uiLocale: 'en',
          )
          .languageTag,
      'ms',
    );
  });
}
