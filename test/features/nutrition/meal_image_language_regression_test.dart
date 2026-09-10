import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_coach_review.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/services/runtime_permission_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_image_review_dialog.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

const examples = <String, List<String>>{
  'en': ['tomato', 'A round red fruit is visible'],
  'ar': ['طماطم', 'ثمرة حمراء مستديرة ظاهرة'],
  'fr': ['tomate', 'Un fruit rouge et rond est visible'],
  'es': ['tomate', 'Se ve un fruto rojo y redondo'],
  'tr': ['domates', 'Yuvarlak kırmızı bir meyve görünüyor'],
  'de': ['Tomate', 'Eine runde rote Frucht ist sichtbar'],
  'it': ['pomodoro', 'È visibile un frutto rosso e rotondo'],
  'pt-BR': ['tomate', 'Uma fruta vermelha e redonda está visível'],
  'pt-PT': ['tomate', 'É visível um fruto vermelho e redondo'],
  'ur': ['ٹماٹر', 'ایک گول سرخ پھل نظر آ رہا ہے'],
  'fa': ['گوجه‌فرنگی', 'یک میوه گرد قرمز دیده می‌شود'],
  'hi': ['टमाटर', 'एक गोल लाल फल दिखाई दे रहा है'],
  'id': ['tomat', 'Terlihat buah bulat berwarna merah'],
  'ms': ['tomato', 'Kelihatan buah bulat berwarna merah'],
  'ja': ['トマト', '丸い赤い実が見えます'],
  'ko': ['토마토', '둥근 빨간 열매가 보입니다'],
  'zh-Hans': ['番茄', '可以看到圆形的红色果实'],
  'zh-Hant': ['番茄', '可以看到圓形的紅色果實'],
  'ru': ['помидор', 'Виден круглый красный плод'],
  'bn': ['টমেটো', 'একটি গোল লাল ফল দেখা যাচ্ছে'],
  'vi': ['cà chua', 'Có thể thấy một quả tròn màu đỏ'],
  'th': ['มะเขือเทศ', 'มองเห็นผลกลมสีแดง'],
  'pl': ['pomidor', 'Widoczny jest okrągły czerwony owoc'],
  'nl': ['tomaat', 'Er is een ronde rode vrucht zichtbaar'],
  'uk': ['помідор', 'Видно круглий червоний плід'],
};

Map<String, Object?> payload(String locale) => {
  'schema_version': 1,
  'response_locale': locale,
  'request_id': 'locale-fixture',
  'notice':
      'Confirm each visible food and serving. Nutrition is resolved separately from verified food records.',
  'candidates': [
    {
      'name': examples[locale]![0],
      'evidence': examples[locale]![1],
      'confidence': 1.0,
      'amount': 1.0,
      'unit': 'piece',
      'alternatives': [
        {'name': examples[locale]![0], 'confidence': 0.8},
      ],
      'uncertainty': examples[locale]![1],
      'warnings': [examples[locale]![1]],
      'provenance': {
        'identification_provider': 'fixture',
        'model_revision': 'test',
        'nutrition_resolution': 'requires_verified_food_match',
      },
    },
  ],
};

void main() {
  test('Coach review copy has exactly the 25 shipped locale columns', () {
    expect(
      CoachReviewRuntimeCopy.translations.keys.toSet(),
      BilLocalePolicy.productionTags,
    );
    expect(
      CoachReviewRuntimeCopy.permissionTranslations.keys.toSet(),
      BilLocalePolicy.productionTags,
    );
    expect(examples.keys.toSet(), BilLocalePolicy.productionTags);
    for (final row in CoachReviewRuntimeCopy.translations.values) {
      expect(row, hasLength(CoachReviewRuntimeCopy.keys.length));
      expect(row.every((item) => item.trim().isNotEmpty), isTrue);
    }
  });

  for (final locale in BilLocalePolicy.productionTags) {
    test('static review, permission, error copy and units use $locale', () {
      for (final key in [
        ...CoachReviewRuntimeCopy.keys,
        CoachReviewRuntimeCopy.cameraRationale,
        CoachReviewRuntimeCopy.settingsRecovery,
      ]) {
        final value = RuntimeCopy.resolve(key, locale);
        expect(value, isNotNull, reason: key);
        if (locale != 'en') expect(value, isNot(key), reason: '$locale: $key');
      }
      for (final capability in [
        BilRuntimeCapability.camera,
        BilRuntimeCapability.microphone,
        BilRuntimeCapability.speechRecognition,
      ]) {
        final copy = coachRuntimePermissionPresentation(capability);
        final value = intelligenceTextFor(
          locale,
          copy.englishRationale,
          copy.arabicRationale,
        );
        if (locale != 'en') expect(value, isNot(copy.englishRationale));
      }
      for (final failure in MealImageAnalysisFailure.values) {
        final exception = MealImageAnalysisException(failure);
        final value = exception.message(arabic: false, languageCode: locale);
        expect(value, isNotEmpty);
        if (locale != 'en') {
          expect(value, isNot(exception.message(arabic: false)));
        }
      }
      final copy = MealVisionUiCopy.ofLocale(
        BilLocalePolicy.localeFromTag(locale),
      );
      final english = MealVisionUiCopy.of('en');
      for (final key in [
        'review',
        'select_notice',
        'cancel',
        'confirmed_added',
        'unit_mismatch',
      ]) {
        expect(copy.text(key), isNotEmpty);
        if (locale != 'en') expect(copy.text(key), isNot(english.text(key)));
      }
      expect(
        mealImageCanonicalUnit(mealImageUnitLabel('piece', locale), locale),
        'piece',
      );
      expect(
        mealImageAmountInGrams(
          amount: 2,
          unit: mealImageCanonicalUnit(
            mealImageUnitLabel('piece', locale),
            locale,
          ),
          servingSize: 125,
          servingUnit: 'piece',
        ),
        250,
      );
    });

    test('localized dynamic fields survive intact in $locale', () {
      final result = parseMealImageResponse(
        jsonEncode(payload(locale)),
        languageCode: locale,
      );
      final candidate = result.candidates.single;
      expect(candidate.name, examples[locale]![0]);
      expect(candidate.evidence, examples[locale]![1]);
      expect(candidate.alternatives.single.name, examples[locale]![0]);
      expect(candidate.uncertainty, examples[locale]![1]);
      expect(candidate.warnings.single, examples[locale]![1]);
      expect(candidate.unit, 'piece');
      expect(
        result.notice,
        CoachReviewRuntimeCopy.resolve(CoachReviewRuntimeCopy.notice, locale),
      );
      expect(result.notice, isNot(payload(locale)['notice']));
      expect(candidate.requiresReview, isTrue);
    });

    if (locale != 'en') {
      test('rejects legacy or wrong-language result for $locale', () {
        final old = payload('en')..remove('response_locale');
        for (final wrong in [old, payload('en')]) {
          expect(
            () =>
                parseMealImageResponse(jsonEncode(wrong), languageCode: locale),
            throwsA(
              isA<MealImageAnalysisException>().having(
                (e) => e.failure,
                'failure',
                MealImageAnalysisFailure.languageMismatch,
              ),
            ),
          );
        }
      });
    }
  }

  test(
    'Arabic receipt cannot hide English evidence, alternatives or warnings',
    () {
      for (final field in [
        'name',
        'evidence',
        'alternatives',
        'uncertainty',
        'warnings',
      ]) {
        final wrong = payload('ar');
        final candidate =
            (wrong['candidates']! as List).single as Map<String, Object?>;
        candidate[field] = switch (field) {
          'alternatives' => [
            {'name': 'tomato', 'confidence': 0.8},
          ],
          'warnings' => ['English review warning'],
          _ => 'English model text',
        };
        expect(
          () => parseMealImageResponse(jsonEncode(wrong), languageCode: 'ar'),
          throwsA(isA<MealImageAnalysisException>()),
          reason: field,
        );
      }
    },
  );

  test('regional and script variants select their own column', () {
    for (final pair in {
      'ar_EG': 'ar',
      'fr-CA': 'fr',
      'pt_BR': 'pt-BR',
      'pt_PT': 'pt-PT',
      'zh-Hant-TW': 'zh-Hant',
      'zh-Hans-CN': 'zh-Hans',
    }.entries) {
      expect(
        CoachReviewRuntimeCopy.resolve(CoachReviewRuntimeCopy.notice, pair.key),
        CoachReviewRuntimeCopy.resolve(
          CoachReviewRuntimeCopy.notice,
          pair.value,
        ),
      );
      expect(
        parseMealImageResponse(
          jsonEncode(payload(pair.value)),
          languageCode: pair.key,
        ).candidates.single.name,
        examples[pair.value]![0],
      );
    }
  });

  test('semantic language failure is localized without a paid retry', () async {
    var requests = 0;
    final service = MealImageAnalysisService(
      endpoint: 'https://example.test/meal',
      requestedLocale: 'ar',
      accessToken: () => 'test-only',
      gatewayPost: ({required uri, required headers, required body}) async {
        requests++;
        return const MealImageGatewayResponse(
          statusCode: 502,
          body: '{"error":"vision_language_mismatch"}',
        );
      },
    );
    await expectLater(
      service.analyze(
        XFile.fromData(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
          mimeType: 'image/jpeg',
        ),
      ),
      throwsA(
        isA<MealImageAnalysisException>().having(
          (e) => e.failure,
          'failure',
          MealImageAnalysisFailure.languageMismatch,
        ),
      ),
    );
    expect(requests, 1);
  });

  testWidgets(
    'Arabic photo review displays Arabic and returns a canonical unit',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<MealImageReviewSelection>? selected;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showMealImageReviewDialog(
                    context,
                    analysis: parseMealImageResponse(
                      jsonEncode(payload('ar')),
                      languageCode: 'ar',
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('طماطم'), findsOneWidget);
      expect(find.text('tomato'), findsNothing);
      expect(find.text(payload('ar')['notice']! as String), findsNothing);
      expect(find.text('قطعة'), findsOneWidget);
      expect(find.text('piece'), findsNothing);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'مطابقة الأطعمة المحددة'),
      );
      await tester.pumpAndSettle();
      expect(selected!.single.unit, 'piece');
      expect(selected!.single.amount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
