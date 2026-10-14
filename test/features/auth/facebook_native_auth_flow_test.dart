import 'package:body_intelligence_log/features/auth/supabase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final launched in [true, false]) {
      test(
        '$platform Facebook uses external Supabase PKCE OAuth: $launched',
        () async {
          final binding = TestWidgetsFlutterBinding.ensureInitialized();
          const channel = MethodChannel('plugins.flutter.io/url_launcher');
          final calls = <MethodCall>[];
          binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
            call,
          ) async {
            calls.add(call);
            return launched;
          });
          final storage = _MemoryPkceStorage();
          final client = SupabaseClient(
            'https://example.supabase.co',
            'test-publishable-key',
            authOptions: AuthClientOptions(
              autoRefreshToken: false,
              pkceAsyncStorage: storage,
            ),
          );
          final service = SupabaseAuthService(client);
          final previousPlatform = debugDefaultTargetPlatformOverride;
          try {
            debugDefaultTargetPlatformOverride = platform;
            expect(
              SupabaseAuthService.oauthLaunchModeFor(
                OAuthProvider.facebook,
                isWeb: false,
                platform: platform,
              ),
              LaunchMode.externalApplication,
            );
            expect(
              await service.signInWithOAuth(OAuthProvider.facebook),
              launched,
            );
            final launch = calls.singleWhere((call) => call.method == 'launch');
            final arguments = Map<String, dynamic>.from(
              launch.arguments as Map,
            );
            final url = Uri.parse(arguments['url'] as String);
            expect(url.host, 'example.supabase.co');
            expect(url.path, '/auth/v1/authorize');
            expect(url.queryParameters['provider'], 'facebook');
            expect(
              url.queryParameters['redirect_to'],
              SupabaseAuthService.oauthRedirectUri,
            );
            expect(url.queryParameters['code_challenge'], isNotEmpty);
            expect(
              url.queryParameters['code_challenge_method']?.toLowerCase(),
              's256',
            );
            expect(url.queryParameters.keys, isNot(contains('access_token')));
            expect(url.queryParameters.keys, isNot(contains('id_token')));
            expect(arguments['useWebView'], isFalse);
            expect(storage.values, isNotEmpty);
          } finally {
            debugDefaultTargetPlatformOverride = previousPlatform;
            binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              null,
            );
            await client.dispose();
          }
        },
      );
    }
  }
}

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}
