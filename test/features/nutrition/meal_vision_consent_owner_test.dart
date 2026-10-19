import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_consent_gate.dart';
import 'package:body_intelligence_log/features/settings/sharing_privacy_settings_page.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

Map<String, Object?> _session(String owner) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
    'refresh_token': 'synthetic-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'email': 'vision-fixture@example.invalid',
      'aud': 'authenticated',
      'created_at': '2026-10-19T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    },
  };
}

class _Scenario {
  final receipts = <String, bool>{};
  final paths = <String>[];
  final transportErrors = <Object>[];
  final writes = <({String owner, bool granted})>[];
  Completer<http.Response>? pendingRead;
  bool holdRead = false;
  bool persistWrites = true;
  bool holdWrite = false;
  Completer<http.Response>? pendingWrite;
  final writeStarted = Completer<void>();
  bool? result;
  final completed = Completer<void>();
  late Supabase sdk;
  SupabaseClient get client => sdk.client;

  String _owner(http.Request request) {
    final token = request.headers['authorization']!.split(' ').last;
    return (jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(token.split('.')[1])),
              ),
            )
            as Map)['sub']
        as String;
  }

  http.Response response(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> request(http.Request request) async {
    paths.add(request.url.path);
    if (request.url.path == '/auth/v1/user') {
      return response(_session(_owner(request))['user']!);
    }
    if (request.url.path == '/auth/v1/logout') return response({});
    if (request.url.path == '/rest/v1/bil_consent_receipts') {
      if (holdRead) {
        holdRead = false;
        pendingRead = Completer<http.Response>();
        return pendingRead!.future;
      }
      final value = receipts[_owner(request)];
      return response(
        value == null
            ? []
            : [
                {'granted': value, 'policy_version': '1'},
              ],
      );
    }
    if (request.url.path == '/rest/v1/rpc/bil_record_consent') {
      final body = jsonDecode(request.body) as Map;
      expectSync(body['p_purpose'], mealVisionConsentPurpose);
      expectSync(body['p_policy_version'], mealVisionConsentPolicyVersion);
      final owner = _owner(request), granted = body['p_granted'] as bool;
      writes.add((owner: owner, granted: granted));
      if (persistWrites) receipts[owner] = granted;
      if (holdWrite) {
        holdWrite = false;
        pendingWrite = Completer<http.Response>();
        writeStarted.complete();
        return pendingWrite!.future;
      }
      return response({});
    }
    throw StateError('Unexpected external request: ${request.url.path}');
  }

  Future<void> initialize(WidgetTester tester, {bool open = true}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      sdk = await Supabase.initialize(
        url: 'https://vision-consent.invalid',
        publishableKey: 'synthetic-fixture-key',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: CommunityOwnerHttpClient(
          MockClient((request) async {
            late http.Response result;
            try {
              result = await this.request(request);
            } catch (error) {
              transportErrors.add(error);
              rethrow;
            }
            return http.Response.bytes(
              result.bodyBytes,
              result.statusCode,
              headers: result.headers,
              request: request,
            );
          }),
        ),
      );
      await client.auth.recoverSession(jsonEncode(_session(_a)));
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await sdk.dispose();
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await ensureMealVisionConsent(context);
                completed.complete();
              },
              child: const Text('Open photo consent'),
            ),
          ),
        ),
      ),
    );
    if (open) {
      await tester.tap(find.text('Open photo consent'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.runAsync(
      () => completed.future.timeout(const Duration(seconds: 3)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showPrivacy(WidgetTester tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await database.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SharingPrivacySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('meal-vision-ai-consent')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> switchTo(WidgetTester tester, String owner) async {
    await tester.runAsync(() async {
      await client.auth.recoverSession(jsonEncode(_session(owner)));
    });
    await tester.pump();
  }
}

void main() {
  testWidgets('privacy setting does not retain the previous account consent', (
    tester,
  ) async {
    final s = _Scenario()
      ..receipts[_a] = true
      ..receipts[_b] = false;
    await s.initialize(tester, open: false);
    await s.showPrivacy(tester);
    SwitchListTile tile() => tester.widget<SwitchListTile>(
      find.byKey(const Key('meal-vision-ai-consent')),
    );
    expect(tile().value, isTrue);
    await s.switchTo(tester, _b);
    await tester.pumpAndSettle();
    expect(tile().value, isFalse);
    expect(s.writes, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'failed withdrawal remains visibly enabled and offers failure feedback',
    (tester) async {
      final s = _Scenario()
        ..receipts[_a] = true
        ..persistWrites = false;
      await s.initialize(tester, open: false);
      await s.showPrivacy(tester);
      await tester.tap(find.byKey(const Key('meal-vision-ai-consent')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('meal-vision-ai-consent')),
            )
            .value,
        isTrue,
      );
      expect(find.text('Could not save changes.'), findsOneWidget);
      expect(s.writes, [(owner: _a, granted: false)]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('withdrawal verifies the same current server receipt', (
    tester,
  ) async {
    final s = _Scenario()..receipts[_a] = true;
    await s.initialize(tester, open: false);
    expect(await tester.runAsync(revokeMealVisionConsent), isTrue);
    expect(s.receipts[_a], isFalse);
    expect(s.writes, [(owner: _a, granted: false)]);
  });

  testWidgets('withdrawal cannot claim success when the server kept Allow', (
    tester,
  ) async {
    final s = _Scenario()
      ..receipts[_a] = true
      ..persistWrites = false;
    await s.initialize(tester, open: false);
    expect(await tester.runAsync(revokeMealVisionConsent), isFalse);
    expect(s.receipts[_a], isTrue);
  });

  testWidgets(
    'withdrawal finishing after account change cannot change the successor receipt',
    (tester) async {
      final s = _Scenario()
        ..receipts[_a] = true
        ..receipts[_b] = true
        ..holdWrite = true;
      await s.initialize(tester, open: false);
      await tester.pumpAndSettle();
      final pending = revokeMealVisionConsent();
      final clock = Stopwatch()..start();
      while (!s.writeStarted.isCompleted &&
          clock.elapsed < const Duration(seconds: 3)) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
      }
      expect(
        s.writeStarted.isCompleted,
        isTrue,
        reason:
            'paths=${s.paths}, writes=${s.writes}, current=${s.client.auth.currentUser?.id}, transportErrors=${s.transportErrors}',
      );
      expect(s.pendingWrite, isNotNull);
      await s.switchTo(tester, _b);
      s.pendingWrite!.complete(s.response({}));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () => pending.timeout(const Duration(seconds: 3)),
        ),
        isFalse,
      );
      expect(s.writes, [(owner: _a, granted: false)]);
      expect(s.receipts[_b], isTrue);
    },
  );

  testWidgets(
    'a consent receipt delivered after account change cannot authorize photo upload',
    (tester) async {
      final s = _Scenario()..holdRead = true;
      await s.initialize(tester);
      expect(s.pendingRead, isNotNull);
      await s.switchTo(tester, _b);
      s.pendingRead!.complete(
        s.response([
          {'granted': true, 'policy_version': '1'},
        ]),
      );
      await tester.pumpAndSettle();
      await s.finish(tester);
      expect(s.result, isFalse);
      expect(s.writes, isEmpty);
    },
  );

  for (final roundTrip in [false, true]) {
    testWidgets(
      'Allow belongs to the account that opened the dialog; ABA=$roundTrip',
      (tester) async {
        final s = _Scenario();
        await s.initialize(tester);
        expect(
          find.byKey(const Key('meal-vision-consent-accept')),
          findsOneWidget,
        );
        await s.switchTo(tester, _b);
        if (roundTrip) await s.switchTo(tester, _a);
        await tester.tap(find.byKey(const Key('meal-vision-consent-accept')));
        await tester.pumpAndSettle();
        await s.finish(tester);
        expect(s.result, isFalse);
        expect(s.writes, isEmpty);
      },
    );
  }

  testWidgets(
    'unchanged owner explicitly allows and receives a persisted current receipt',
    (tester) async {
      final s = _Scenario();
      await s.initialize(tester);
      await tester.tap(find.byKey(const Key('meal-vision-consent-accept')));
      await tester.pumpAndSettle();
      await s.finish(tester);
      expect(s.result, isTrue);
      expect(s.writes, [(owner: _a, granted: true)]);
      expect(s.receipts[_a], isTrue);
    },
  );

  testWidgets('decline never authorizes image analysis', (tester) async {
    final s = _Scenario();
    await s.initialize(tester);
    await tester.tap(find.byKey(const Key('meal-vision-consent-decline')));
    await tester.pumpAndSettle();
    await s.finish(tester);
    expect(s.result, isFalse);
    expect(s.writes, [(owner: _a, granted: false)]);
  });

  testWidgets('an unpersisted Allow response never authorizes image analysis', (
    tester,
  ) async {
    final s = _Scenario()..persistWrites = false;
    await s.initialize(tester);
    await tester.tap(find.byKey(const Key('meal-vision-consent-accept')));
    await tester.pumpAndSettle();
    await s.finish(tester);
    expect(s.result, isFalse);
    expect(s.writes, [(owner: _a, granted: true)]);
  });

  testWidgets(
    'account change during consent persistence cancels the continuation',
    (tester) async {
      final s = _Scenario()..holdWrite = true;
      await s.initialize(tester);
      await tester.tap(find.byKey(const Key('meal-vision-consent-accept')));
      await tester.pumpAndSettle();
      expect(s.pendingWrite, isNotNull);
      await s.switchTo(tester, _b);
      s.pendingWrite!.complete(s.response({}));
      await s.finish(tester);
      expect(s.result, isFalse);
      expect(s.writes, [(owner: _a, granted: true)]);
      expect(s.receipts[_b], isNull);
    },
  );
}
