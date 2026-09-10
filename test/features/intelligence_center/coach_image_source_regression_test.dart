import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_rollout_manifest.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_coach_review.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_ui_copy.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'coach_review_actions_regression_test.dart' as harness;

class RecordingPicker extends ImagePicker {
  int calls = 0;
  final result = Completer<XFile?>();

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    calls++;
    expect(source, ImageSource.gallery);
    expect(maxWidth, 2048);
    expect(maxHeight, 2048);
    expect(imageQuality, 88);
    expect(requestFullMetadata, isFalse);
    return result.future;
  }
}

class RecordingAnalysis extends MealImageAnalysisService {
  RecordingAnalysis(String locale) : super(requestedLocale: locale);
  XFile? received;
  @override
  Future<MealImageAnalysis> analyze(XFile image) async {
    received = image;
    return parseMealImageResponse(
      jsonEncode({
        'schema_version': 1,
        'response_locale': requestedLocale,
        'request_id': 'local-fixture',
        'candidates': [
          {
            'name': requestedLocale == 'ar' ? 'طماطم' : 'Tomato',
            'evidence': requestedLocale == 'ar'
                ? 'ثمرة حمراء مستديرة'
                : 'Round red fruit',
            'confidence': 0.9,
            'amount': 1,
            'unit': 'piece',
            'provenance': {
              'identification_provider': 'local-test',
              'model_revision': 'test',
              'nutrition_resolution': 'requires_verified_food_match',
            },
          },
        ],
      }),
      languageCode: requestedLocale!,
    );
  }
}

final cameraButton = find.byKey(const Key('ai-coach-food-image-button'));
final galleryOption = find.byKey(const Key('ai-coach-image-source-gallery'));

void main() {
  for (final tag in BilLocaleRolloutManifest.releaseTargets25) {
    test('source picker and deletion selection stay in app locale $tag', () {
      final locale = BilLocalePolicy.localeFromTag(tag);
      final copy = MealVisionUiCopy.ofLocale(locale);
      expect(CoachReviewRuntimeCopy.balanced, isTrue);
      for (final key in ['take', 'choose', 'cancel']) {
        expect(copy.text(key), isNotEmpty);
        if (tag != 'en') {
          expect(copy.text(key), isNot(MealVisionUiCopy.of('en').text(key)));
        }
      }
      final deleteCopy = RuntimeCopy.resolve(
        CoachReviewRuntimeCopy.deleteSelection,
        tag,
      );
      expect(deleteCopy, isNotNull);
      if (tag != 'en') {
        expect(deleteCopy, isNot(CoachReviewRuntimeCopy.deleteSelection));
      }
    });
  }

  testWidgets(
    'source cancellation opens no picker and preserves draft and chat',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final picker = RecordingPicker();
      final prefs = PreferencesRepository(db);
      await harness.seed(prefs);
      await harness.mount(
        tester,
        db,
        gateway: harness.Gateway(),
        imagePicker: picker,
      );
      final field = find.byKey(const Key('ai-coach-question-field'));
      await tester.enterText(field, 'My unsent draft');
      await tester.tap(cameraButton);
      await tester.pumpAndSettle();
      expect(galleryOption, findsOneWidget);
      expect(
        find.byKey(const Key('ai-coach-image-source-camera')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ai-coach-image-source-cancel')));
      await tester.pumpAndSettle();
      expect(picker.calls, 0);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'My unsent draft',
      );
      expect(await prefs.get(harness.activeKey), 'current');
      await tester.tap(cameraButton);
      await tester.pumpAndSettle();
      expect(galleryOption, findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-coach-image-source-cancel')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await harness.unmount(tester);
    },
  );

  for (final leave in [false, true]) {
    testWidgets(
      'gallery is single-flight; cancellation/late result is safe, leave=$leave',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final picker = RecordingPicker();
        var analyses = 0;
        var permissionCalls = 0;
        const permissions = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissions,
          (call) async {
            permissionCalls++;
            return 0; // Gallery must work even when camera access is denied.
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            permissions,
            null,
          ),
        );
        final router = await harness.mount(
          tester,
          db,
          gateway: harness.Gateway(),
          imagePicker: picker,
          imageAnalysis: (locale) {
            analyses++;
            return RecordingAnalysis(locale);
          },
        );
        await tester.tap(cameraButton);
        await tester.pumpAndSettle();
        await tester.tap(galleryOption);
        await tester.pumpAndSettle();
        await tester.tap(cameraButton);
        await tester.pumpAndSettle();
        expect(picker.calls, 1);
        expect(permissionCalls, 0);
        if (leave) {
          router.go('/dashboard');
          await tester.pumpAndSettle();
        }
        picker.result.complete(leave ? XFile('late-result.jpg') : null);
        await tester.pumpAndSettle();
        expect(analyses, 0);
        expect(find.byType(AlertDialog), findsNothing);
        if (!leave) {
          await tester.tap(cameraButton);
          await tester.pumpAndSettle();
          expect(galleryOption, findsOneWidget);
          await tester.tap(
            find.byKey(const Key('ai-coach-image-source-cancel')),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await harness.unmount(tester);
      },
    );
  }

  for (final arabic in [false, true]) {
    testWidgets(
      'selected photo reaches the same localized review, arabic=$arabic',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final picker = RecordingPicker();
        final image = XFile('selected-local-photo.jpg');
        picker.result.complete(image);
        RecordingAnalysis? service;
        await harness.mount(
          tester,
          db,
          gateway: harness.Gateway(),
          arabic: arabic,
          imagePicker: picker,
          imageAnalysis: (locale) => service = RecordingAnalysis(locale),
        );
        await tester.tap(cameraButton);
        await tester.pumpAndSettle();
        await tester.tap(galleryOption);
        await tester.pumpAndSettle();
        expect(service!.received, same(image));
        expect(service!.requestedLocale, arabic ? 'ar' : 'en');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(arabic ? 'طماطم' : 'Tomato'), findsOneWidget);
        await tester.tap(find.text(arabic ? 'إلغاء' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(await PreferencesRepository(db).get(harness.activeKey), isNull);
        expect(tester.takeException(), isNull);
        await harness.unmount(tester);
      },
    );
  }

  testWidgets(
    'gallery error is localized, does not leak platform error, and permits retry',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final picker = RecordingPicker();
      await harness.mount(
        tester,
        db,
        gateway: harness.Gateway(),
        arabic: true,
        imagePicker: picker,
      );
      await tester.tap(cameraButton);
      await tester.pumpAndSettle();
      await tester.tap(galleryOption);
      await tester.pumpAndSettle();
      picker.result.completeError(
        PlatformException(
          code: 'photo_access_denied',
          message: 'sensitive-native-detail',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('sensitive-native-detail'), findsNothing);
      expect(
        find.text('فشل تحليل صورة الطعام. لم يُسجّل شيء.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(cameraButton);
      await tester.pumpAndSettle();
      expect(galleryOption, findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-coach-image-source-cancel')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await harness.unmount(tester);
    },
  );
}
