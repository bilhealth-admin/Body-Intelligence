import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:body_intelligence_log/features/nutrition/presentation/meal_image_guide_page.dart';
import 'package:body_intelligence_log/features/nutrition/providers/meal_vision_usage_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_usage_contract.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'usage contract exposes truthful used reserved and remaining values',
    () {
      final usage = MealVisionUsage.fromJson(const {
        'limit': 100,
        'used': 23,
        'reserved': 1,
        'remaining': 76,
        'period_start': '2026-08-01',
      });
      expect(usage.limit, 100);
      expect(usage.exhausted, isFalse);
      expect(
        () => MealVisionUsage.fromJson(const {
          'limit': 100,
          'used': 23,
          'reserved': 1,
          'remaining': 77,
        }),
        throwsFormatException,
      );
    },
  );

  test('legacy quota display can parse shared Coach and Boost balances', () {
    final usage = MealVisionUsage.fromAiUsageStatus(const {
      'plan': 'ai_coach',
      'week_start': '2026-08-10',
      'credits': {
        'unit': 'BIL AI Token',
        'billing_scope': 'shared',
        'weekly_limit': 5000,
        'weekly_used': 800,
        'weekly_reserved': 100,
        'weekly_remaining': 4100,
        'paid_granted': 5000,
        'paid_used': 300,
        'paid_reserved': 200,
        'paid_remaining': 4500,
      },
    });

    expect(usage.limit, 10000);
    expect(usage.used, 1100);
    expect(usage.reserved, 300);
    expect(usage.remaining, 8600);
    expect(usage.periodStart, DateTime(2026, 8, 10));
  });

  test(
    'production meal Vision reservation uses the shared AI Coach meter',
    () async {
      final legacySql = File(
        'supabase/migrations/'
        '20260821174122_require_paid_boost_for_meal_vision.sql',
      ).readAsStringSync();
      final sql = File(
        'supabase/migrations/'
        '20260918120000_meal_vision_uses_shared_ai_coach_tokens.sql',
      ).readAsStringSync();
      expect(legacySql, contains('bil_reserve_paid_ai_vision_usage'));
      expect(sql, contains('bil_reserve_ai_usage'));
      expect(sql, contains("'billing_source'"));
      expect(sql, contains("'ai_coach_then_paid_boost'"));
      expect(sql, contains('weekly_tokens_reserved'));
      expect(sql, contains('paid_tokens_reserved'));
      expect(sql, contains("'vision'"));
      await _withRealVisionAccessSdk((fixture) async {
        for (final example in <({String body, AiVisionCreditState state})>[
          (body: _creditBody(99), state: AiVisionCreditState.insufficient),
          (body: _creditBody(100), state: AiVisionCreditState.available),
          (
            body: _creditBody(0, plan: 'premium'),
            state: AiVisionCreditState.insufficient,
          ),
          (
            body: _creditBody(5000, plan: 'free'),
            state: AiVisionCreditState.available,
          ),
          (body: _creditBody(-1), state: AiVisionCreditState.unavailable),
          (body: _creditBody('100'), state: AiVisionCreditState.unavailable),
          (
            body: '{"credits":{"total_remaining":NaN}}',
            state: AiVisionCreditState.unavailable,
          ),
          (
            body: '{"credits":{"weekly_remaining":5000,"paid_remaining":5000}}',
            state: AiVisionCreditState.unavailable,
          ),
        ]) {
          fixture.ownerBodies[_visionOwnerA] = example.body;
          fixture.container.invalidate(aiVisionCreditStateProvider);
          expect(
            await fixture.container.read(aiVisionCreditStateProvider.future),
            example.state,
          );
          expect(
            await fixture.container.read(aiBoostVisionAccessProvider.future),
            example.state == AiVisionCreditState.available,
          );
        }
        // Refresh failure cannot reuse the earlier positive result as new authority.
        fixture.ownerBodies[_visionOwnerA] = _creditBody(100);
        fixture.container.invalidate(aiVisionCreditStateProvider);
        expect(
          await fixture.container.read(aiBoostVisionAccessProvider.future),
          isTrue,
        );
        fixture.statusCode = 503;
        fixture.ownerBodies[_visionOwnerA] =
            '{"code":"synthetic_unavailable","message":"Synthetic test outage"}';
        fixture.container.invalidate(aiVisionCreditStateProvider);
        expect(
          await fixture.container.read(aiVisionCreditStateProvider.future),
          AiVisionCreditState.unavailable,
        );
        expect(
          await fixture.container.read(aiBoostVisionAccessProvider.future),
          isFalse,
        );
        expect(fixture.owners, isNotEmpty);
        expect(fixture.owners.every((owner) => owner == _visionOwnerA), isTrue);
      });
    },
  );

  for (final roundTrip in [false, true]) {
    test(
      'real SDK Vision credit gate fences pending ${roundTrip ? 'ABA' : 'AB'} reads',
      () async {
        await _withRealVisionAccessSdk((fixture) async {
          fixture.ownerBodies[_visionOwnerA] = _creditBody(5000);
          fixture.ownerBodies[_visionOwnerB] = _creditBody(0);
          fixture.holdNext = true;
          final oldRead = fixture.container.read(
            aiVisionCreditStateProvider.future,
          );
          unawaited(oldRead.then((_) {}, onError: (Object _) {}));
          await fixture.entered.future.timeout(const Duration(seconds: 5));
          await fixture.moveOwner(_visionOwnerB);
          expect(
            await fixture.container.read(aiVisionCreditStateProvider.future),
            AiVisionCreditState.insufficient,
          );
          if (roundTrip) {
            fixture.ownerBodies[_visionOwnerA] = _creditBody(99);
            await fixture.moveOwner(_visionOwnerA);
            expect(
              await fixture.container.read(aiVisionCreditStateProvider.future),
              AiVisionCreditState.insufficient,
            );
          }
          fixture.release.complete();
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          expect(
            await fixture.container.read(aiVisionCreditStateProvider.future),
            AiVisionCreditState.insufficient,
          );
          expect(
            await fixture.container.read(aiBoostVisionAccessProvider.future),
            isFalse,
          );
          expect(fixture.owners, contains(_visionOwnerA));
          expect(fixture.owners, contains(_visionOwnerB));
        });
      },
    );
  }

  test(
    'migration is atomic, idempotent, metered, RLS protected and fail closed',
    () {
      final sql = File(
        'supabase/migrations/202608100003_bil_meal_vision_quota.sql',
      ).readAsStringSync();
      expect(sql, contains("values ('free', 0), ('pro', 100), ('plus', 100)"));
      // Legacy migration coverage only. Runtime allowance now comes from
      // bil_get_ai_usage_status (standalone Coach weekly + paid Boost).
      expect(sql, contains('for update'));
      expect(sql, contains('vision_quota_not_configured'));
      expect(sql, contains('vision_quota_exhausted'));
      expect(sql, contains('idempotency_payload_mismatch'));
      expect(sql, contains('duplicate_image'));
      expect(sql, contains("state in ('reserved','succeeded','refunded')"));
      expect(sql, contains('provider text'));
      expect(sql, contains('latency_ms integer'));
      expect(sql, contains('input_tokens integer'));
      expect(sql, contains('output_tokens integer'));
      expect(sql, contains('cost_usd numeric'));
      expect(sql, contains('enable row level security'));
      expect(sql, contains('owner_id = (select auth.uid())'));
    },
  );

  for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
    testWidgets('meal guide exposes truthful quota in $locale', (tester) async {
      const usage = MealVisionUsage(
        limit: 75,
        used: 7,
        reserved: 0,
        remaining: 68,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealVisionUsageProvider.overrideWith(
              (ref) async => const MealVisionUsageSnapshot.available(usage),
            ),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
              Locale('fr'),
              Locale('es'),
              Locale('tr'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MealImageGuidePage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('meal-vision-usage')), findsOneWidget);
      expect(find.textContaining(locale == 'ar' ? '٦٨' : '68'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('meal-image-guide-next')),
            )
            .onPressed,
        isNotNull,
      );
    });
  }

  test('meal guide authored copy resolves across all 25 locales', () {
    const english = <String>[
      'Meal Scan',
      'Choose a meal photo',
      'Suggestions are not nutrition facts. You stay in control and nothing is logged until you confirm it.',
      'Scan your entire meal',
      'Select visible foods',
      'Add anything we missed',
      'Review and log your meal',
      'Nothing is saved until you confirm',
      'Analysis allowance is unavailable right now.',
      'Sign in to check your analysis allowance.',
      'Weekly allowance and AI Boost balance are exhausted.',
    ];
    for (final locale in AppLocalizations.supportedLocales) {
      if (const {'ar', 'en', 'fr', 'es', 'tr'}.contains(locale.languageCode)) {
        continue;
      }
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final key in english) {
        expect(RuntimeCopy.resolve(key, tag), isNotNull, reason: '$key $tag');
      }
    }
  });
}

// Actual pinned Supabase/Auth/PostgREST and production Riverpod credit gate.
// Only HTTP I/O is synthetic; no allowance provider or grant is overridden.
const _visionOwnerA = '11111111-1111-4111-8111-111111111111';
const _visionOwnerB = '22222222-2222-4222-8222-222222222222';
String _creditBody(Object? remaining, {String plan = 'ai_coach'}) =>
    jsonEncode({
      'plan': plan,
      'credits': {'total_remaining': remaining},
    });
String _visionSession(String owner) => jsonEncode({
  'access_token':
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800}))).replaceAll('=', '')}.synthetic',
  'refresh_token': 'synthetic-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'aud': 'authenticated',
    'app_metadata': {},
    'user_metadata': {},
    'created_at': '2026-10-13T00:00:00Z',
  },
});

class _VisionAccessFixture {
  late SupabaseClient client;
  late ProviderContainer container;
  final ownerBodies = <String, String>{
    _visionOwnerA: _creditBody(99),
    _visionOwnerB: _creditBody(0),
  };
  final owners = <String>[];
  final entered = Completer<void>(), release = Completer<void>();
  bool holdNext = false;
  int statusCode = 200;
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path != '/rest/v1/rpc/bil_get_ai_usage_status') {
      throw StateError('Unexpected isolated credit route: ${request.url.path}');
    }
    final jwt = request.headers['authorization']!.split(' ').last;
    final owner =
        (jsonDecode(
                  utf8.decode(
                    base64Url.decode(base64Url.normalize(jwt.split('.')[1])),
                  ),
                )
                as Map)['sub']
            as String;
    owners.add(owner);
    final body = ownerBodies[owner]!;
    final status = statusCode;
    if (holdNext) {
      holdNext = false;
      entered.complete();
      await release.future;
    }
    return http.Response(
      body,
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<void> moveOwner(String owner) async {
    final delivered = client.auth.onAuthStateChange.firstWhere(
      (event) => event.session?.user.id == owner,
    );
    await client.auth.recoverSession(_visionSession(owner));
    await delivered.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(verifiedEntitlementOwnerIdProvider), owner);
  }
}

Future<void> _withRealVisionAccessSdk(
  Future<void> Function(_VisionAccessFixture) action,
) async {
  SharedPreferences.setMockInitialValues({});
  final fixture = _VisionAccessFixture();
  final singleton = await Supabase.initialize(
    url: 'https://bootstrap.invalid',
    publishableKey: 'synthetic-bootstrap',
    debug: false,
    accessToken: () async => 'synthetic-bootstrap',
    httpClient: MockClient(
      (request) async => http.Response('{}', 200, request: request),
    ),
  );
  await singleton.client.dispose();
  fixture.client = SupabaseClient(
    'https://vision-credits.invalid',
    'synthetic-publishable',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(fixture.respond),
  );
  singleton.client = fixture.client;
  await fixture.client.auth.recoverSession(_visionSession(_visionOwnerA));
  fixture.container = ProviderContainer();
  final listener = fixture.container.listen(
    aiVisionCreditStateProvider,
    (_, _) {},
  );
  try {
    await action(fixture);
  } finally {
    if (!fixture.release.isCompleted) fixture.release.complete();
    listener.close();
    fixture.container.dispose();
    await singleton.dispose();
  }
}
