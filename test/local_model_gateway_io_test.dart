import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default build skips nonexistent emulator model without delay', () {
    expect(const LlamaCppLocalGateway().endpoint, isEmpty);
  });

  test('loopback local model works without a network bearer secret', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/v1/chat/completions');
      expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['messages'], isA<List>());
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'answer': 'Grounded local answer',
                  'action': null,
                }),
              },
            },
          ],
        }),
      );
      await request.response.close();
    });

    final gateway = LlamaCppLocalGateway(
      endpoint: 'http://127.0.0.1:${server.port}',
    );
    final result = await gateway.answer(
      question: 'How am I doing?',
      locale: 'en',
      context: _emptyContext(),
    );

    expect(result.answer?.text, 'Grounded local answer');
    expect(result.answer?.action, isNull);
  });

  test('remote model without a strong secret fails closed', () async {
    const gateway = LlamaCppLocalGateway(endpoint: 'https://example.com');
    final result = await gateway.answer(
      question: 'test',
      locale: 'en',
      context: _emptyContext(),
    );
    expect(result.answer, isNull);
  });

  test(
    'Edge Function error codes are extracted without alias normalization',
    () {
      expect(
        functionErrorCodeFromDetails(const {'error': 'ai_usage_exhausted'}),
        'ai_usage_exhausted',
      );
      expect(
        functionErrorCodeFromDetails('{"error":"ai_usage_exhausted"}'),
        'ai_usage_exhausted',
      );
      expect(
        functionErrorCodeFromDetails(const {'error': 'ai_usage_exhausted '}),
        'ai_usage_exhausted ',
      );
      expect(
        functionErrorCodeFromDetails('{"error":" ai_usage_exhausted"}'),
        ' ai_usage_exhausted',
      );
      expect(functionErrorCodeFromDetails(const {'error': 402}), isNull);
      expect(functionErrorCodeFromDetails('{"error":402}'), isNull);
      expect(functionErrorCodeFromDetails('not-json'), isNull);
    },
  );
}

CoachContextSnapshot _emptyContext() => CoachContextSnapshot(
  generatedAt: DateTime.utc(2026, 8, 10),
  profile: const <String, Object?>{},
  weights: const <CoachWeightPoint>[],
  nutritionDays: const <CoachNutritionDay>[],
  waterHistory: const <Map<String, Object?>>[],
  computedHealth: const <String, Object?>{},
);
