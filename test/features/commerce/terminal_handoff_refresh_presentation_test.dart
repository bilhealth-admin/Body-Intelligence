import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/entitlement_resolver.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/verified_purchase_handoff.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 21, 10, 45);

SubscriptionState _proof(
  SubscriptionProvider provider, {
  required bool active,
  required DateTime verifiedAt,
  int? revision,
}) => const EntitlementResolver().resolve(
  record: SubscriptionRecord(
    plan: CommercePlan.premium,
    provider: provider,
    authorityVerified: true,
    lifecycle: active
        ? SubscriptionLifecycle.active
        : SubscriptionLifecycle.expired,
    startedAt: _now.subtract(const Duration(minutes: 4)),
    currentPeriodEndsAt: active
        ? _now.add(const Duration(minutes: 3))
        : _now.subtract(const Duration(minutes: 1)),
    verifiedAt: verifiedAt,
    serverRevision: revision,
  ),
  now: _now,
);

const _offer = BilStoreOfferMetadata(
  productId: 'bil_premium',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Monthly',
  localizedPrice: '£4.99',
  currencyCode: 'GBP',
  priceMicros: 4990000,
  billingPeriodIso8601: 'P1M',
);

class _Catalog implements BilStoreCatalogGateway {
  int purchases = 0;
  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> ids) async => [
    _offer,
  ];
  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    purchases++;
  }

  @override
  Future<void> openManageSubscriptions() async {}
  @override
  Future<void> restorePurchases() async {}
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  late AppDatabase db;
  setUpAll(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });
  tearDownAll(() => db.close());
  for (final provider in [
    SubscriptionProvider.apple,
    SubscriptionProvider.google,
  ]) {
    for (final surface in ['Plans', 'More']) {
      testWidgets(
        '${provider.name} expired monthly keeps $surface stable through two held rereads',
        (tester) async {
          tester.view.physicalSize = const Size(430, 932);
          tester.view.devicePixelRatio = 1;
          final canonicalFree = _proof(
            provider,
            active: false,
            verifiedAt: _now,
          );
          final denied = _proof(
            provider,
            active: false,
            verifiedAt: _now.subtract(const Duration(seconds: 1)),
          );
          final catalog = _Catalog();
          var read = Completer<SubscriptionState>()..complete(canonicalFree);
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              databaseProvider.overrideWithValue(db),
              verifiedEntitlementOwnerIdProvider.overrideWithValue(
                'fixture-owner',
              ),
              verifiedEntitlementClockProvider.overrideWithValue(() => _now),
              verifiedEntitlementLoaderProvider.overrideWithValue(
                () => read.future,
              ),
            ],
          );
          try {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: surface == 'Plans'
                      ? BilStorePlansPage(
                          catalog: catalog,
                          connectToDeviceStore: false,
                          productIds: const {'bil_premium'},
                        )
                      : const SettingsPage(),
                ),
              ),
            );
            await _flush(tester);
            container
                .read(verifiedPurchaseHandoffProvider.notifier)
                .publish(denied);
            await _flush(tester);
            final entry = surface == 'Plans'
                ? find.byKey(const Key('store-purchase-cta'))
                : find.text('Explore Premium');
            expect(
              entry,
              findsOneWidget,
              reason: 'Complete same-owner verified Free read',
            );
            for (var i = 0; i < 2; i++) {
              read = Completer<SubscriptionState>();
              container.invalidate(verifiedSubscriptionStateProvider);
              await _flush(tester);
              expect(
                container.read(verifiedSubscriptionAccessProvider).isLoading,
                isTrue,
              );
              expect(
                entry,
                findsOneWidget,
                reason: 'Held reread $i retired the verified Free presentation',
              );
              if (surface == 'Plans' && i == 0) {
                await tester.tap(entry);
                await _flush(tester);
                expect(
                  catalog.purchases,
                  0,
                  reason: 'Held authority cannot start checkout',
                );
                expect(find.text('Checking subscription'), findsOneWidget);
                await tester.pumpAndSettle();
                await tester.pump(const Duration(seconds: 5));
                await tester.pumpAndSettle();
              }
              read.complete(canonicalFree);
              await _flush(tester);
              expect(entry, findsOneWidget);
            }
            if (surface == 'Plans') {
              read = Completer<SubscriptionState>();
              container.invalidate(verifiedSubscriptionStateProvider);
              await _flush(tester);
              read.completeError(StateError('fixture outage'));
              await _flush(tester);
              expect(entry, findsOneWidget);
              await tester.tap(entry);
              await tester.pumpAndSettle();
              expect(
                find.text('Subscription check unavailable'),
                findsOneWidget,
              );
              final retry = find.widgetWithText(SnackBarAction, 'Try again');
              expect(retry, findsOneWidget);
              read = Completer<SubscriptionState>();
              await tester.tap(retry);
              await tester.pumpAndSettle();
              expect(
                container.read(verifiedSubscriptionStateProvider).isLoading,
                isTrue,
              );
              read.complete(canonicalFree);
              await _flush(tester);
              expect(
                catalog.purchases,
                0,
                reason: 'Retry only rechecks the account',
              );
              await tester.tap(entry);
              await _flush(tester);
              expect(
                catalog.purchases,
                1,
                reason: 'A fresh tap after canonical Free starts checkout once',
              );
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
            await _flush(tester);
            tester.view.reset();
          }
        },
      );
    }
    testWidgets(
      '${provider.name} a store denial alone cannot seed a composite Free display during reread',
      (tester) async {
        final paid = _proof(
          provider,
          active: true,
          verifiedAt: _now.subtract(const Duration(minutes: 1)),
        );
        var read = Completer<SubscriptionState>()..complete(paid);
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              'fixture-owner',
            ),
            verifiedEntitlementClockProvider.overrideWithValue(() => _now),
            verifiedEntitlementLoaderProvider.overrideWithValue(
              () => read.future,
            ),
          ],
        );
        final sub = container.listen(
          verifiedSubscriptionPresentationProvider,
          (_, _) {},
        );
        try {
          await _flush(tester);
          expect(sub.read().value?.plan, CommercePlan.premium);
          container
              .read(verifiedPurchaseHandoffProvider.notifier)
              .publish(_proof(provider, active: false, verifiedAt: _now));
          await _flush(tester);
          expect(sub.read().value?.plan, CommercePlan.free);
          read = Completer<SubscriptionState>();
          container.invalidate(verifiedSubscriptionStateProvider);
          await _flush(tester);
          expect(
            sub.read().value,
            isNull,
            reason:
                'Independent account grants have not been checked since the store-only denial',
          );
          expect(
            container.read(verifiedSubscriptionAccessProvider).isLoading,
            isTrue,
          );
        } finally {
          sub.close();
          container.dispose();
          await _flush(tester);
        }
      },
    );
    test(
      '${provider.name} ordered rows settle a denial even with equal or reversed timestamps',
      () {
        final denied = _proof(
          provider,
          active: false,
          revision: 20,
          verifiedAt: _now,
        );
        final lower = _proof(
          provider,
          active: true,
          revision: 19,
          verifiedAt: _now.add(const Duration(seconds: 1)),
        );
        final newer = _proof(
          provider,
          active: true,
          revision: 21,
          verifiedAt: _now.subtract(const Duration(seconds: 1)),
        );
        expect(
          purchaseHandoffView(AsyncData(lower), denied, _now).value?.plan,
          CommercePlan.free,
        );
        expect(
          purchaseHandoffView(AsyncData(newer), denied, _now).value?.plan,
          CommercePlan.premium,
        );
        final same = _proof(provider, active: true, verifiedAt: _now);
        expect(
          purchaseHandoffView(AsyncData(same), denied, _now).value?.plan,
          CommercePlan.free,
        );
      },
    );
    testWidgets(
      '${provider.name} newer repurchase survives stale inactive handoff during reread, fresh denial immediately wins',
      (tester) async {
        final paid = _proof(provider, active: true, verifiedAt: _now);
        var read = Completer<SubscriptionState>()..complete(paid);
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              'fixture-owner',
            ),
            verifiedEntitlementClockProvider.overrideWithValue(() => _now),
            verifiedEntitlementLoaderProvider.overrideWithValue(
              () => read.future,
            ),
          ],
        );
        final sub = container.listen(
          verifiedSubscriptionAccessProvider,
          (_, _) {},
        );
        try {
          await _flush(tester);
          final handoff = container.read(
            verifiedPurchaseHandoffProvider.notifier,
          );
          handoff.publish(
            _proof(
              provider,
              active: false,
              verifiedAt: _now.subtract(const Duration(seconds: 1)),
            ),
          );
          await _flush(tester);
          expect(sub.read().value?.plan, CommercePlan.premium);
          read = Completer<SubscriptionState>();
          container.invalidate(verifiedSubscriptionStateProvider);
          await _flush(tester);
          expect(
            sub.read().value?.plan,
            CommercePlan.premium,
            reason: 'Newer canonical paid proof still covers this instant',
          );
          handoff.publish(
            _proof(
              provider,
              active: false,
              verifiedAt: _now.add(const Duration(seconds: 1)),
            ),
          );
          await _flush(tester);
          expect(sub.read().value?.plan, isNot(CommercePlan.premium));
          read.complete(paid);
          await _flush(tester);
          expect(sub.read().value?.plan, CommercePlan.free);
        } finally {
          sub.close();
          container.dispose();
          await _flush(tester);
        }
      },
    );
  }
}
