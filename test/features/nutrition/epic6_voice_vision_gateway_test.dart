import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('authenticated meal-image gateway', () {
    test('sends image evidence and parses review-required provenance', () async {
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;
      final service = MealImageAnalysisService(
        endpoint: 'https://example.test/functions/v1/analyze-meal',
        accessToken: () => 'signed-session',
        requestedLocale: 'ar_EG',
        gatewayPost: ({required uri, required headers, required body}) async {
          capturedHeaders = headers;
          capturedBody = jsonDecode(body) as Map<String, dynamic>;
          return const MealImageGatewayResponse(
            statusCode: 200,
            body:
                '{"schema_version":1,"request_id":"req-1","candidates":[{"name":"دجاج","confidence":0.91,"evidence":"visible grilled pieces","provenance":{"identification_provider":"vision-provider","model_revision":"2026-08","nutrition_resolution":"requires_verified_food_match"}}],"notice":"Confirm visible foods."}',
          );
        },
      );
      final result = await service.analyze(
        XFile.fromData(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
          mimeType: 'image/jpeg',
          name: 'meal.jpg',
        ),
      );
      expect(
        capturedHeaders?[HttpHeaders.authorizationHeader],
        'Bearer signed-session',
      );
      expect(capturedBody?['requested_locale'], 'ar-EG');
      expect(capturedBody, isNot(contains('nutrition')));
      expect(result.candidates.single.name, 'دجاج');
      expect(result.candidates.single.requiresReview, isTrue);
      expect(result.requiresReview, isTrue);
    });

    test(
      'fails closed before upload without an authenticated session',
      () async {
        var uploaded = false;
        final service = MealImageAnalysisService(
          endpoint: 'https://example.test/functions/v1/analyze-meal',
          accessToken: () => null,
          gatewayPost: ({required uri, required headers, required body}) async {
            uploaded = true;
            return const MealImageGatewayResponse(statusCode: 200, body: '{}');
          },
        );
        await expectLater(
          service.analyze(
            XFile.fromData(
              Uint8List.fromList([0xff, 0xd8, 0xff]),
              mimeType: 'image/jpeg',
            ),
          ),
          throwsA(
            isA<MealImageAnalysisException>().having(
              (error) => error.failure,
              'failure',
              MealImageAnalysisFailure.authenticationRequired,
            ),
          ),
        );
        expect(uploaded, isFalse);
      },
    );

    test('retries once with a stable idempotency key', () async {
      final keys = <String>[];
      var calls = 0;
      final service = MealImageAnalysisService(
        endpoint: 'https://example.test/functions/v1/analyze-meal',
        accessToken: () => 'session',
        gatewayPost: ({required uri, required headers, required body}) async {
          keys.add(headers['x-idempotency-key']!);
          if (++calls == 1) {
            return const MealImageGatewayResponse(statusCode: 503, body: '{}');
          }
          return const MealImageGatewayResponse(
            statusCode: 200,
            body: '{"schema_version":1,"request_id":"r","candidates":[]}',
          );
        },
      );
      await service.analyze(
        XFile.fromData(
          Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
          mimeType: 'image/png',
        ),
      );
      expect(calls, 2);
      expect(keys.toSet(), hasLength(1));
    });

    test('maps a paid Boost boundary to a dedicated failure', () async {
      final service = MealImageAnalysisService(
        endpoint: 'https://example.test/functions/v1/analyze-meal',
        accessToken: () => 'session',
        gatewayPost: ({required uri, required headers, required body}) async {
          return const MealImageGatewayResponse(
            statusCode: 402,
            body: '{"error":"ai_boost_required"}',
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
            (error) => error.failure,
            'failure',
            MealImageAnalysisFailure.boostRequired,
          ),
        ),
      );
    });

    test('rejects malformed or provenance-free responses', () {
      for (final body in <String>[
        '{}',
        '{"schema_version":1,"request_id":"r","candidates":[{"name":"rice","confidence":2,"evidence":""}]}',
        '{"schema_version":1,"request_id":"r","candidates":[{"name":"rice","confidence":0.9,"evidence":"","provenance":{"identification_provider":"x","model_revision":"x","nutrition_resolution":"verified_food_record"}}]}',
      ]) {
        expect(
          () => parseMealImageResponse(body),
          throwsA(isA<MealImageAnalysisException>()),
        );
      }
    });

    test('five locales expose human-safe errors', () {
      const error = MealImageAnalysisException(
        MealImageAnalysisFailure.rateLimited,
      );
      for (final locale in ['en', 'ar', 'fr', 'es', 'tr']) {
        expect(error.message(arabic: false, languageCode: locale), isNotEmpty);
      }
    });
  });

  test('voice capture remains locale-aware and bounded', () {
    final source = File(
      'lib/features/nutrition/services/meal_voice_input_service.dart',
    ).readAsStringSync();
    expect(source, contains('SpeechToText'));
    expect(source, contains('onError:'));
    expect(source, contains('listenFor: const Duration(seconds: 30)'));
    expect(source, contains('pauseFor: const Duration(seconds: 4)'));
  });

  test('edge gateway authenticates and constrains provider output', () {
    final gateway = File(
      'supabase/functions/analyze-meal/index.ts',
    ).readAsStringSync();
    expect(gateway, contains('auth.auth.getUser()'));
    expect(gateway, contains('BIL_MEAL_VISION_GATEWAY_SECRET'));
    expect(gateway, contains('nutrition_resolution'));
    expect(gateway, contains('request_id: idempotencyKey'));
    expect(gateway, contains('AbortController'));
    expect(gateway, contains("error: 'ai_boost_required'"));
  });
}
