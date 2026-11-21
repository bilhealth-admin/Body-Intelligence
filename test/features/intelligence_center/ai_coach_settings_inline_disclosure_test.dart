// HOST_WIDGET_WITH_MOCK_HTTP_AND_NATIVE. Actual AiCoachSettingsPage body and
// default consent coordinator execute; no live owner, Gemini or purchase call.
import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_apple_ai_privacy.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/ai_coach_settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _subtitle =
    'When enabled, your question and selected weight/body, nutrition, activity, sleep, habit, and recent conversation context can be sent to Google Gemini, a third-party AI service operated by Google, only to answer your request. Turn this off at any time; local BIL features remain available.';
const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _Native extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: identifiers.toList(),
  );
}

class _Boundary {
  bool granted = false;
  int grants = 0;
  int reads = 0;
  int modelRequests = 0;
  Object? failure;
  Future<http.Response> handle(http.Request request) async {
    try {
      expect(request.url.host, 'inline-consent-fixture.invalid');
      Object? result;
      switch (request.url.path) {
        case '/rest/v1/rpc/bil_get_ai_usage_status':
          result = {
            'plan': 'free',
            'credits': {
              'weekly_limit': 0,
              'weekly_used': 0,
              'weekly_reserved': 0,
              'weekly_remaining': 0,
              'paid_remaining': 0,
              'total_remaining': 0,
            },
          };
        case '/rest/v1/rpc/bil_get_remote_ai_consent':
          reads++;
          result = {'policy_version': '3', 'granted': granted};
        case '/rest/v1/rpc/bil_record_consent':
          final body = jsonDecode(request.body) as Map;
          expect(body['p_purpose'], 'remote_ai');
          expect(body['p_policy_version'], '3');
          expect(body['p_granted'], true);
          grants++;
          granted = true;
          result = true;
        case '/rest/v1/bil_ai_coach_reset_notices':
          result = <Object?>[];
        default:
          if (request.url.path.startsWith('/functions/')) modelRequests++;
          throw StateError('Unexpected host-only endpoint ${request.url.path}');
      }
      return http.Response(
        jsonEncode(result),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    } on Object catch (error) {
      failure = error;
      rethrow;
    }
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
  expect(
    ready(),
    isTrue,
    reason: 'Actual settings state must settle within the bounded host wait',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'ar', 'fr', 'es', 'tr']) {
    testWidgets(
      'actual inline Gemini disclosure precedes affirmative grant [$language]',
      (tester) async {
        final boundary = _Boundary();
        final native = _Native();
        final httpClient = MockClient(boundary.handle);
        Supabase? supabase;
        AppDatabase? database;
        ProviderContainer? container;
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        SharedPreferences.setMockInitialValues({});
        final secureValues = <String, String>{};
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _secureStorage,
          (call) async {
            final args = Map<String, Object?>.from(call.arguments as Map);
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return secureValues[key];
              case 'write':
                secureValues[key!] = args['value'] as String;
                return null;
              case 'delete':
                secureValues.remove(key);
                return null;
              default:
                throw StateError('Unexpected secure storage operation');
            }
          },
        );
        try {
          debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
          InAppPurchasePlatform.instance = native;
          expect(InAppPurchase.instance, isA<InAppPurchase>());
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          await tester.runAsync(() async {
            supabase = await Supabase.initialize(
              url: 'https://inline-consent-fixture.invalid',
              publishableKey: 'synthetic-host-only-publishable-key',
              debug: false,
              authOptions: const FlutterAuthClientOptions(
                autoRefreshToken: false,
                detectSessionInUri: false,
                localStorage: EmptyLocalStorage(),
              ),
              httpClient: httpClient,
            );
            await supabase!.client.auth.setInitialSession(
              jsonEncode({
                'access_token': 'synthetic-host-only-token',
                'token_type': 'bearer',
                'user': {
                  'id': '00000000-0000-4000-8005-000000000050',
                  'app_metadata': {},
                  'user_metadata': {},
                  'aud': 'authenticated',
                  'created_at': '2026-01-01T00:00:00Z',
                },
              }),
            );
          });
          database = AppDatabase.forTesting(
            NativeDatabase.memory(),
            localOwnerId: '00000000-0000-4000-8005-000000000050',
          );
          container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              preferencesRepositoryProvider.overrideWithValue(
                PreferencesRepository(database),
              ),
            ],
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                home: const AiCoachSettingsPage(),
              ),
            ),
          );
          final expectedTitle = AppleAiPrivacyRuntimeCopy.resolve(
            'Google Gemini AI consent',
            language,
          )!;
          final expectedSubtitle = AppleAiPrivacyRuntimeCopy.resolve(
            _subtitle,
            language,
          )!;
          final tile = find.ancestor(
            of: find.text(expectedTitle),
            matching: find.byType(SwitchListTile),
          );
          await _until(
            tester,
            () => tile.evaluate().length == 1 && boundary.reads > 0,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text(expectedSubtitle)),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          expect(find.text(expectedSubtitle), findsOneWidget);
          expect(expectedTitle, contains('Google Gemini'));
          expect(expectedSubtitle, contains('Google'));
          expect(tester.widget<SwitchListTile>(tile).value, isFalse);
          expect(tester.widget<SwitchListTile>(tile).onChanged, isNotNull);
          final viewport = Offset.zero & tester.view.physicalSize;
          for (final target in [
            find.text(expectedTitle),
            find.text(expectedSubtitle),
          ]) {
            final rect = tester.getRect(target);
            expect(
              viewport.contains(rect.topLeft) &&
                  viewport.contains(rect.bottomRight),
              isTrue,
              reason:
                  'Complete provider/data/purpose/withdrawal disclosure must be visible BEFORE affirmative consent',
            );
          }
          final consentPreferences = await SharedPreferences.getInstance();
          const acknowledgementKey =
              'bil.remoteAi.disclosure.googleRecipient.v1.00000000-0000-4000-8005-000000000050';
          expect(consentPreferences.getBool(acknowledgementKey), isNull);
          expect(boundary.grants, 0);
          expect(boundary.granted, isFalse);
          expect(boundary.modelRequests, 0);
          for (final legacy in [
            'service Gemini de BIL',
            'servicio Gemini de BIL',
            'BILâ€™in Gemini hizmetine',
          ]) {
            expect(find.textContaining(legacy), findsNothing);
          }
          // Real rendered affirmative control and default production coordinator;
          // neither callback nor consent repository is overridden.
          await tester.tap(tile);
          await _until(
            tester,
            () =>
                boundary.grants == 1 &&
                tile.evaluate().length == 1 &&
                tester.widget<SwitchListTile>(tile).value,
          );
          expect(boundary.granted, isTrue);
          expect(consentPreferences.getBool(acknowledgementKey), isTrue);
          expect(
            boundary.reads,
            greaterThanOrEqualTo(2),
            reason: 'Grant persistence must be read back',
          );
          expect(boundary.grants, 1);
          expect(boundary.modelRequests, 0);
          expect(boundary.failure, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container?.dispose();
          if (database != null) await _finishHost(tester, database.close);
          if (supabase != null) await _finishHost(tester, supabase!.dispose);
          await _finishHost(tester, native.updates.close);
          httpClient.close();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _secureStorage,
            null,
          );
          debugDefaultTargetPlatformOverride = null;
          tester.view.reset();
          await tester.pump();
        }
      },
      timeout: const Timeout(Duration(seconds: 40)),
    );
  }
}

Future<void> _finishHost(
  WidgetTester tester,
  Future<void> Function() operation,
) async {
  var complete = false;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    Future<void>.sync(operation).then<void>(
      (_) => complete = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        complete = true;
      },
    );
  });
  await _until(tester, () => complete);
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}
