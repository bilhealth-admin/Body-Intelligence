import 'dart:convert';
import 'package:body_intelligence_log/app/security/bil_integrity_exception.dart';
import 'package:body_intelligence_log/app/security/bil_play_integrity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'actual FunctionsClient HTTP403 retains exact license_unlicensed denial',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      var posts = 0;
      await Supabase.initialize(
        url: 'https://fixture.invalid',
        publishableKey: 'fixture-key',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/functions/v1/play-integrity');
          posts++;
          return http.Response(
            jsonEncode({
              'allowed': false,
              'trustworthy': false,
              'mode': 'enforce',
              'reason': 'license_unlicensed',
              'grant': null,
              'verdicts': {
                'licensing': 'UNLICENSED',
                'app': 'PLAY_RECOGNIZED',
                'device': [
                  'MEETS_BASIC_INTEGRITY',
                  'MEETS_DEVICE_INTEGRITY',
                  'MEETS_STRONG_INTEGRITY',
                ],
              },
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await Supabase.instance.client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'fixture-token',
          'token_type': 'bearer',
          'user': {
            'id': '00000000-0000-4000-8000-000000000001',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      const channel = MethodChannel('bil/play_integrity');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepare') return true;
        if (call.method == 'requestToken') return 'encrypted-fixture';
        if (call.method == 'releaseToken') return null;
        throw StateError('No dialog/payment expected');
      });
      try {
        final service = BilPlayIntegrityService.forTesting(
          cloudProjectNumber: 1041595138122,
        );
        await expectLater(
          service.authorize(
            action: 'store.verify_ai_boost',
            payloadDigest: 'a' * 64,
          ),
          throwsA(
            isA<BilIntegrityException>().having(
              (e) => e.code,
              'code',
              'license_unlicensed',
            ),
          ),
        );
        expect(posts, 1);
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        await Supabase.instance.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
