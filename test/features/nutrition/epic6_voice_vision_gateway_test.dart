import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('authenticated meal-image gateway', () {
    test('sends only image evidence and parses strict candidates', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;
      final service = MealImageAnalysisService(
        endpoint: 'https://example.test/functions/v1/analyze-meal',
        accessToken: () => 'signed-session',
        requestedLocale: 'ar_EG',
        gatewayPost: ({required uri, required headers, required body}) async {
          capturedUri = uri;
          capturedHeaders = headers;
          capturedBody = jsonDecode(body) as Map<String, dynamic>;
          return const MealImageGatewayResponse(
            statusCode: 200,
            body:
                '{"schema_version":1,"candidates":[{"name":"دجاج","confidence":0.91,"evidence":"visible grilled pieces"}],"notice":"Confirm visible foods."}',
          );
        },
      );

      final result = await service.analyze(
        XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/jpeg',
          name: 'meal.jpg',
        ),
      );

      expect(capturedUri?.scheme, 'https');
      expect(
        capturedHeaders?[HttpHeaders.authorizationHeader],
        'Bearer signed-session',
      );
      expect(capturedBody?['schema_version'], 1);
      expect(capturedBody?['requested_locale'], 'ar');
      expect(capturedBody?['mime_type'], 'image/jpeg');
      expect(capturedBody, isNot(contains('calories')));
      expect(capturedBody, isNot(contains('nutrition')));
      expect(result.candidates.single.name, 'دجاج');
      expect(result.candidates.single.confidence, 0.91);
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
              Uint8List.fromList([1]),
              mimeType: 'image/jpeg',
              name: 'meal.jpg',
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

    test('rejects malformed, oversized, or invented candidate responses', () {
      for (final body in [
        '{}',
        '{"schema_version":1,"candidates":[{"name":"rice","confidence":2,"evidence":""}]}',
        '{"schema_version":1,"candidates":[{"name":"","confidence":0.9,"evidence":""}]}',
      ]) {
        expect(
          () => parseMealImageResponse(body),
          throwsA(isA<MealImageAnalysisException>()),
        );
      }
    });
  });

  test('voice capture is live, locale-aware, bounded, and honest', () {
    final source = File(
      'lib/features/nutrition/services/meal_voice_input_service.dart',
    ).readAsStringSync();

    expect(source, contains('SpeechToText'));
    expect(source, contains('onError:'));
    expect(source, contains('StatefulBuilder'));
    expect(source, contains('listenFor: const Duration(seconds: 30)'));
    expect(source, contains('pauseFor: const Duration(seconds: 4)'));
    expect(source, contains('selectedLocale == null'));
    expect(source, contains('recognizedWords'));
  });

  test('edge gateway authenticates and constrains provider output', () {
    final gateway = File(
      'supabase/functions/analyze-meal/index.ts',
    ).readAsStringSync();
    final actions = File(
      'lib/features/daily_log/daily_log_page_actions.dart',
    ).readAsStringSync();

    expect(gateway, contains('auth.auth.getUser()'));
    expect(gateway, contains('BIL_MEAL_VISION_GATEWAY_SECRET'));
    expect(gateway, contains('allowedMimeTypes'));
    expect(gateway, contains('no_nutrition_estimation: true'));
    expect(gateway, contains('identify_visible_food_only: true'));
    expect(gateway, contains('maximum_candidates: 8'));
    expect(gateway, contains('AbortController'));
    expect(gateway, contains('invalid_vision_response'));
    expect(actions, contains('MealImageAnalysisException'));
    expect(actions, contains('error.message(arabic: _arabic)'));
    expect(actions, isNot(contains('Text(error.toString())')));
  });
}
