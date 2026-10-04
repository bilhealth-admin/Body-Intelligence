// HOST_WIDGET_WITH_MOCK_HTTP_AND_NATIVE, not a native purchase or Production
// transaction. Actual Settings, default AiBoostPurchaseService, Supabase SDK,
// real Coach/Vision access loaders and SQLite execute without paid-state,
// verification-function, usage-loader, callback or page overrides. The public
// IAP plugin platform and HTTP responses are controlled host boundaries.
// Debug integrity's normal opt-out is not App Attest/Play Integrity evidence.
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/ai_coach_settings_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
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

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _host = 'coach-settings-credit-fixture.invalid';
const _token = 'coach-settings-credit-fixture-token';

enum _Case { nativeFinishPending, rejectedVerification, repeatedConsumable }

class _NativePlatform extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  bool finishFails = false;
  int launches = 0;
  int finishes = 0;
  int catalogReads = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    expectSync(AiBoostPurchaseService.productId, isNotEmpty);
    expectSync(ids, {AiBoostPurchaseService.productId});
    catalogReads++;
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: AiBoostPurchaseService.productId,
          title: 'Host native boundary product',
          description: 'Not a genuine StoreKit purchase',
          price: '2.49',
          rawPrice: 2.49,
          currencyCode: 'USD',
        ),
      ],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    expectSync(
      purchaseParam.productDetails.id,
      AiBoostPurchaseService.productId,
    );
    expectSync(autoConsume, isFalse);
    launches++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    finishes++;
    if (finishFails) throw StateError('Host native finish unavailable');
  }
}

class _HttpBoundary {
  _HttpBoundary(this.owner);
  final String owner;
  final verification = Completer<bool>();
  final creditedReceipts = <String>{};
  int balance = 0;
  int usageReads = 0;
  int verificationReads = 0;
  int activeRequests = 0;
  Object? failure;

  Future<http.Response> handle(http.Request request) async {
    activeRequests++;
    try {
      expectSync(request.url.host, _host);
      expectSync(request.headers['authorization'], 'Bearer $_token');
      Object? data;
      switch (request.url.path) {
        case '/rest/v1/rpc/bil_get_ai_usage_status':
          expectSync(request.method, 'POST');
          usageReads++;
          data = {
            'plan': 'free',
            'week_start': '2026-10-04T00:00:00Z',
            'reset_at': '2026-10-11T00:00:00Z',
            'credits': {
              'weekly_limit': 0,
              'weekly_used': 0,
              'weekly_reserved': 0,
              'weekly_remaining': 0,
              'paid_remaining': balance,
              'total_remaining': balance,
            },
          };
        case '/rest/v1/rpc/bil_get_remote_ai_consent':
          data = {'policy_version': '3', 'granted': false};
        case '/rest/v1/bil_ai_coach_reset_notices':
          expectSync(request.url.queryParameters['owner_id'], 'eq.$owner');
          data = <Object?>[];
        case '/functions/v1/verify-store-purchase':
          expectSync(request.method, 'POST');
          final body = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          expectSync(body['action'], 'verify_ai_boost');
          expectSync(body['source'], 'app_store');
          expectSync(body['product_id'], AiBoostPurchaseService.productId);
          final receipt = body['verification_data'] as String;
          expectSync(receipt, startsWith('host-receipt-$owner-'));
          verificationReads++;
          final verified = await verification.future;
          // Simulated server ledger changes only after this owner-authenticated
          // verification response, never from a native status or UI callback.
          if (verified && creditedReceipts.add(receipt)) balance += 2500;
          data = {'verified': verified};
        default:
          throw StateError(
            'Unexpected host HTTP boundary: ${request.url.path}',
          );
      }
      return http.Response(
        jsonEncode(data),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    } on Object catch (error) {
      failure = error;
      rethrow;
    } finally {
      activeRequests--;
    }
  }
}

PurchaseDetails _receipt(String owner, String id) {
  final purchase = PurchaseDetails(
    purchaseID: id,
    productID: AiBoostPurchaseService.productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: 'host-receipt-$owner-$id',
      source: 'app_store',
    ),
    transactionDate: '1',
    status: PurchaseStatus.purchased,
  );
  purchase.pendingCompletePurchase = true;
  return purchase;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var sequence = 0;
  for (final scenario in _Case.values) {
    testWidgets(
      'actual Coach Settings verified credit ${scenario.name}',
      (tester) async {
        final owner =
            '00000000-0000-4000-8005-${(++sequence).toString().padLeft(12, '0')}';
        _NativePlatform? ownedNative;
        _HttpBoundary? ownedServer;
        MockClient? ownedTransport;
        Supabase? ownedSupabase;
        AppDatabase? ownedDatabase;
        ProviderContainer? ownedContainer;
        ProviderSubscription<AsyncValue<String?>>? ownerSubscription;
        ProviderSubscription<AsyncValue<bool>>? coach;
        ProviderSubscription<AsyncValue<bool>>? vision;
        try {
          tester.view.physicalSize = const Size(600, 1400);
          tester.view.devicePixelRatio = 1;
          final native = ownedNative = _NativePlatform()
            ..finishFails = scenario == _Case.nativeFinishPending;
          // The SDK's own tests bootstrap the singleton on Fuchsia to avoid native
          // auto-registration, then install the public plugin-platform fixture.
          // iOS below selects the real service's native-finish branch, not an OS.
          debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
          InAppPurchasePlatform.instance = native;
          final sdk = InAppPurchase.instance;
          expect(sdk, isA<InAppPurchase>());
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          final server = ownedServer = _HttpBoundary(owner);
          final transport = ownedTransport = MockClient(server.handle);
          final secureValues = <String, String>{};
          SharedPreferences.setMockInitialValues({});
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _storage,
            (call) async {
              final args = Map<String, Object?>.from(call.arguments as Map);
              final key = args['key'] as String?;
              switch (call.method) {
                case 'read':
                  return secureValues[key];
                case 'write':
                  secureValues[key!] = args['value']! as String;
                  return null;
                case 'delete':
                  secureValues.remove(key);
                  return null;
                default:
                  throw StateError('Unexpected secure-storage operation');
              }
            },
          );
          await tester.runAsync(() async {
            try {
              ownedSupabase = await Supabase.initialize(
                url: 'https://$_host',
                publishableKey: 'host-fixture-publishable-key',
                debug: false,
                authOptions: const FlutterAuthClientOptions(
                  autoRefreshToken: false,
                  detectSessionInUri: false,
                  localStorage: EmptyLocalStorage(),
                ),
                httpClient: transport,
              );
            } finally {
              if (ownedSupabase == null) {
                // The SDK can create its client before async auth setup fails.
                // Retain that resource for disposal; a rejected getter means
                // no initialized instance is exposed, not a suppressed error.
                try {
                  ownedSupabase = Supabase.instance;
                } on AssertionError {
                  // The original initialize failure still propagates.
                }
              }
            }
            await Supabase.instance.client.auth.setInitialSession(
              jsonEncode({
                'access_token': _token,
                'token_type': 'bearer',
                'user': {
                  'id': owner,
                  'app_metadata': {},
                  'user_metadata': {},
                  'aud': 'authenticated',
                  'created_at': '2026-01-01T00:00:00Z',
                },
              }),
            );
          });
          final database = ownedDatabase = AppDatabase.forTesting(
            NativeDatabase.memory(),
            localOwnerId: owner,
          );
          final container = ownedContainer = ProviderContainer(
            overrides: [databaseProvider.overrideWithValue(database)],
          );
          // This regression starts on an already authenticated Settings route.
          // Settle the real SDK-backed owner stream before observing its credit
          // consumers. Initial owner Loading -> Data can rebuild Vision; it is
          // not a purchase revision and must not be counted as purchase refresh.
          ownerSubscription = container.listen(
            verifiedEntitlementOwnerProvider,
            (_, _) {},
          );
          await _waitUntil(
            tester,
            () =>
                container
                    .read(verifiedEntitlementOwnerProvider)
                    .asData
                    ?.value ==
                owner,
            'the genuine SDK owner stream settles before mounting Settings',
          );
          coach = container.listen(aiCoachCreditAccessProvider, (_, _) {});
          vision = container.listen(aiBoostVisionAccessProvider, (_, _) {});
          bool accessIs(bool value) =>
              container.read(aiCoachCreditAccessProvider).asData?.value ==
                  value &&
              container.read(aiBoostVisionAccessProvider).asData?.value ==
                  value;
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                locale: Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                home: AiCoachSettingsPage(),
              ),
            ),
          );
          await _waitUntil(
            tester,
            () =>
                server.usageReads == 3 &&
                server.activeRequests == 0 &&
                native.catalogReads == 1 &&
                native.updates.hasListener &&
                accessIs(false) &&
                find.text('0').evaluate().length == 1,
            'actual Settings plus both default access loaders at zero',
            diagnostics: () =>
                'usage=${server.usageReads}, requests=${server.activeRequests}, '
                'catalog=${native.catalogReads}, listener=${native.updates.hasListener}, '
                'coach=${container.read(aiCoachCreditAccessProvider)}, '
                'vision=${container.read(aiBoostVisionAccessProvider)}, '
                'zeroWidgets=${find.text('0').evaluate().length}, '
                'httpFailure=${server.failure}',
          );
          expect(server.failure, isNull);
          final baselineReads = server.usageReads;
          await _reach(tester, _buyButton());
          expect(
            tester.widget<FilledButton>(_buyButton()).onPressed,
            isNotNull,
          );
          await tester.tap(_buyButton());
          await _waitUntil(
            tester,
            () =>
                native.launches == 1 &&
                find.text('Waiting for store…').evaluate().isNotEmpty,
            'actual purchase button launches the SDK platform',
          );
          final receipt = _receipt(owner, 'first');
          native.updates.add([receipt]);
          await _waitUntil(
            tester,
            () => server.verificationReads == 1,
            'default service reaches owner-authenticated HTTP verification',
          );
          expect(server.balance, 0);
          expect(server.usageReads, baselineReads);
          expect(accessIs(false), isTrue);
          expect(
            native.finishes,
            0,
            reason:
                'Native success cannot finish or grant before server verification',
          );
          final approved = scenario != _Case.rejectedVerification;
          server.verification.complete(approved);
          if (!approved) {
            await _waitUntil(
              tester,
              () =>
                  server.activeRequests == 0 &&
                  _retryButton().evaluate().length == 1 &&
                  _buyButton().evaluate().length == 1 &&
                  tester.widget<FilledButton>(_buyButton()).onPressed == null,
              'rejected transaction blocks a new charge without verified credit',
            );
            expect(server.usageReads, baselineReads);
            expect(accessIs(false), isTrue);
            expect(server.balance, 0);
            expect(native.finishes, 0);
            await _reach(tester, find.text('0'), towardTop: true);
            expect(find.text('2,500'), findsNothing);
          } else {
            await _waitUntil(
              tester,
              () =>
                  native.finishes == 1 &&
                  server.activeRequests == 0 &&
                  server.usageReads == baselineReads + 3 &&
                  accessIs(true) &&
                  _buyButton().evaluate().length == 1,
              'verification refreshes Settings and both genuine access loaders',
            );
            expect(server.balance, 2500);
            if (scenario == _Case.nativeFinishPending) {
              expect(_retryButton(), findsOneWidget);
              expect(
                tester.widget<FilledButton>(_buyButton()).onPressed,
                isNull,
              );
            } else {
              expect(
                tester.widget<FilledButton>(_buyButton()).onPressed,
                isNotNull,
              );
            }
            final verifiedReads = server.usageReads;
            // Replaying a previously credited receipt may retry native finish;
            // it cannot reverify, add balance, or publish another refresh event.
            native.updates.add([receipt]);
            await _waitUntil(
              tester,
              () => native.finishes == 2,
              'duplicate callback is reconciled through the genuine service',
            );
            expect(server.verificationReads, 1);
            expect(server.usageReads, verifiedReads);
            expect(server.balance, 2500);
            if (scenario == _Case.nativeFinishPending) {
              native.finishFails = false;
              await _reach(tester, _retryButton());
              await tester.tap(_retryButton());
              await _waitUntil(
                tester,
                () =>
                    native.finishes == 3 &&
                    _retryButton().evaluate().isEmpty &&
                    _buyButton().evaluate().length == 1 &&
                    tester.widget<FilledButton>(_buyButton()).onPressed != null,
                'actual retry finishes the existing transaction without a new charge',
              );
              expect(server.verificationReads, 1);
              expect(server.usageReads, verifiedReads);
              expect(native.launches, 1);
            } else {
              await _reach(tester, _buyButton());
              await tester.tap(_buyButton());
              await _waitUntil(
                tester,
                () => native.launches == 2,
                'second actual consumable purchase gesture',
              );
              native.updates.add([_receipt(owner, 'second')]);
              await _waitUntil(
                tester,
                () =>
                    server.verificationReads == 2 &&
                    native.finishes == 3 &&
                    server.activeRequests == 0 &&
                    server.usageReads == verifiedReads + 3 &&
                    accessIs(true),
                'a distinct verified receipt refreshes the same mounted page again',
              );
              expect(server.balance, 5000);
            }
            await _reach(
              tester,
              find.text(
                scenario == _Case.repeatedConsumable ? '5,000' : '2,500',
              ),
              towardTop: true,
            );
            expect(
              server.balance,
              scenario == _Case.repeatedConsumable ? 5000 : 2500,
            );
            expect(accessIs(true), isTrue);
          }
          expect(server.failure, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          final server = ownedServer;
          if (server != null && !server.verification.isCompleted) {
            server.verification.complete(false);
          }
          try {
            try {
              await tester.pumpWidget(const SizedBox.shrink());
            } finally {
              coach?.close();
              vision?.close();
              ownerSubscription?.close();
              ownedContainer?.dispose();
            }
            if (server != null) {
              await _waitUntil(
                tester,
                () => server.activeRequests == 0,
                'owned HTTP work completes before closing the client',
              );
            }
          } finally {
            try {
              final database = ownedDatabase;
              if (database != null) {
                await _finishHost(tester, database.close);
              }
            } finally {
              try {
                final supabase = ownedSupabase;
                if (supabase != null) {
                  await _finishHost(tester, supabase.dispose);
                }
              } finally {
                ownedTransport?.close();
                try {
                  final native = ownedNative;
                  if (native != null) {
                    await _finishHost(tester, native.updates.close);
                  }
                } finally {
                  tester.binding.defaultBinaryMessenger
                      .setMockMethodCallHandler(_storage, null);
                  debugDefaultTargetPlatformOverride = null;
                  tester.view.reset();
                  await tester.pump();
                }
              }
            }
          }
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  }
}

Finder _buyButton() => find.ancestor(
  of: find.text('Buy verified Boost'),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

Finder _retryButton() => find.ancestor(
  of: find.text('Check existing store transaction'),
  matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
);

Future<void> _reach(
  WidgetTester tester,
  Finder target, {
  bool towardTop = false,
}) async {
  final scrollable = find.descendant(
    of: find.byType(AiCoachSettingsPage),
    matching: find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axis == Axis.vertical,
    ),
  );
  expect(scrollable, findsOneWidget);
  for (var gesture = 0; gesture < 20; gesture++) {
    if (target.hitTestable().evaluate().length == 1) return;
    await tester.drag(scrollable, Offset(0, towardTop ? 300 : -300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
  fail(
    'Actual Settings control not reachable with bounded pointer drags: $target',
  );
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() ready,
  String stage, {
  String Function()? diagnostics,
}) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsedMilliseconds < 5000) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull, reason: stage);
  }
  expect(
    ready(),
    isTrue,
    reason: 'Real Settings stage stalled: $stage ${diagnostics?.call() ?? ''}',
  );
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
  await _waitUntil(tester, () => complete, 'genuine host disposal completes');
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}
