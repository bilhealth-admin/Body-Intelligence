import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'inactive_catalog_ordering_regression_test.dart' as base;

const _owner = '00000000-0000-4000-8000-000000000001';
const _monthly = StoreCatalogConfiguration.premiumMonthly;
const _annual = StoreCatalogConfiguration.premiumAnnual;

class _Native extends base.NativeFixture {
  List<PurchaseDetails> batch = [];
  int restores = 0;
  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restores++;
    updates.add(List.of(batch));
  }
}

class _Store extends VerifiedStorePurchaseService {
  _Store(_Native native)
    : super(purchase: native, handlesBoost: false, appleStoreSync: () async {});
  @override
  bool get configured => true;
}

PurchaseDetails _receipt(
  String id, {
  String product = _monthly,
  String? proof,
}) => PurchaseDetails(
  purchaseID: id,
  productID: product,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'synthetic',
    serverVerificationData: proof ?? 'bad-$id',
    source: 'app_store',
  ),
  status: PurchaseStatus.restored,
  transactionDate: '1',
)..pendingCompletePurchase = true;

class _Fixture {
  final native = _Native();
  late final _Store store;
  final proofs = <String>[];
  List<Map<String, Object?>> rows = [];
  Future<void> open() async {
    SharedPreferences.setMockInitialValues({});
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await Supabase.initialize(
      url: 'https://ownership-classification.invalid',
      publishableKey: 'synthetic-ownership-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        Object? data;
        var status = 200;
        if (request.url.path == '/rest/v1/bil_subscriptions') {
          data = rows;
        } else if (request.url.path == '/functions/v1/verify-store-purchase') {
          final body = jsonDecode(request.body) as Map;
          expect(body['action'], 'verify_purchase');
          final proof = body['verification_data'] as String;
          proofs.add(proof);
          if (proof.startsWith('own-')) {
            final now = DateTime.now().toUtc();
            rows = [
              {
                'provider': 'apple',
                'plan_id': 'premium',
                'lifecycle': 'active',
                'verified_at': now.toIso8601String(),
                'started_at': now
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
                'expires_at': now
                    .add(const Duration(days: 1))
                    .toIso8601String(),
                'grace_period_ends_at': null,
              },
            ];
            data = {
              'verified': true,
              'entitlement_active': true,
              'verified_at': now.toIso8601String(),
            };
          } else {
            status = 400;
            data = {
              'error': 'purchase_owned_by_another_account',
              'verified': false,
              'entitlement_active': false,
            };
          }
        } else {
          throw StateError('Unexpected synthetic HTTP path');
        }
        return http.Response(
          jsonEncode(data),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-ownership-session',
        'token_type': 'bearer',
        'user': {
          'id': _owner,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    store = _Store(native);
    native.settleCatalog();
    await store.initialize();
    expect(store.canStartPurchase, isTrue);
  }

  Future<void> emit(List<PurchaseDetails> receipts) async {
    native.updates.add(receipts);
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      if (!store.busy) return;
    }
    fail('Synthetic receipt queue did not settle');
  }

  Future<void> close() async {
    store.dispose();
    await native.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() async {
    fixture = _Fixture();
    await fixture.open();
  });
  tearDown(() => fixture.close());

  test(
    'explicit ownership Restore survives cooled replay and rejects repeated exact proofs',
    () async {
      final batch = [
        _receipt('history-1'),
        _receipt('history-2'),
        _receipt('history-3'),
      ];
      fixture.native.batch = batch;
      await fixture.store.restore();
      expect(fixture.proofs.length, 3);
      expect(fixture.store.messageCode, 'purchase_owned_by_another_account');
      expect(fixture.store.ownershipConflictProductId, _monthly);
      await fixture.emit([batch.first]);
      expect(fixture.store.messageCode, 'purchase_owned_by_another_account');
      expect(fixture.proofs.length, 3);
      await fixture.store.restore();
      expect(fixture.store.messageCode, 'purchase_owned_by_another_account');
      expect(
        fixture.proofs.length,
        3,
        reason:
            'Same denied proof/owner visit is terminal, not a retryable outage',
      );
      expect(fixture.native.finishes, 0);
      expect(fixture.native.launches, 0);
      expect(fixture.store.entitlement?.grantsPaidAccess, isNot(true));
      expect(fixture.store.canStartPurchase, isFalse);
      expect(fixture.store.canRecoverSubscriptionBlocker, isFalse);
      fixture.native.batch = [
        _receipt('history-1', proof: 'own-new-signed-proof'),
      ];
      await fixture.store.restore();
      expect(
        fixture.proofs.length,
        4,
        reason: 'Changed signed proof must still reach server authority',
      );
      expect(fixture.store.entitlement?.grantsPaidAccess, isTrue);
      expect(fixture.native.finishes, 1);
    },
  );

  test('terminal ownership proof is retired by delivered owner A B A', () async {
    final old = _receipt('visit-scoped-history');
    fixture.native.batch = [old];
    await fixture.store.restore();
    expect(fixture.proofs.length, 1);
    final client = Supabase.instance.client;
    final returned = Completer<void>();
    var sawOther = false;
    final subscription = client.auth.onAuthStateChange.listen((state) {
      final owner = state.session?.user.id;
      if (owner == '00000000-0000-4000-8000-000000000002') sawOther = true;
      if (sawOther && owner == _owner && !returned.isCompleted) {
        returned.complete();
      }
    });
    String session(String owner) {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      return jsonEncode({
        'access_token': 'e30.$payload.synthetic',
        'refresh_token': 'synthetic-owner-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      });
    }

    try {
      await Future.wait([
        client.auth.recoverSession(
          session('00000000-0000-4000-8000-000000000002'),
        ),
        client.auth.recoverSession(session(_owner)),
      ]);
      await returned.future.timeout(const Duration(seconds: 2));
      expect(fixture.store.ownershipConflictProductId, isNull);
      await fixture.store.initialize();
      await fixture.store.restore();
      expect(
        fixture.proofs.length,
        2,
        reason:
            'A retired owner visit cannot suppress verification in a new visit',
      );
      expect(fixture.store.messageCode, 'purchase_owned_by_another_account');
      expect(fixture.native.finishes, 0);
      expect(fixture.native.launches, 0);
      expect(fixture.store.entitlement?.grantsPaidAccess, isNot(true));
    } finally {
      await subscription.cancel();
    }
  });

  for (final ownedFirst in [true, false]) {
    test(
      'owned active Restore and old unrelated conflict retain paid authority (ownedFirst=$ownedFirst)',
      () async {
        final own = _receipt('own-current-month', proof: 'own-current-proof');
        final other = _receipt('old-other-annual', product: _annual);
        fixture.native.batch = ownedFirst ? [own, other] : [other, own];
        await fixture.store.restore();
        expect(fixture.proofs.length, 2);
        expect(fixture.store.entitlement?.grantsPaidAccess, isTrue);
        expect(fixture.store.state, VerifiedStoreState.verified);
        expect(fixture.store.messageCode, 'subscription_verified');
        expect(fixture.store.lastVerifiedProductId, _monthly);
        expect(fixture.store.ownershipConflictProductId, isNot(_monthly));
        expect(fixture.store.verifiedBenefitRevision, 1);
        expect(
          fixture.native.finishes,
          1,
          reason: 'Only the owned verified receipt may finish',
        );
        expect(fixture.native.launches, 0);
        await fixture.emit([other]);
        expect(fixture.store.state, VerifiedStoreState.verified);
        expect(fixture.store.messageCode, 'subscription_verified');
        expect(fixture.store.entitlement?.grantsPaidAccess, isTrue);
        expect(fixture.proofs.length, 2);
      },
    );
  }

  for (final language in ['en', 'ar', 'fr', 'es', 'tr']) {
    testWidgets(
      'real Plans explicit ownership explanation and Restore [$language]',
      (tester) async {
        final old = _receipt('passive-history');
        await tester.runAsync(() => fixture.emit([old]));
        expect(fixture.store.messageCode, 'reconciliation_verification_failed');
        final container = ProviderContainer(
          overrides: [
            verifiedEntitlementOwnerProvider.overrideWith(
              (ref) => Stream.value(_owner),
            ),
            verifiedEntitlementLoaderProvider.overrideWithValue(
              () async => SubscriptionState(
                plan: CommercePlan.free,
                entitlements: FreePlan.entitlements,
                authority: EntitlementAuthority.verifiedServer,
                lifecycle: SubscriptionLifecycle.inactive,
                isPurchasable: true,
                canRestorePurchases: true,
                verifiedAt: DateTime.now().toUtc(),
              ),
            ),
            purchaseOwnershipConflictStoreProvider.overrideWithValue(
              PurchaseOwnershipConflictStore(),
            ),
          ],
        );
        addTearDown(container.dispose);
        try {
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
                home: BilStorePlansPage(
                  store: fixture.store,
                  catalog: VerifiedStoreCatalogAdapter(fixture.store),
                  connectToDeviceStore: false,
                  productIds: const {_monthly},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<BilDynamicStoreOffers>(
                  find.byType(BilDynamicStoreOffers),
                )
                .purchaseStatusMessage,
            isNull,
            reason:
                'Passive reconciliation must not manufacture an account error',
          );
          final cta = find.byKey(const ValueKey('store-purchase-cta'));
          await tester.ensureVisible(cta);
          await tester.tap(cta);
          await tester.pumpAndSettle();
          final expected = BilStoreCopy.text(
            language,
            'purchase_owned_by_another_account',
          );
          expect(find.text(expected), findsWidgets);
          expect(fixture.native.launches, 0);
          fixture.native.batch = [old];
          final restore = find.text(BilStoreCopy.text(language, 'restore'));
          await tester.ensureVisible(restore);
          await tester.tap(restore);
          for (var i = 0; i < 120; i++) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 1)),
            );
            if (fixture.native.restores == 1 && !fixture.store.busy) break;
          }
          await tester.pumpAndSettle();
          expect(fixture.native.restores, 1);
          expect(
            fixture.store.messageCode,
            'purchase_owned_by_another_account',
          );
          expect(find.text(expected), findsWidgets);
          expect(fixture.proofs.length, 1);
          expect(fixture.native.finishes, 0);
          expect(fixture.store.canStartPurchase, isFalse);
          expect(fixture.store.canRecoverSubscriptionBlocker, isFalse);
          expect(fixture.store.verifiedBenefitRevision, 0);
          expect(fixture.store.entitlement?.grantsPaidAccess, isNot(true));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
