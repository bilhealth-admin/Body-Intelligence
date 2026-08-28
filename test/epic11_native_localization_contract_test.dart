import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const authoredLocales = <String>{'ar', 'en', 'fr', 'es', 'tr'};
  const extendedLocales = <String>{
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
  const iosLocales = <String>{...authoredLocales, ...extendedLocales};
  const iosKeys = <String>{
    'NSHealthShareUsageDescription',
    'NSHealthUpdateUsageDescription',
    'NSBluetoothAlwaysUsageDescription',
    'NSBluetoothPeripheralUsageDescription',
    'NSCameraUsageDescription',
    'NSPhotoLibraryUsageDescription',
    'NSMicrophoneUsageDescription',
    'NSSpeechRecognitionUsageDescription',
  };

  test('iOS permission copy is complete and bundled in all 25 locales', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final variantStart = project.indexOf('/* Begin PBXVariantGroup section */');
    final variantEnd = project.indexOf('/* End PBXVariantGroup section */');
    final variantGroup = project.substring(variantStart, variantEnd);
    final regionsStart = project.indexOf('knownRegions = (');
    final regionsEnd = project.indexOf('\n\t\t\t);', regionsStart);
    final knownRegions = project.substring(regionsStart, regionsEnd);
    final english = File(
      'ios/Runner/en.lproj/InfoPlist.strings',
    ).readAsStringSync();
    for (final locale in iosLocales) {
      final file = File('ios/Runner/$locale.lproj/InfoPlist.strings');
      expect(file.existsSync(), isTrue, reason: locale);
      final copy = file.readAsStringSync();
      expect(copy, isNot(contains('= "";')), reason: '$locale has empty copy');
      for (final key in iosKeys) {
        expect(copy, contains('"$key"'), reason: '$locale:$key');
      }
      final coachName = switch (locale) {
        'ar' => 'مدرب BIL الذكي',
        'fa' => 'مربی هوشمند BIL',
        _ => 'AI Coach',
      };
      expect(
        RegExp(
          '^"NSMicrophoneUsageDescription" = ".*${RegExp.escape(coachName)}.*";\r?\$',
          multiLine: true,
        ).hasMatch(copy),
        isTrue,
        reason: '$locale microphone copy must disclose AI Coach voice use',
      );
      expect(
        RegExp(
          '^"NSSpeechRecognitionUsageDescription" = ".*${RegExp.escape(coachName)}.*";\r?\$',
          multiLine: true,
        ).hasMatch(copy),
        isTrue,
        reason: '$locale speech copy must disclose AI Coach transcription',
      );
      expect(
        RegExp(r'^"NS', multiLine: true).allMatches(copy),
        hasLength(iosKeys.length),
        reason: '$locale must have the closed eight-key permission surface',
      );
      if (extendedLocales.contains(locale)) {
        expect(copy, isNot(english), reason: '$locale must not use English');
      }
      expect(
        variantGroup,
        contains('/* $locale */'),
        reason: '$locale must be a member of the Xcode variant group',
      );
      final regionToken = locale.contains('-') ? '"$locale"' : locale;
      expect(
        knownRegions,
        contains('\n\t\t\t\t$regionToken,'),
        reason: '$locale must be declared in knownRegions',
      );
    }
  });

  test('Android rationale and app name exist in all production languages', () {
    const androidQualifiers = <String, String>{
      'en': 'values',
      'ar': 'values-ar',
      'fr': 'values-fr',
      'es': 'values-es',
      'tr': 'values-tr',
      'de': 'values-de',
      'it': 'values-it',
      'pt-BR': 'values-pt-rBR',
      'pt-PT': 'values-pt-rPT',
      'ur': 'values-ur',
      'fa': 'values-fa',
      'hi': 'values-hi',
      'id': 'values-id',
      'ms': 'values-ms',
      'ja': 'values-ja',
      'ko': 'values-ko',
      'zh-Hans': 'values-b+zh+Hans',
      'zh-Hant': 'values-b+zh+Hant',
      'ru': 'values-ru',
      'bn': 'values-bn',
      'vi': 'values-vi',
      'th': 'values-th',
      'pl': 'values-pl',
      'nl': 'values-nl',
      'uk': 'values-uk',
    };
    for (final locale in iosLocales) {
      final qualifier = androidQualifiers[locale]!;
      final copy = File(
        'android/app/src/main/res/$qualifier/strings.xml',
      ).readAsStringSync();
      expect(copy, contains('name="app_name"'), reason: locale);
      expect(
        copy,
        contains('name="health_permissions_rationale_title"'),
        reason: locale,
      );
      expect(
        copy,
        contains('name="health_permissions_rationale_body"'),
        reason: locale,
      );
      if (extendedLocales.contains(locale)) {
        expect(
          copy,
          isNot(
            File(
              'android/app/src/main/res/values/strings.xml',
            ).readAsStringSync(),
          ),
          reason: '$locale must not use English Android resources',
        );
      }
    }
    final localeConfig = File(
      'android/app/src/main/res/xml/locales_config.xml',
    ).readAsStringSync();
    for (final locale in iosLocales) {
      expect(localeConfig, contains('android:name="$locale"'), reason: locale);
    }
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="@string/app_name"'),
    );
  });
}
