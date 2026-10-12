// Actual authenticated HTTP adapter, receipt queue, canonical row, providers,
// SQLite journal and Flutter root. Native store/server are isolated fixtures;
// this does not prove a device purchase, a financial ledger or Production.
import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/shared/widgets/bil_experience_presentation.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/presentation/app_purchase_coordinator.dart';
import 'package:body_intelligence_log/features/commerce/presentation/app_purchase_presentation_routes.dart';
import 'package:body_intelligence_log/features/commerce/providers/app_purchase_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../visual_closure/closure_surface_capture.dart';
import '../../visual_closure/visual_evidence_font.dart';

class _SubscriptionNative extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  final finish = Completer<void>();
  int launches = 0, finishes = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          AppStoreProduct2Details.fromSK2Product(
            SK2Product(
              id: StoreCatalogConfiguration.premiumMonthly,
              displayName: 'Premium',
              description: 'Isolated store boundary',
              displayPrice: '2.49',
              price: 2.49,
              type: SK2ProductType.autoRenewable,
              priceLocale: SK2PriceLocale(
                currencyCode: 'USD',
                currencySymbol: r'$',
              ),
              subscription: SK2SubscriptionInfo(
                subscriptionGroupID: 'fixture-premium',
                promotionalOffers: const [],
                subscriptionPeriod: const SK2SubscriptionPeriod(
                  value: 1,
                  unit: SK2SubscriptionPeriodUnit.month,
                ),
              ),
            ),
          ),
        ],
        notFoundIDs: const [],
      );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    launches++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    finishes++;
    return finish.future;
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final lifecycle in ['active', 'trial']) {
    testWidgets(
      'root subscription $lifecycle proof unlocks before native finish after route exit',
      (tester) async {
        expect(AppEnvironment.commerceConfigured, isTrue);
        final width = lifecycle == 'trial' ? 320.0 : 390.0;
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        final native = _SubscriptionNative();
        debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
        InAppPurchasePlatform.instance = native;
        final sdk = InAppPurchase.instance;
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        SharedPreferences.setMockInitialValues({});
        const owner = '00000000-0000-4000-8000-000000000001';
        final at = DateTime.now().toUtc();
        var rows = <Map<String, Object?>>[];
        final verification = Completer<http.Response>();
        var verifies = 0, rowReads = 0;
        final requestPaths = <String>[];
        await tester.runAsync(
          () => Supabase.initialize(
            url: 'https://subscription-fixture.invalid',
            publishableKey: 'fixture',
            debug: false,
            authOptions: const FlutterAuthClientOptions(
              autoRefreshToken: false,
              detectSessionInUri: false,
              localStorage: EmptyLocalStorage(),
            ),
            httpClient: MockClient((request) async {
              requestPaths.add(request.url.path);
              if (request.url.path == '/rest/v1/bil_subscriptions') {
                rowReads++;
                return http.Response(
                  jsonEncode(rows),
                  200,
                  headers: {'content-type': 'application/json'},
                  request: request,
                );
              }
              if (request.url.path == '/functions/v1/verify-store-purchase') {
                final body = jsonDecode(request.body) as Map;
                expect(body['delivery_version'], 2);
                expect(
                  body['product_id'],
                  StoreCatalogConfiguration.premiumMonthly,
                );
                verifies++;
                return verification.future;
              }
              throw StateError(
                'No other network permitted: ${request.url.path}',
              );
            }),
          ),
        );
        await tester.runAsync(
          () => Supabase.instance.client.auth.setInitialSession(
            jsonEncode({
              'access_token': 'fixture-token',
              'token_type': 'bearer',
              'user': {
                'id': owner,
                'app_metadata': {},
                'user_metadata': {},
                'aud': 'authenticated',
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
          ),
        );
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: owner,
        );
        await tester.runAsync(() => db.customSelect('SELECT 1').get());
        final service = VerifiedStorePurchaseService(
          purchase: sdk,
          handlesBoost: false,
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            verifiedEntitlementOwnerIdProvider.overrideWithValue(owner),
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(
                SubscriptionState(
                  plan: CommercePlan.free,
                  entitlements: FreePlan.entitlements,
                  authority: EntitlementAuthority.verifiedServer,
                  isPurchasable: true,
                  canRestorePurchases: true,
                  verifiedAt: at.subtract(const Duration(seconds: 1)),
                ),
              ),
            ),
            appSubscriptionPurchaseFactoryProvider.overrideWithValue(
              () => service,
            ),
            appBoostPurchaseFactoryProvider.overrideWithValue(
              () => AiBoostPurchaseService(purchase: sdk, owner: () => owner),
            ),
          ],
        );
        final draft = TextEditingController(text: 'مسودة لا تُمحى');
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                navigatorKey: bilAppNavigatorKey,
                navigatorObservers: [bilStorePresentationRouteObserver],
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: visualEvidenceTheme(
                  BilFlagshipTheme.light(isArabic: true),
                  fontFamily: 'NotoArabicEvidence',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 2 : 1),
                    disableAnimations: true,
                  ),
                  child: RepaintBoundary(
                    key: const Key('subscription-root-capture'),
                    child: AppPurchaseCoordinator(child: child!),
                  ),
                ),
                home: Scaffold(body: TextField(controller: draft)),
              ),
            ),
          );
          await _until(tester, () => service.canStartPurchase);
          unawaited(
            bilAppNavigatorKey.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(body: Text('Plans fixture route')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => service.purchasePlan(
              CommercePlan.premium,
              term: SubscriptionTerm.oneMonth,
            ),
          );
          expect(native.launches, 1);
          native.updates.add([
            PurchaseDetails(
              purchaseID: 'subscription-fixture-transaction',
              productID: StoreCatalogConfiguration.premiumMonthly,
              verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: 'fixture',
                source: 'app_store',
              ),
              transactionDate: '0',
              status: PurchaseStatus.purchased,
            )..pendingCompletePurchase = true,
          ]);
          await _until(tester, () => verifies == 1);
          expect(
            find.byKey(const Key('store-benefit-confirmation')),
            findsNothing,
          );
          expect(
            container.read(verifiedSubscriptionAccessProvider).value?.plan,
            CommercePlan.free,
          );
          bilAppNavigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
          rows = [
            {
              'provider': 'apple',
              'plan_id': 'premium',
              'lifecycle': lifecycle,
              'verified_at': at.toIso8601String(),
              'started_at': at.toIso8601String(),
              'expires_at': at.add(const Duration(days: 3)).toIso8601String(),
              'grace_period_ends_at': null,
            },
          ];
          verification.complete(
            http.Response(
              jsonEncode({
                'verified': true,
                'entitlement_active': true,
                'delivery': {
                  'version': 2,
                  'owner_id': owner,
                  'store': 'app_store',
                  'environment': 'sandbox',
                  'product_id': StoreCatalogConfiguration.premiumMonthly,
                  'event_key': List.filled(
                    64,
                    lifecycle == 'trial' ? 'd' : 'c',
                  ).join(),
                  'verified_at': at.toIso8601String(),
                  'kind': 'subscription',
                  'active': true,
                  'finish_pending': false,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
          await _until(
            tester,
            () => find
                .byKey(const Key('store-benefit-confirmation'))
                .evaluate()
                .isNotEmpty,
            detail: () =>
                '${service.state} ${service.messageCode}; '
                'active=${service.entitlement?.grantsPaidAccess}; '
                'proof=${service.lastDelivery?.active}; nativeFinish=${native.finishes}; '
                'user=${service.lastDeliveryIsUserPurchase}; deliveryCurrent=${service.lastDelivery == null ? false : service.deliveryIsActive(service.lastDelivery!.eventKey)}; '
                'lease=${BilExperiencePresentation.occupied.value}; blocked=${bilStorePresentationRouteObserver.blocked}; '
                'rowReads=$rowReads paths=$requestPaths',
          );
          expect(service.state, VerifiedStoreState.verified);
          expect(native.finish.isCompleted, isFalse);
          expect(native.finishes, 1);
          expect(
            container.read(verifiedSubscriptionAccessProvider).value?.plan,
            CommercePlan.premium,
          );
          expect(draft.text, 'مسودة لا تُمحى');
          await captureClosureFrames(
            tester,
            find.byKey(const Key('subscription-root-capture')),
            'subscription-$lifecycle-ar-$width-reduced',
            step: 'canonical-active-before-held-native-finish',
            frames: 20,
          );
          expect(find.text('أهلًا بك في BIL Premium'), findsOneWidget);
          expect(
            find.text(
              lifecycle == 'trial'
                  ? 'بدأت فترتك التجريبية. ميزات خطتك جاهزة للاستخدام.'
                  : 'تم تفعيل خطتك. ميزاتها جاهزة للاستخدام.',
            ),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 400));
          await captureClosureSurface(
            tester,
            find.byKey(const Key('subscription-root-capture')),
            'purchase-subscription-$lifecycle-ar-$width',
          );
          await tester.tap(
            find.byKey(const Key('store-confirmation-continue')),
          );
          await tester.pumpAndSettle();
          await captureClosureFrames(
            tester,
            find.byKey(const Key('subscription-root-capture')),
            'subscription-$lifecycle-ar-$width-reduced',
            step: 'real-continue-keeps-draft',
          );
          native.finish.complete();
          await _until(tester, () => !service.busy);
          expect(verifies, 1);
          expect(tester.takeException(), isNull);
        } finally {
          if (!native.finish.isCompleted) native.finish.complete();
          if (!verification.isCompleted) {
            verification.complete(http.Response('{"verified":false}', 200));
          }
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          draft.dispose();
          await native.updates.close();
          await tester.runAsync(db.close);
          await tester.runAsync(() => Supabase.instance.dispose());
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  String Function()? detail,
}) async {
  for (var i = 0; i < 120; i++) {
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    ready(),
    isTrue,
    reason:
        'bounded real queue/SQLite presentation did not settle: ${detail?.call()}',
  );
}
