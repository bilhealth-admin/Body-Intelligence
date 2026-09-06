import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only exact loopback HTTP endpoints qualify as local', () {
    for (final endpoint in const <String>[
      'http://localhost:8080',
      'https://localhost',
      'http://127.0.0.1:1234',
      'http://[::1]:9090',
    ]) {
      expect(isLoopbackLocalModelEndpoint(endpoint), isTrue, reason: endpoint);
    }
    for (final endpoint in const <String>[
      '',
      'file:///tmp/model',
      'http://localhost.example.com',
      'http://127.0.0.2:1234',
      'http://192.168.1.8:8080',
      'https://example.com',
    ]) {
      expect(isLoopbackLocalModelEndpoint(endpoint), isFalse, reason: endpoint);
    }
  });

  test('remote URL with a strong key still uses consent-gated cloud', () async {
    final cloud = _CloudSpy();
    final result =
        await LlamaCppLocalGateway(
          endpoint: 'https://example.com/private-model',
          apiKey: 'x' * 64,
          cloudAccess: cloud,
        ).answer(
          question: 'Give me a general tip',
          locale: 'en',
          context: CoachContextSnapshot.empty(
            generatedAt: DateTime.utc(2026, 9, 5),
          ),
        );

    expect(cloud.consentReads, 1);
    expect(cloud.invocations, 1);
    expect(result.answer?.text, 'cloud');
    expect(result.answer?.processedOnDevice, isFalse);
  });

  test('loopback request stays local and never runs cloud preflight', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({'answer': 'local', 'action': null}),
              },
            },
          ],
        }),
      );
      await request.response.close();
    });
    final cloud = _CloudSpy();
    final result =
        await LlamaCppLocalGateway(
          endpoint: 'http://127.0.0.1:${server.port}',
          cloudAccess: cloud,
        ).answer(
          question: 'hello',
          locale: 'en',
          context: CoachContextSnapshot.empty(
            generatedAt: DateTime.utc(2026, 9, 5),
          ),
        );

    expect(result.answer?.text, 'local');
    expect(cloud.consentReads, 0);
    expect(cloud.invocations, 0);
  });
}

final class _CloudSpy implements CoachCloudAccess {
  int consentReads = 0;
  int invocations = 0;

  @override
  bool get hasAuthenticatedSession => true;

  @override
  Future<Object?> readRemoteAiConsent() async {
    consentReads++;
    return const <String, Object?>{'granted': true, 'policy_version': '2'};
  }

  @override
  Future<CoachCloudFunctionResponse> invokeCoach(
    Map<String, Object?> body,
  ) async {
    invocations++;
    return const CoachCloudFunctionResponse(
      status: 200,
      data: <String, Object?>{'reply': 'cloud'},
    );
  }
}
