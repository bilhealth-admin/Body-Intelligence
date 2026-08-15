import 'package:body_intelligence_log/features/nutrition/services/meal_voice_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('voice food candidate parser', () {
    test(
      'extracts an optional reviewed quantity without nutrition guesses',
      () {
        final candidate = MealVoiceCandidateParser.parse(
          transcript: '200 g chicken breast',
          localeId: 'en-US',
        );
        expect(candidate.foodQuery, 'chicken breast');
        expect(candidate.quantity, 200);
        expect(candidate.unit, 'g');
      },
    );

    test('preserves a dialect phrase as an editable search candidate', () {
      final candidate = MealVoiceCandidateParser.parse(
        transcript: 'كوب عدس مطبوخ',
        localeId: 'ar-EG',
      );
      expect(candidate.foodQuery, 'كوب عدس مطبوخ');
      expect(candidate.localeId, 'ar-EG');
    });

    test('rejects an empty or unbounded candidate', () {
      expect(
        () => MealVoiceCandidateParser.parse(
          transcript: '   ',
          localeId: 'ar-EG',
        ),
        throwsFormatException,
      );
      expect(
        () => MealVoiceCandidateParser.parse(
          transcript: List.filled(241, 'a').join(),
          localeId: 'en-US',
        ),
        throwsFormatException,
      );
    });
  });

  group('device locale and dialect resolver', () {
    test('prefers the exact Arabic device dialect when installed', () {
      expect(
        MealVoiceLocaleResolver.resolve(
          appLanguage: 'ar',
          deviceLocale: 'ar_JO',
          availableLocales: const ['ar-EG', 'ar-JO', 'en-US'],
        ),
        'ar-JO',
      );
    });

    test('uses a deterministic Arabic fallback supported by the device', () {
      expect(
        MealVoiceLocaleResolver.resolve(
          appLanguage: 'ar',
          deviceLocale: 'en-US',
          availableLocales: const ['ar-SA', 'ar-EG'],
        ),
        'ar-EG',
      );
    });

    test('never falls back to another app language', () {
      expect(
        MealVoiceLocaleResolver.resolve(
          appLanguage: 'tr',
          deviceLocale: 'en-US',
          availableLocales: const ['en-US', 'ar-EG'],
        ),
        isNull,
      );
    });
  });

  test('permission timeout and no-match errors remain distinguishable', () {
    expect(
      classifyMealVoiceFailure('microphone_permission_denied'),
      MealVoiceFailure.permissionDenied,
    );
    expect(
      classifyMealVoiceFailure('speech_timeout'),
      MealVoiceFailure.timeout,
    );
    expect(
      classifyMealVoiceFailure('speech_no_match'),
      MealVoiceFailure.noMatch,
    );
  });
}
