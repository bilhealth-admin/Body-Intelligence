import '../../support/google_subscription_replacement_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/app/security/bil_integrity_exception.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/services/android_store_purchase_readiness.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '00000000-0000-4000-8000-000000000001';
const denial = BilIntegrityException(
  'license_unlicensed',
  recoveryHandle: 'lease',
  recoveryOwner: owner,
);
ProductDetails product(
  String id, [
  String currency = 'USD',
  double price = 2.49,
]) => ProductDetails(
  id: id,
  title: id,
  description: 'fixture',
  price: '$currency $price',
  rawPrice: price,
  currencyCode: currency,
);

class Native extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  var launches = 0, finishes = 0, queries = 0;
  String currency = 'USD';
  double amount = 2.49;
  Future<void> Function()? beforeQuery;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> countryCode() async => 'JOR';
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queries++;
    await beforeQuery?.call();
    return ProductDetailsResponse(
      productDetails: [product(ids.single, currency, amount)],
      notFoundIDs: [],
    );
  }

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
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    launches++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    finishes++;
  }
}

class Store extends VerifiedStorePurchaseService {
  Store(Native native, AndroidStorePurchaseReadiness gate)
    : super(
        googleReplacementReader: emptyGoogleSubscriptionProofFixture(),
        purchase: native,
        androidReadiness: gate,
      );
  @override
  bool get configured => true;
}

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Native native;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.invalid',
      publishableKey: 'fixture-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (_) async => throw StateError('No verification/HTTP expected'),
      ),
    );
    await Supabase.instance.client.auth.setInitialSession(
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
    );
    native = Native();
  });
  tearDown(() async {
    await native.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  for (final recoverSuccess in [false, true]) {
    for (final lane in ['subscription', 'legacy-boost', 'dedicated-boost']) {
      test(
        '$lane denied/recovery=$recoverSuccess never launches or leaves false pending',
        () async {
          var probes = 0, dialogs = 0;
          final gate = AndroidStorePurchaseReadiness(
            probe: (_, _) async {
              probes++;
              if (probes == 1 || !recoverSuccess) throw denial;
            },
            recover: (_) async {
              dialogs++;
              return recoverSuccess;
            },
            release: (_) async {},
          );
          if (lane == 'dedicated-boost') {
            final service = AiBoostPurchaseService(
              purchase: native,
              owner: () => owner,
              ownerChanges: const Stream.empty(),
              verify: (_, _) async => true,
              reconcile: () async => [],
              androidReadiness: gate,
            );
            try {
              await service.initialize();
              await service.purchaseBoost();
              expect(service.state, AiBoostPurchaseState.ready);
              expect(
                service.errorCode,
                recoverSuccess
                    ? 'play_license_recovered'
                    : 'license_unlicensed',
              );
              expect(service.verifiedCreditsRevision, 0);
            } finally {
              service.dispose();
            }
          } else {
            final service = Store(native, gate)
              ..state = VerifiedStoreState.ready
              ..products = {
                'bil_premium_ai_coach': product('bil_premium_ai_coach'),
                AiBoostPurchaseService.productId: product(
                  AiBoostPurchaseService.productId,
                ),
              };
            try {
              if (lane == 'subscription') {
                await service.purchasePlan(
                  CommercePlan.premiumAiCoach,
                  term: SubscriptionTerm.oneMonth,
                );
              } else {
                await service.purchaseBoost();
              }
              expect(service.state, VerifiedStoreState.ready);
              expect(service.busy, isFalse);
              expect(
                service.messageCode,
                recoverSuccess
                    ? 'play_license_recovered'
                    : 'license_unlicensed',
              );
              expect(service.verifiedBenefitRevision, 0);
            } finally {
              service.dispose();
            }
          }
          expect(native.launches, 0);
          expect(native.finishes, 0);
          expect(dialogs, 1);
        },
      );
    }
  }
  test(
    'dedicated Boost fresh quote change blocks charge and updates visible quote',
    () async {
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, _) async {},
        recover: (_) async => true,
        release: (_) async {},
      );
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => owner,
        ownerChanges: const Stream.empty(),
        verify: (_, _) async => true,
        reconcile: () async => [],
        androidReadiness: gate,
      );
      try {
        await service.initialize();
        native.currency = 'EGP';
        native.amount = 119.99;
        await service.purchaseBoost(
          expectedPrice: 'USD 2.49',
          expectedCurrency: 'USD',
        );
        expect(native.launches, 0);
        expect(service.errorCode, 'store_catalog_changed');
        expect(service.displayPrice, 'EGP 119.99');
        expect(service.product!.currencyCode, 'EGP');
        expect(service.state, AiBoostPurchaseState.ready);
        expect(service.verifiedCreditsRevision, 0);
      } finally {
        service.dispose();
      }
    },
  );
  test(
    'legacy Boost refreshes quote after held readiness and blocks changed currency',
    () async {
      final held = Completer<void>();
      final entered = Completer<void>();
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, _) {
          entered.complete();
          return held.future;
        },
        recover: (_) async => true,
        release: (_) async {},
      );
      final service = Store(native, gate)
        ..state = VerifiedStoreState.ready
        ..products = {
          AiBoostPurchaseService.productId: product(
            AiBoostPurchaseService.productId,
          ),
        };
      try {
        final buying = service.purchaseBoost();
        await entered.future;
        native.currency = 'EGP';
        native.amount = 119.99;
        held.complete();
        await buying;
        expect(native.launches, 0);
        expect(service.messageCode, 'store_catalog_changed');
        expect(
          service.products[AiBoostPurchaseService.productId]!.currencyCode,
          'EGP',
        );
        expect(service.state, VerifiedStoreState.ready);
        expect(service.busy, isFalse);
      } finally {
        service.dispose();
      }
    },
  );
  test(
    'resume initialize cannot reopen held dedicated Boost quote or allow a second charge',
    () async {
      final held = Completer<void>();
      final entered = Completer<void>();
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, _) async {},
        recover: (_) async => true,
        release: (_) async {},
      );
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => owner,
        ownerChanges: const Stream.empty(),
        verify: (_, _) async => true,
        reconcile: () async => [],
        androidReadiness: gate,
      );
      try {
        await service.initialize();
        native.beforeQuery = () {
          if (native.queries == 2) {
            entered.complete();
            return held.future;
          }
          return Future<void>.value();
        };
        final buying = service.purchaseBoost();
        await entered.future;
        await service.initialize();
        expect(service.canPurchase, isFalse);
        await service.purchaseBoost();
        expect(native.launches, 0);
        expect(native.queries, 2);
        held.complete();
        await buying;
        expect(native.launches, 1);
      } finally {
        service.dispose();
      }
    },
  );
  test(
    'iOS legacy handoff gains no Android-await gap or attestation work',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var probes = 0;
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, _) async {
          probes++;
        },
        recover: (_) async => true,
        release: (_) async {},
      );
      final service = Store(native, gate)
        ..state = VerifiedStoreState.ready
        ..products = {
          AiBoostPurchaseService.productId: product(
            AiBoostPurchaseService.productId,
          ),
        };
      final buying = service.purchaseBoost();
      expect(native.launches, 1);
      expect(probes, 0);
      service.dispose();
      await buying;
      expect(native.launches, 1);
      expect(native.queries, 0);
      expect(native.finishes, 0);
    },
  );
  test(
    'unresolved prior receipt stays blocked after explicit license repair with no automatic retry',
    () async {
      var verifies = 0, probes = 0;
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, _) async {
          probes++;
          if (probes == 1) throw denial;
        },
        recover: (_) async => true,
        release: (_) async {},
      );
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => owner,
        ownerChanges: const Stream.empty(),
        verify: (_, _) async {
          verifies++;
          throw denial;
        },
        reconcile: () async => [],
        androidReadiness: gate,
      );
      try {
        await service.initialize();
        native.updates.add([
          PurchaseDetails(
            purchaseID: 'prior-receipt',
            productID: AiBoostPurchaseService.productId,
            verificationData: PurchaseVerificationData(
              localVerificationData: '',
              serverVerificationData: 'synthetic-prior-unresolved',
              source: 'google_play',
            ),
            transactionDate: '1',
            status: PurchaseStatus.purchased,
          )..pendingCompletePurchase = true,
        ]);
        await settle();
        expect(verifies, 1);
        expect(service.canPurchase, isFalse);
        expect(service.canRecoverPlayLicense, isTrue);
        await service.recoverPlayLicense();
        expect(service.errorCode, 'play_license_recovered_pending');
        expect(service.canPurchase, isFalse);
        expect(service.state, AiBoostPurchaseState.failed);
        expect(verifies, 1);
        expect(native.launches, 0);
        expect(native.finishes, 0);
        expect(service.verifiedCreditsRevision, 0);
        expect(service.lastDelivery, isNull);
      } finally {
        service.dispose();
      }
    },
  );
}
