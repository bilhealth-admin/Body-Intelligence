import 'dart:async';
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

const owner = '00000000-0000-4000-8000-000000000001';
Future<void> signIn(String id) =>
    Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'fixture-token',
        'token_type': 'bearer',
        'user': {
          'id': id,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bil/play_integrity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late BilPlayIntegrityService service;
  var status = 403, posts = 0, dialogCode = 3, prepares = 0;
  late Map<String, Object?> body;
  final calls = <String>[];
  final released = <String>[];
  String? nativeHash;
  Completer<void>? heldToken;
  Completer<void>? tokenEntered;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    body = {
      'allowed': false,
      'trustworthy': false,
      'mode': 'enforce',
      'reason': 'license_unlicensed',
      'grant': null,
    };
    status = 403;
    posts = 0;
    prepares = 0;
    calls.clear();
    released.clear();
    nativeHash = null;
    heldToken = null;
    tokenEntered = null;
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
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await signIn(owner);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'prepare':
          prepares++;
          return true;
        case 'requestToken':
          nativeHash = (call.arguments as Map)['requestHash'] as String;
          tokenEntered?.complete();
          await heldToken?.future;
          return 'encrypted-fixture';
        case 'releaseToken':
          released.add((call.arguments as Map)['handle'] as String);
          return null;
        case 'getLicensed':
          return dialogCode;
      }
      throw StateError('Unexpected native method');
    });
    service = BilPlayIntegrityService.forTesting(
      cloudProjectNumber: 1041595138122,
    );
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  Future<BilIntegrityException> denied() async {
    try {
      await service.authorize(
        action: 'store.purchase_readiness',
        payloadDigest: 'a' * 64,
        retainLicenseRecovery: true,
      );
      fail('403 must not return a grant');
    } on BilIntegrityException catch (e) {
      return e;
    }
  }

  test(
    'actual HTTP403 FunctionException details preserve only licensing denial',
    () async {
      final error = await denied();
      expect(error.code, 'license_unlicensed');
      expect(error.recoveryOwner, owner);
      expect(error.recoveryHandle, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(posts, 1);
      expect(calls, isNot(contains('getLicensed')));
      expect(error.toString(), 'BilIntegrityException(license_unlicensed)');
    },
  );
  for (final variant in [
    'wrong_reason',
    'joined_reasons',
    'string_body',
    'allowed',
    'trustworthy',
    'mode',
    'status',
  ]) {
    test('nonallowlisted non-2xx $variant gets no recovery handle', () async {
      switch (variant) {
        case 'wrong_reason':
          body['reason'] = 'raw-private-failure';
          break;
        case 'joined_reasons':
          body['reason'] = 'license_unlicensed,device_integrity_missing';
          break;
        case 'string_body':
          body = {'message': 'license_unlicensed'};
          break;
        case 'allowed':
          body['allowed'] = true;
          break;
        case 'trustworthy':
          body['trustworthy'] = true;
          break;
        case 'mode':
          body['mode'] = 'observe';
          break;
        case 'status':
          status = 503;
          break;
      }
      final error = await denied();
      expect(error.code, 'integrity_backend_unavailable');
      expect(error.recoveryHandle, isNull);
      expect(calls, contains('releaseToken'));
      expect(calls, isNot(contains('getLicensed')));
    });
  }
  for (final code in [0, 1, 2, 3]) {
    test(
      'Google result $code is only a recovery interaction; next token freshly prepared',
      () async {
        dialogCode = code;
        final error = await denied();
        expect(await service.recoverLicense(error), code == 3);
        expect(prepares, 1);
        await denied();
        expect(prepares, 2);
        expect(posts, 2); // still denied: dialog never becomes a grant/benefit
      },
    );
  }
  test(
    'A B A while native token held cannot send original-attempt HTTP',
    () async {
      heldToken = Completer<void>();
      tokenEntered = Completer<void>();
      final pending = service.authorize(
        action: 'store.purchase_readiness',
        payloadDigest: 'a' * 64,
        retainLicenseRecovery: true,
      );
      await tokenEntered!.future;
      await signIn('00000000-0000-4000-8000-000000000002');
      await signIn(owner);
      heldToken!.complete();
      await expectLater(pending, throwsA(anything));
      expect(posts, 0);
      expect(released, contains(nativeHash));
    },
  );
}
