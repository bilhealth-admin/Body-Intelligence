import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_estimate_visit.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_vision_estimate_consent.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const a = '11111111-1111-4111-8111-111111111111',
    b = '22222222-2222-4222-8222-222222222222';
Map<String, Object?> session(String owner) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
    'refresh_token': 'synthetic',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    },
  };
}

class Scenario {
  final receipts = <String, bool>{'meal_vision_ai': true};
  final reads = <String>[];
  final writes = <Map<String, dynamic>>[];
  Completer<http.Response>? hold;
  final entered = Completer<void>();
  bool fail = false;
  late Supabase sdk;
  http.Response response(http.Request request, Object body, int status) =>
      http.Response(
        jsonEncode(body),
        status,
        request: request,
        headers: {'content-type': 'application/json'},
      );
  Future<void> init(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    await t.runAsync(() async {
      sdk = await Supabase.initialize(
        url: 'https://gemini-consent.invalid',
        publishableKey: 'synthetic-public',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: CommunityOwnerHttpClient(
          MockClient((request) async {
            if (request.url.path == '/rest/v1/bil_consent_receipts') {
              final purpose = request.url.queryParameters['purpose']!
                  .replaceFirst('eq.', '');
              reads.add(purpose);
              expect(request.url.queryParameters['user_id'], 'eq.$a');
              if (hold != null) {
                if (!entered.isCompleted) entered.complete();
                final result = await hold!.future;
                return http.Response.bytes(
                  result.bodyBytes,
                  result.statusCode,
                  headers: result.headers,
                  request: request,
                );
              }
              if (fail) {
                return response(request, {'message': 'synthetic outage'}, 503);
              }
              final value = receipts[purpose];
              return response(
                request,
                value == null
                    ? []
                    : [
                        {'granted': value, 'policy_version': '1'},
                      ],
                200,
              );
            }
            if (request.url.path == '/rest/v1/rpc/bil_record_consent') {
              final data = (jsonDecode(request.body) as Map)
                  .cast<String, dynamic>();
              writes.add(data);
              receipts[data['p_purpose'] as String] = data['p_granted'] as bool;
              return response(request, {}, 200);
            }
            if (request.url.path == '/auth/v1/user') {
              return response(request, session(a)['user']!, 200);
            }
            throw StateError('Unexpected request ${request.url.path}');
          }),
        ),
      );
      await sdk.client.auth.setInitialSession(jsonEncode(session(a)));
    });
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.runAsync(() => sdk.dispose());
    });
  }

  Future<void> owner(WidgetTester t, String id) async {
    await t.runAsync(
      () => sdk.client.auth
          .setInitialSession(jsonEncode(session(id)))
          .then((_) {}),
    );
  }
}

void main() {
  testWidgets('captured owner visit retires permanently on delivered A B A', (
    t,
  ) async {
    final s = Scenario();
    await s.init(t);
    final db = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: a);
    final visit = MealVisionEstimateVisit.capture(
      database: db,
      isCurrentDatabase: () => true,
    )!;
    try {
      expect(visit.current, isTrue);
      await s.owner(t, b);
      await s.owner(t, a);
      expect(s.sdk.client.auth.currentUser!.id, a);
      expect(visit.current, isFalse);
      expect(visit.lifetime.isActive, isFalse);
    } finally {
      visit.dispose();
      await db.close();
    }
  });
  testWidgets(
    'guest or a database belonging to another owner cannot capture a photo visit',
    (t) async {
      final s = Scenario();
      await s.init(t);
      final guest = AppDatabase.forTesting(NativeDatabase.memory());
      final other = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: b,
      );
      try {
        expect(
          MealVisionEstimateVisit.capture(
            database: guest,
            isCurrentDatabase: () => true,
          ),
          isNull,
        );
        expect(
          MealVisionEstimateVisit.capture(
            database: other,
            isCurrentDatabase: () => true,
          ),
          isNull,
        );
      } finally {
        await guest.close();
        await other.close();
      }
    },
  );
  testWidgets(
    'supplement reads and withdrawal use only the exact current owner and new purpose',
    (t) async {
      final s = Scenario();
      s.receipts[mealVisionEstimateConsentPurpose] = true;
      await s.init(t);
      final first = await t.runAsync(loadMealVisionEstimateConsent);
      expect(first, isTrue);
      expect(await t.runAsync(revokeMealVisionEstimateConsent), isTrue);
      expect(s.writes.single, {
        'p_purpose': mealVisionEstimateConsentPurpose,
        'p_policy_version': '1',
        'p_granted': false,
      });
      expect(s.receipts['meal_vision_ai'], isTrue);
      expect(await t.runAsync(loadMealVisionEstimateConsent), isFalse);
    },
  );
  testWidgets(
    'held positive consent read cannot become a new visit grant after owner ABA',
    (t) async {
      final s = Scenario();
      await s.init(t);
      s.hold = Completer<http.Response>();
      final read = loadMealVisionEstimateConsent();
      await t.runAsync(
        () => s.entered.future.timeout(const Duration(seconds: 3)),
      );
      await s.owner(t, b);
      await s.owner(t, a);
      s.hold!.complete(
        http.Response(
          '[{"granted":true,"policy_version":"1"}]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await expectLater(read, throwsA(isA<CommunityOwnerOperationCancelled>()));
      expect(s.writes, isEmpty);
    },
  );
  testWidgets('read outage cannot be interpreted as supplemental consent', (
    t,
  ) async {
    final s = Scenario();
    await s.init(t);
    s.fail = true;
    await t.runAsync(() async {
      await expectLater(
        loadMealVisionEstimateConsent(),
        throwsA(isA<PostgrestException>()),
      );
    });
    expect(s.writes, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'supplemental disclosure decline records false and never upgrades existing base consent',
    (t) async {
      final s = Scenario();
      await s.init(t);
      bool? result;
      final done = Completer<void>();
      await t.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await ensureMealVisionEstimateConsent(
                    context,
                    isCurrent: () => true,
                  );
                  done.complete();
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('gemini-estimates-allow')), findsOneWidget);
      expect(s.writes, isEmpty);
      await t.tap(find.byKey(const Key('gemini-estimates-decline')));
      await t.pumpAndSettle();
      await t.runAsync(() => done.future.timeout(const Duration(seconds: 3)));
      expect(result, isFalse);
      expect(s.writes.single['p_purpose'], mealVisionEstimateConsentPurpose);
      expect(s.writes.single['p_granted'], isFalse);
      expect(s.receipts['meal_vision_ai'], isTrue);
    },
  );
}
