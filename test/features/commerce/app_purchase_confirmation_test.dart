// Actual queue/providers/SQLite journal/root coordinator/Flutter surfaces.
// Native SDK and authenticated delivery boundary are controlled fixtures;
// not a financial ledger, device, StoreKit, Play or Production test.
import 'dart:async';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_benefit_delivery.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/presentation/app_purchase_coordinator.dart';
import 'package:body_intelligence_log/features/commerce/presentation/app_purchase_presentation_routes.dart';
import 'package:body_intelligence_log/features/commerce/providers/app_purchase_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:body_intelligence_log/shared/widgets/bil_experience_presentation.dart';
import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../visual_closure/closure_surface_capture.dart';
import '../../visual_closure/visual_evidence_font.dart';

class _Native extends InAppPurchasePlatform {
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
          ProductDetails(
            id: StoreCatalogConfiguration.aiBoost,
            title: 'Fixture',
            description: 'Mock store boundary',
            price: '2.49',
            rawPrice: 2.49,
            currencyCode: 'USD',
          ),
        ],
        notFoundIDs: const [],
      );
  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    expect(autoConsume, isFalse);
    launches++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    finishes++;
    return finish.future;
  }
}

class _QuietSubscriptionLane extends VerifiedStorePurchaseService {
  @override
  Future<void> initialize() async {}
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final width in [390.0, 320.0]) {
    testWidgets(
      'Boost confirmation after route exit before native finish at $width',
      (tester) async {
        expect(
          AppEnvironment.commerceConfigured,
          isTrue,
          reason: 'run with fixture purchase-review defines',
        );
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        final native = _Native();
        debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
        InAppPurchasePlatform.instance = native;
        final sdk = InAppPurchase.instance;
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        SharedPreferences.setMockInitialValues({});
        final http = MockClient(
          (request) async =>
              throw StateError('No network permitted: ${request.url.path}'),
        );
        await tester.runAsync(
          () => Supabase.initialize(
            url: 'https://purchase-fixture.invalid',
            publishableKey: 'fixture',
            debug: false,
            httpClient: http,
            authOptions: const FlutterAuthClientOptions(
              autoRefreshToken: false,
              detectSessionInUri: false,
              localStorage: EmptyLocalStorage(),
            ),
          ),
        );
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'fixture-A',
        );
        await tester.runAsync(() => db.customSelect('SELECT 1').get());
        final delivery = StoreBenefitDelivery(
          ownerId: 'fixture-A',
          store: 'app_store',
          environment: 'sandbox',
          eventKey: List.filled(64, 'b').join(),
          productId: StoreCatalogConfiguration.aiBoost,
          verifiedAt: DateTime.now().toUtc(),
          active: true,
          isBoost: true,
          quantity: 730,
          creditedNow: true,
          finishPending: false,
        );
        final verify = Completer<StoreVerificationOutcome>();
        final boost = AiBoostPurchaseService(
          purchase: sdk,
          owner: () => 'fixture-A',
          verifyDelivery: (_, _) => verify.future,
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            verifiedEntitlementOwnerIdProvider.overrideWithValue('fixture-A'),
            appBoostPurchaseFactoryProvider.overrideWithValue(() => boost),
            appSubscriptionPurchaseFactoryProvider.overrideWithValue(
              _QuietSubscriptionLane.new,
            ),
          ],
        );
        final draft = TextEditingController(text: 'مسودة محفوظة');
        var continued = false;
        VoidCallback? release;
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
                    key: const Key('purchase-root-capture'),
                    child: AppPurchaseCoordinator(child: child!),
                  ),
                ),
                home: Scaffold(
                  body: Column(
                    children: [
                      TextField(controller: draft),
                      FilledButton(
                        onPressed: () => continued = true,
                        child: const Text('إجراء مجاني'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await _until(tester, () => boost.canPurchase);
          final checkout = MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Checkout route')),
          );
          unawaited(bilAppNavigatorKey.currentState!.push(checkout));
          await tester.pumpAndSettle();
          await boost.purchaseBoost();
          expect(native.launches, 1);
          native.updates.add([
            PurchaseDetails(
              purchaseID: 'fixture-transaction-1',
              productID: StoreCatalogConfiguration.aiBoost,
              verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: 'fixture',
                source: 'app_store',
              ),
              transactionDate: '0',
              status: PurchaseStatus.purchased,
            )..pendingCompletePurchase = true,
          ]);
          await tester.pump();
          bilAppNavigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
          release = BilExperiencePresentation.tryClaim();
          expect(release, isNotNull);
          verify.complete(StoreVerificationOutcome(true, delivery: delivery));
          await _until(
            tester,
            () =>
                boost.state == AiBoostPurchaseState.verified &&
                native.finishes == 1,
          );
          expect(native.finish.isCompleted, isFalse);
          expect(
            find.byKey(const Key('store-benefit-confirmation')),
            findsNothing,
          );
          release!();
          release = null;
          await _until(
            tester,
            () => find
                .byKey(const Key('store-benefit-confirmation'))
                .evaluate()
                .isNotEmpty,
          );
          expect(
            find.text('تمت إضافة \u2066730 BIL AI Tokens\u2069'),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('store-confirmation-sandbox')),
            findsOneWidget,
          );
          expect(draft.text, 'مسودة محفوظة');
          await captureClosureFrames(
            tester,
            find.byKey(const Key('purchase-root-capture')),
            'boost-ar-$width-reduced',
            step: 'trusted-delivery-before-held-native-finish',
            frames: 20,
          );
          final trace = boost.checkoutTrace!.toSafeMap();
          final timings = trace['stages'] as Map;
          expect(timings['serverProof'], isA<int>());
          expect(
            timings['benefitPublished'],
            greaterThanOrEqualTo(timings['serverProof'] as int),
          );
          expect(timings['finishCompleted'], isNull);
          expect(trace.toString(), isNot(contains('fixture-A')));
          expect(trace.toString(), isNot(contains('fixture-transaction')));
          expect(
            native.finish.isCompleted,
            isFalse,
            reason: 'proof presentation is independent of native finish',
          );
          await tester.pump(const Duration(milliseconds: 400));
          await captureClosureSurface(
            tester,
            find.byKey(const Key('purchase-root-capture')),
            'purchase-boost-ar-$width',
          );
          await tester.tap(
            find.byKey(const Key('store-confirmation-continue')),
          );
          await tester.pumpAndSettle();
          await captureClosureFrames(
            tester,
            find.byKey(const Key('purchase-root-capture')),
            'boost-ar-$width-reduced',
            step: 'real-continue-keeps-draft',
          );
          native.finish.complete();
          await _until(tester, () => boost.canPurchase);
          native.updates.add([
            PurchaseDetails(
              purchaseID: 'fixture-transaction-1',
              productID: StoreCatalogConfiguration.aiBoost,
              verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: 'rotated-fixture',
                source: 'app_store',
              ),
              transactionDate: '0',
              status: PurchaseStatus.restored,
            ),
          ]);
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            find.byKey(const Key('store-benefit-confirmation')),
            findsNothing,
          );
          expect(boost.verifiedCreditsRevision, 1);
          await tester.tap(find.text('إجراء مجاني'));
          expect(continued, isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          release?.call();
          if (!native.finish.isCompleted) native.finish.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          container.dispose();
          draft.dispose();
          await tester.runAsync(() async {
            await db.close();
            await Supabase.instance.dispose();
            await native.updates.close();
          });
          http.close();

          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}
