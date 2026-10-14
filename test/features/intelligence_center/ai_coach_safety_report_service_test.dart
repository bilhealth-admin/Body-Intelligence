import 'dart:convert';

import 'package:body_intelligence_log/features/intelligence_center/services/ai_coach_safety_report_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> _session() {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-ai-report-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': _owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-13T00:00:00Z',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends only the confirmed answer metadata to the safety RPC', () async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final transport = MockClient((request) async {
      requests.add(request);
      expect(
        request.url.path,
        '/rest/v1/rpc/bil_submit_ai_coach_safety_report_v1',
      );
      return http.Response(
        jsonEncode({
          'report_id': '00000000-0000-4000-8000-000000000201',
          'status': 'open',
          'duplicate': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final client = SupabaseClient(
      'https://ai-report-test.invalid',
      'synthetic-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: transport,
    );
    await client.auth.recoverSession(jsonEncode(_session()));

    try {
      final receipt = await AiCoachSafetyReportService(clientOverride: client)
          .submit(
            responseId: 'coach-response-0001',
            answerText: 'Only this exact answer is submitted.',
            reason: 'other',
            explicitConsentAccepted: true,
            userNote: 'Please review this part.',
            locale: 'EN-us',
            runtime: CoachAnswerRuntime.onDevice,
          );
      expect(receipt.reportId, '00000000-0000-4000-8000-000000000201');
      expect(receipt.duplicate, isFalse);
      expect(requests, hasLength(1));
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'p_response_id',
        'p_answer_text',
        'p_reason',
        'p_user_note',
        'p_consent_confirmed',
        'p_locale',
        'p_runtime',
      });
      expect(body['p_answer_text'], 'Only this exact answer is submitted.');
      expect(body['p_reason'], 'other');
      expect(body['p_user_note'], 'Please review this part.');
      expect(body['p_consent_confirmed'], isTrue);
      expect(body['p_locale'], 'en-us');
      expect(body['p_runtime'], 'on_device');
      expect(requests.single.headers['authorization'], startsWith('Bearer '));
    } finally {
      await client.dispose();
      transport.close();
    }
  });

  test(
    'rejects unsupported reason, missing consent, and invalid data',
    () async {
      SharedPreferences.setMockInitialValues({});
      var requestCount = 0;
      final transport = MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200, request: request);
      });
      final client = SupabaseClient(
        'https://ai-report-test.invalid',
        'synthetic-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: transport,
      );
      await client.auth.recoverSession(jsonEncode(_session()));
      try {
        await expectLater(
          AiCoachSafetyReportService(clientOverride: client).submit(
            responseId: 'coach-response-unsupported-reason',
            answerText: 'A non-empty synthetic answer.',
            reason: 'privacy',
            explicitConsentAccepted: true,
            locale: 'en',
            runtime: CoachAnswerRuntime.localFallback,
          ),
          throwsFormatException,
        );
        await expectLater(
          AiCoachSafetyReportService(clientOverride: client).submit(
            responseId: 'coach-response-no-consent',
            answerText: 'A non-empty synthetic answer.',
            reason: 'unsafe',
            explicitConsentAccepted: false,
            locale: 'en',
            runtime: CoachAnswerRuntime.localFallback,
          ),
          throwsFormatException,
        );
        await expectLater(
          AiCoachSafetyReportService(clientOverride: client).submit(
            responseId: 'coach-response-0002',
            answerText: List<String>.filled(12001, 'x').join(),
            reason: 'unsafe',
            explicitConsentAccepted: true,
            locale: 'en',
            runtime: CoachAnswerRuntime.localFallback,
          ),
          throwsFormatException,
        );
        expect(requestCount, 0);
      } finally {
        await client.dispose();
        transport.close();
      }
    },
  );
}
