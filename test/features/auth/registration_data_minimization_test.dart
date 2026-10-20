import 'dart:convert';

import 'package:body_intelligence_log/features/auth/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final displayName in ['', '   ', '  Q  ']) {
    test('new signup sends only voluntarily supplied profile metadata '
        'for display name "$displayName"', () async {
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(request.url.origin, 'https://signup-fixture.invalid');
        expect(request.url.path, '/auth/v1/signup');
        return http.Response(
          jsonEncode({
            'id': 'eec958e8-b3ee-4b95-923b-9937a6774d16',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'member@example.invalid',
            'created_at': '2026-10-20T00:00:00Z',
            'app_metadata': {
              'provider': 'email',
              'providers': ['email'],
            },
            'user_metadata': {},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'https://signup-fixture.invalid',
        'synthetic-public-key',
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: transport,
      );
      addTearDown(client.dispose);

      final outcome = await SupabaseAuthService(client).signUp(
        email: 'member@example.invalid',
        password: 'Synthetic123!',
        fullName: displayName,
      );

      expect(outcome, BilAuthOutcome.confirmationRequired);
      expect(requests, hasLength(1));
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['email'], 'member@example.invalid');
      expect(body['password'], 'Synthetic123!');
      expect(body, isNot(contains('phone')));
      expect(
        body['data'],
        displayName.trim().isEmpty ? isEmpty : equals({'full_name': 'Q'}),
      );
      // A removed phone field must not leave a placeholder, country code or
      // hidden phone value in the real authentication request.
      expect(body['data'], isNot(contains('phone')));
    });
  }
}
