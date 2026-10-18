import 'package:body_intelligence_log/features/intelligence_center/services/coach_ios_speech_locale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic iOS follows the interface region when it is supported', () {
    expect(
      coachIosSpeechLocaleId(
        platform: TargetPlatform.iOS,
        interfaceLocaleTag: 'ar-EG',
        deviceLocaleTag: 'ar-SA',
        supportedLocaleIds: const ['ar-SA', 'ar-EG'],
      ),
      'ar-EG',
    );
  });

  test('generic Arabic prefers the Arabic device region when available', () {
    expect(
      coachIosSpeechLocaleId(
        platform: TargetPlatform.iOS,
        interfaceLocaleTag: 'ar',
        deviceLocaleTag: 'ar-SA',
        supportedLocaleIds: const ['ar-EG', 'ar-SA'],
      ),
      'ar-SA',
    );
  });

  test('generic Arabic uses a supported explicit fallback', () {
    expect(
      coachIosSpeechLocaleId(
        platform: TargetPlatform.iOS,
        interfaceLocaleTag: 'ar',
        deviceLocaleTag: 'en-US',
        supportedLocaleIds: const ['en-US', 'ar-EG'],
      ),
      'ar-EG',
    );
  });

  test('English iOS retains the system locale instead of forcing Arabic', () {
    expect(
      coachIosSpeechLocaleId(
        platform: TargetPlatform.iOS,
        interfaceLocaleTag: 'en',
        deviceLocaleTag: 'ar-SA',
        supportedLocaleIds: const ['ar-SA', 'en-US'],
      ),
      isNull,
    );
  });

  test('Android retains automatic language detection', () {
    expect(
      coachIosSpeechLocaleId(
        platform: TargetPlatform.android,
        interfaceLocaleTag: 'ar',
        deviceLocaleTag: 'ar-SA',
        supportedLocaleIds: const ['ar-SA'],
      ),
      isNull,
    );
  });

  test(
    'unsupported Arabic recognition falls back without inventing locale',
    () {
      expect(
        coachIosSpeechLocaleId(
          platform: TargetPlatform.iOS,
          interfaceLocaleTag: 'ar',
          deviceLocaleTag: 'ar-SA',
          supportedLocaleIds: const ['en-US'],
        ),
        isNull,
      );
    },
  );
}
