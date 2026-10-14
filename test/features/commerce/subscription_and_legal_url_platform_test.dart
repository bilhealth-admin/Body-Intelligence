// Actual Settings/Plans taps through the public URL launcher boundary.
// Synthetic SDK HTTP + native SQLite, no store/browser delivery or phone claim.
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
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
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

enum _Result { opened, unavailable, exception }

class _Launcher extends UrlLauncherPlatform {
  _Launcher(this.result);
  final _Result result;
  final launches = <({Uri uri, PreferredLaunchMode mode})>[];
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((uri: Uri.parse(url), mode: options.mode));
    if (result == _Result.exception) {
      throw PlatformException(code: 'synthetic-launch-failure');
    }
    return result == _Result.opened;
  }
}

class _UnavailableStore extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  int purchases = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    purchases++;
    throw StateError('URL-only fixture must never purchase.');
  }
}

Map<String, Object?> _session() {
  final jwt = base64Url
      .encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$jwt.synthetic',
    'refresh_token': 'synthetic-url-refresh',
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

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 80 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  expect(
    ready(),
    isTrue,
    reason: 'Actual SDK/SQLite widget stage must complete.',
  );
}

Future<void> _reach(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

class _SettingsBoundary {
  final previousNative = InAppPurchasePlatform.instance;
  final native = _UnavailableStore();
  final storage = <String, String>{};
  Supabase? sdk;
  AppDatabase? database;
  MockClient? transport;
  Object? httpFailure;
  int usageReads = 0;
  Future<void> mount(WidgetTester tester, TargetPlatform platform) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_storage, (
      call,
    ) async {
      final args = Map<String, Object?>.from(
        call.arguments as Map? ?? const {},
      );
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return storage[key];
        case 'write':
          storage[key!] = args['value']! as String;
          return null;
        case 'delete':
          storage.remove(key);
          return null;
        case 'readAll':
          return storage;
        case 'containsKey':
          return storage.containsKey(key);
        default:
          throw StateError('Unexpected fixture storage ${call.method}');
      }
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    InAppPurchasePlatform.instance = native;
    expect(InAppPurchase.instance, isA<InAppPurchase>());
    debugDefaultTargetPlatformOverride = platform;
    transport = MockClient((request) async {
      try {
        expect(request.url.host, 'subscription-url.invalid');
        expect(
          request.headers['authorization'],
          'Bearer ${_session()['access_token'] as String}',
        );
        Object? value;
        switch (request.url.path) {
          case '/rest/v1/rpc/bil_get_ai_usage_status':
            usageReads++;
            value = {
              'plan': 'free',
              'week_start': '2026-10-13T00:00:00Z',
              'reset_at': '2026-10-20T00:00:00Z',
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
            value = {'granted': false, 'policy_version': '3'};
          case '/rest/v1/bil_ai_coach_reset_notices':
            expect(request.url.queryParameters['owner_id'], 'eq.$_owner');
            value = <Object?>[];
          default:
            throw StateError('Unexpected URL-only HTTP ${request.url.path}');
        }
        return http.Response(
          jsonEncode(value),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      } on Object catch (error) {
        httpFailure = error;
        rethrow;
      }
    });
    await tester.runAsync(() async {
      try {
        sdk = await Supabase.initialize(
          url: 'https://subscription-url.invalid',
          publishableKey: 'synthetic-key',
          debug: false,
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),
          ),
          httpClient: transport!,
        );
      } finally {
        if (sdk == null) {
          try {
            sdk = Supabase.instance;
          } on AssertionError {
            // Supabase is still uninitialized after the expected setup failure.
          }
        }
      }
      await sdk!.client.auth.recoverSession(jsonEncode(_session()));
    });
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: _owner,
    );
    await tester.runAsync(() => database!.customSelect('SELECT 1').getSingle());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database!)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: _delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AiCoachSettingsPage(),
        ),
      ),
    );
    await _until(
      tester,
      () => find.byType(RefreshIndicator).evaluate().isNotEmpty,
    );
    expect(usageReads, greaterThan(0));
    expect(httpFailure, isNull);
    expect(tester.takeException(), isNull);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await database?.close();
      await sdk?.dispose();
    });
    transport?.close();
    await native.updates.close();
    InAppPurchasePlatform.instance = previousNative;
    debugDefaultTargetPlatformOverride = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _storage,
      null,
    );
  }
}

class _Catalog implements BilStoreCatalogGateway {
  int purchases = 0;
  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> ids) async =>
      const [
        BilStoreOfferMetadata(
          productId: 'bil_premium',
          kind: BilStoreProductKind.premiumSubscription,
          localizedTitle: 'Synthetic catalog',
          localizedPrice: '2.49',
          currencyCode: 'USD',
          priceMicros: 2490000,
          billingPeriodIso8601: 'P1M',
        ),
      ];
  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    purchases++;
  }

  @override
  Future<void> restorePurchases() async {}
  @override
  Future<void> openManageSubscriptions() async {}
}

Future<_Catalog> _plans(WidgetTester tester, String language) async {
  expect(
    StoreCatalogConfiguration.legalLinksConfigured,
    isTrue,
    reason: 'Use approved HTTPS defines, or their padded-whitespace variant.',
  );
  final catalog = _Catalog();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: _delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BilStorePlansPage(catalog: catalog, connectToDeviceStore: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return catalog;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('public legal links work without release defines', () {
    expect(
      StoreCatalogConfiguration.termsUrl,
      'https://www.bilhealth.com/terms',
    );
    expect(
      StoreCatalogConfiguration.privacyUrl,
      'https://www.bilhealth.com/privacy',
    );
    expect(StoreCatalogConfiguration.legalLinksConfigured, isTrue);
  });
  final baselineNative = _UnavailableStore();
  setUpAll(() {
    // Public IAP singleton bootstrap on a platform without native registration.
    // A cold test isolate has no InAppPurchasePlatform.instance until this.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    InAppPurchasePlatform.instance = baselineNative;
    expect(InAppPurchase.instance, isA<InAppPurchase>());
    debugDefaultTargetPlatformOverride = null;
  });
  tearDownAll(() => baselineNative.updates.close());
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    final supported =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    for (final result in supported ? _Result.values : [_Result.opened]) {
      testWidgets(
        'actual Settings subscription URL ${platform.name} ${result.name}',
        (tester) async {
          final original = UrlLauncherPlatform.instance;
          final launcher = _Launcher(result);
          final fixture = _SettingsBoundary();
          try {
            UrlLauncherPlatform.instance = launcher;
            await fixture.mount(tester, platform);
            final button = find.widgetWithText(
              TextButton,
              'Manage subscription in store',
            );
            await _reach(tester, button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            if (supported) {
              expect(launcher.launches, hasLength(1));
              final launch = launcher.launches.single;
              expect(launch.mode, PreferredLaunchMode.externalApplication);
              expect(launch.uri.scheme, 'https');
              expect(
                launch.uri.host,
                platform == TargetPlatform.iOS
                    ? 'apps.apple.com'
                    : 'play.google.com',
              );
              expect(
                launch.uri.path,
                platform == TargetPlatform.iOS
                    ? '/account/subscriptions'
                    : '/store/account/subscriptions',
              );
            } else {
              expect(
                launcher.launches,
                isEmpty,
                reason:
                    'Unsupported host must not silently choose the Google store.',
              );
            }
            expect(
              find.byType(SnackBar),
              supported && result == _Result.opened
                  ? findsNothing
                  : findsOneWidget,
            );
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Native launch failure must become a visible retryable state.',
            );
            expect(fixture.native.purchases, 0);
            expect(fixture.httpFailure, isNull);
          } finally {
            await fixture.close(tester);
            UrlLauncherPlatform.instance = original;
          }
        },
      );
    }
  }
  for (final language in ['en', 'ar']) {
    for (final result in _Result.values) {
      testWidgets(
        'actual Plans platform legal links $language ${result.name}',
        (tester) async {
          final original = UrlLauncherPlatform.instance;
          final launcher = _Launcher(result);
          try {
            UrlLauncherPlatform.instance = launcher;
            final catalog = await _plans(tester, language);
            for (final key in ['store-terms-link', 'store-privacy-link']) {
              final button = find.byKey(Key(key));
              await _reach(tester, button);
              await tester.tap(button);
              await tester.pumpAndSettle();
              if (result != _Result.opened) {
                expect(find.byType(SnackBar), findsOneWidget);
                ScaffoldMessenger.of(
                  tester.element(button),
                ).hideCurrentSnackBar();
                await tester.pumpAndSettle();
              }
            }
            expect(launcher.launches.map((launch) => launch.uri), [
              Uri.parse(StoreCatalogConfiguration.termsUrl.trim()),
              Uri.parse(StoreCatalogConfiguration.privacyUrl.trim()),
            ]);
            expect(
              launcher.launches.every(
                (launch) =>
                    launch.mode == PreferredLaunchMode.externalApplication,
              ),
              isTrue,
            );
            expect(catalog.purchases, 0);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            UrlLauncherPlatform.instance = original;
          }
        },
      );
    }
  }
}
