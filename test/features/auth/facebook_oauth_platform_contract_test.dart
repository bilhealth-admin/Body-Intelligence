import 'dart:io';

import 'package:body_intelligence_log/features/auth/facebook_oauth_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bil/facebook_oauth_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('trusted Supabase Facebook URL is sent to the native bridge', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final uri = Uri.https(
      'tgmanzhqulksykhslrzb.supabase.co',
      '/auth/v1/authorize',
      <String, String>{
        'provider': 'facebook',
        'redirect_to': 'https://www.bilhealth.com/auth/callback',
      },
    );

    final opened = await const BilFacebookOAuthLauncher(
      methodChannel: channel,
    ).open(uri);

    expect(opened, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'openCustomTab');
    expect(calls.single.arguments, <String, String>{'url': uri.toString()});
  });

  test('untrusted Facebook authorization URLs fail before native launch', () {
    const redirect =
        'redirect_to=https%3A%2F%2Fwww.bilhealth.com%2Fauth%2Fcallback';
    final invalidUris = <Uri>[
      Uri.parse(
        'http://tgmanzhqulksykhslrzb.supabase.co/auth/v1/authorize?provider=facebook&$redirect',
      ),
      Uri.parse(
        'https://tgmanzhqulksykhslrzb.supabase.co.evil.example/auth/v1/authorize?provider=facebook&$redirect',
      ),
      Uri.parse(
        'https://tgmanzhqulksykhslrzb.supabase.co:444/auth/v1/authorize?provider=facebook&$redirect',
      ),
      Uri.parse(
        'https://tgmanzhqulksykhslrzb.supabase.co/auth/v1/token?provider=facebook&$redirect',
      ),
      Uri.parse(
        'https://tgmanzhqulksykhslrzb.supabase.co/auth/v1/authorize?provider=google&$redirect',
      ),
      Uri.parse(
        'https://tgmanzhqulksykhslrzb.supabase.co/auth/v1/authorize?provider=facebook&redirect_to=https%3A%2F%2Fevil.example',
      ),
      Uri.parse(
        'https://user@tgmanzhqulksykhslrzb.supabase.co/auth/v1/authorize?provider=facebook&$redirect',
      ),
      Uri.parse(
        'https://tgmanzhqulksykhslrzb.supabase.co/auth/v1/authorize?provider=facebook&$redirect#fragment',
      ),
      Uri.parse(
        'https://tgmanzhqulksykhslrzb.supabase.co/auth/v1/authorize?provider=facebook&provider=google&$redirect',
      ),
      Uri.parse(
        'https://tgmanzhqulksykhslrzb.supabase.co/auth/v1/authorize?provider=facebook&$redirect&redirect_to=https%3A%2F%2Fevil.example',
      ),
    ];

    for (final uri in invalidUris) {
      expect(
        const BilFacebookOAuthLauncher(methodChannel: channel).open(uri),
        throwsA(isA<AuthException>()),
        reason: uri.toString(),
      );
    }
  });

  for (final result in <bool?>[false, null]) {
    test(
      'unavailable Custom Tabs result $result is not a successful launch',
      () async {
        messenger.setMockMethodCallHandler(channel, (_) async => result);
        final opened =
            await const BilFacebookOAuthLauncher(methodChannel: channel).open(
              Uri.https(
                'tgmanzhqulksykhslrzb.supabase.co',
                '/auth/v1/authorize',
                <String, String>{
                  'provider': 'facebook',
                  'redirect_to': 'https://www.bilhealth.com/auth/callback',
                },
              ),
            );
        expect(opened, isFalse);
      },
    );
  }

  test('Android bridge is strict Custom Tabs with no WebView fallback', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFacebookOAuthBridge.kt',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(bridge, contains('CustomTabsClient.getPackageName'));
    expect(bridge, contains('CustomTabsIntent.Builder()'));
    expect(bridge, contains('customTab.intent.setPackage(providerPackage)'));
    expect(bridge, contains('customTab.launchUrl(activity, uri)'));
    expect(bridge, contains('getQueryParameters("provider")'));
    expect(bridge, contains('getQueryParameters("redirect_to")'));
    expect(bridge, isNot(contains('WebViewActivity')));
    expect(activity, contains('BILFacebookOAuthBridge(this,'));
    expect(activity, contains('facebookOAuthBridge?.dispose()'));
    expect(
      manifest,
      contains('android.support.customtabs.action.CustomTabsService'),
    );
    expect(gradle, contains('androidx.browser:browser:1.9.0'));
  });
}
