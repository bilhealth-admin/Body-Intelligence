import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/services/store_account_visit.dart';
import 'package:body_intelligence_log/features/commerce/services/store_subscription_blocker_recovery.dart';

const empty = NativeStoreSubscriptionInventory(
  currentEntitlementCount: 0,
  unfinishedCount: 0,
);
const visit = StoreAccountSnapshot('synthetic-owner', 1);

SubscriptionState free({
  EntitlementAuthority authority = EntitlementAuthority.verifiedServer,
  Set<CommerceEntitlement> entitlements = FreePlan.entitlements,
  CommercePlan plan = CommercePlan.free,
  SubscriptionState? next,
}) => SubscriptionState(
  plan: plan,
  entitlements: entitlements,
  authority: authority,
  isPurchasable: false,
  canRestorePurchases: false,
  verifiedNextPeriod: next,
);

StoreSubscriptionBlockerRecoveryContext context({
  int blockers = 0,
  String? product = StoreCatalogConfiguration.premiumMonthly,
}) => StoreSubscriptionBlockerRecoveryContext(
  failedSubscriptionProductId: product,
  hasUnresolvedReceipt: (blockers & 1) != 0,
  hasPendingVerifiedFinish: (blockers & 2) != 0,
  hasQueuedUpdates: (blockers & 4) != 0,
  hasUnknownPurchase: (blockers & 8) != 0,
  hasOwnershipConflict: (blockers & 16) != 0,
  hasConsumableFailure: (blockers & 32) != 0,
  isBackedOff: (blockers & 64) != 0,
  hasNativeActivity: (blockers & 128) != 0,
);

final class Reader implements StoreSubscriptionInventoryReader {
  Reader(this.load);
  final Future<NativeStoreSubscriptionInventory> Function(int) load;
  int calls = 0;
  @override
  Future<NativeStoreSubscriptionInventory> read() => load(++calls);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'only known subscriptions, not missing/alias/Boost SKUs, can seek proof',
    () async {
      for (final product in [
        null,
        '',
        'bil_premium ',
        'BIL_PREMIUM',
        'unknown',
        StoreCatalogConfiguration.aiBoost,
      ]) {
        final reader = Reader((_) async => throw StateError('must not read'));
        final result =
            await StoreSubscriptionBlockerRecovery(
              nativeReader: reader,
              freshCanonicalReader: () async =>
                  throw StateError('must not read'),
            ).assess(
              currentContext: () => context(product: product),
              expectedVisit: visit,
              visitIsCurrent: (_) => true,
            );
        expect(result, StoreSubscriptionBlockerRecoveryResult.blocked);
        expect(reader.calls, 0);
      }
    },
  );

  test(
    'all 255 nonempty blocker tuples stop before native or canonical reads',
    () async {
      for (var blockers = 1; blockers < 256; blockers++) {
        var canonicalCalls = 0;
        final reader = Reader((_) async => empty);
        final result =
            await StoreSubscriptionBlockerRecovery(
              nativeReader: reader,
              freshCanonicalReader: () async {
                canonicalCalls++;
                return free();
              },
            ).assess(
              currentContext: () => context(blockers: blockers),
              expectedVisit: visit,
              visitIsCurrent: (_) => true,
            );
        expect(
          result,
          StoreSubscriptionBlockerRecoveryResult.blocked,
          reason: 'tuple $blockers',
        );
        expect(reader.calls, 0);
        expect(canonicalCalls, 0);
      }
    },
  );

  test(
    'eligible proves two empty native reads around a fresh canonical Free read',
    () async {
      for (final product in StoreCatalogConfiguration.productIds) {
        final order = <String>[];
        final reader = Reader((n) async {
          order.add('native$n');
          return empty;
        });
        final result =
            await StoreSubscriptionBlockerRecovery(
              nativeReader: reader,
              freshCanonicalReader: () async {
                order.add('canonical');
                return free();
              },
            ).assess(
              currentContext: () => context(product: product),
              expectedVisit: visit,
              visitIsCurrent: (_) => true,
            );
        expect(result, StoreSubscriptionBlockerRecoveryResult.eligible);
        expect(order, ['native1', 'canonical', 'native2']);
      }
    },
  );

  test('missing or retired owner cannot request recovery', () async {
    for (final owner in [null, '']) {
      final result =
          await StoreSubscriptionBlockerRecovery(
            nativeReader: Reader(
              (_) async => throw StateError('must not read'),
            ),
            freshCanonicalReader: () async => throw StateError('must not read'),
          ).assess(
            currentContext: () => context(),
            expectedVisit: StoreAccountSnapshot(owner, 1),
            visitIsCurrent: (_) => true,
          );
      expect(result, StoreSubscriptionBlockerRecoveryResult.ownerChanged);
    }
  });

  for (final stage in [1, 2, 3]) {
    test(
      'A -> B -> A during await $stage retires the original owner visit',
      () async {
        var owner = 'A';
        final changes = StreamController<String?>.broadcast(sync: true);
        final account = StoreAccountVisit(
          readOwner: () => owner,
          changes: changes.stream,
        );
        final expected = account.capture();
        final pause = Completer<void>();
        final entered = Completer<void>();
        var operation = 0;
        Future<void> step() async {
          operation++;
          if (operation == stage) {
            entered.complete();
            await pause.future;
          }
        }

        final result =
            StoreSubscriptionBlockerRecovery(
              nativeReader: Reader((_) async {
                await step();
                return empty;
              }),
              freshCanonicalReader: () async {
                await step();
                return free();
              },
            ).assess(
              currentContext: () => context(),
              expectedVisit: expected,
              visitIsCurrent: account.isCurrent,
            );
        await entered.future;
        owner = 'B';
        changes.add(owner);
        owner = 'A';
        changes.add(owner);
        pause.complete();
        expect(
          await result,
          StoreSubscriptionBlockerRecoveryResult.ownerChanged,
        );
        expect(operation, stage);
        account.dispose();
        await changes.close();
      },
    );

    test(
      'a new blocker or changed failed SKU during await $stage prevents UI retirement',
      () async {
        for (final changedProduct in [false, true]) {
          var current = context();
          var operation = 0;
          Future<void> step() async {
            if (++operation == stage) {
              current = changedProduct
                  ? context(product: StoreCatalogConfiguration.premiumAnnual)
                  : context(blockers: 128);
            }
          }

          final result =
              await StoreSubscriptionBlockerRecovery(
                nativeReader: Reader((_) async {
                  await step();
                  return empty;
                }),
                freshCanonicalReader: () async {
                  await step();
                  return free();
                },
              ).assess(
                currentContext: () => current,
                expectedVisit: visit,
                visitIsCurrent: (_) => true,
              );
          expect(result, StoreSubscriptionBlockerRecoveryResult.blocked);
          expect(operation, stage);
        }
      },
    );

    test(
      'read failure or timeout at await $stage is unavailable, never empty',
      () async {
        for (final timeout in [false, true]) {
          var operation = 0;
          Future<void> step() async {
            if (++operation == stage) {
              if (timeout) await Completer<void>().future;
              throw StateError('synthetic read failure');
            }
          }

          final result =
              await StoreSubscriptionBlockerRecovery(
                nativeReader: Reader((_) async {
                  await step();
                  return empty;
                }),
                freshCanonicalReader: () async {
                  await step();
                  return free();
                },
                readTimeout: const Duration(milliseconds: 2),
              ).assess(
                currentContext: () => context(),
                expectedVisit: visit,
                visitIsCurrent: (_) => true,
              );
          expect(result, StoreSubscriptionBlockerRecoveryResult.unavailable);
          expect(operation, stage);
        }
      },
    );
  }

  test(
    'either native nonempty snapshot blocks, malformed negative counts fail closed',
    () async {
      for (final snapshot in [
        const NativeStoreSubscriptionInventory(
          currentEntitlementCount: 1,
          unfinishedCount: 0,
        ),
        const NativeStoreSubscriptionInventory(
          currentEntitlementCount: 0,
          unfinishedCount: 1,
        ),
        const NativeStoreSubscriptionInventory(
          currentEntitlementCount: -1,
          unfinishedCount: 0,
        ),
        const NativeStoreSubscriptionInventory(
          currentEntitlementCount: 0,
          unfinishedCount: 10001,
        ),
      ]) {
        for (final position in [1, 2]) {
          final result =
              await StoreSubscriptionBlockerRecovery(
                nativeReader: Reader(
                  (n) async => n == position ? snapshot : empty,
                ),
                freshCanonicalReader: () async => free(),
              ).assess(
                currentContext: () => context(),
                expectedVisit: visit,
                visitIsCurrent: (_) => true,
              );
          expect(
            result,
            snapshot.isValid
                ? StoreSubscriptionBlockerRecoveryResult.blocked
                : StoreSubscriptionBlockerRecoveryResult.unavailable,
          );
        }
      }
    },
  );

  test(
    'local/default Free, paid, hidden paid capabilities or future periods are not canonical Free proof',
    () async {
      for (final canonical in [
        free(authority: EntitlementAuthority.localDefault),
        free(plan: CommercePlan.premium),
        free(
          entitlements: {
            ...FreePlan.entitlements,
            CommerceEntitlement.advancedIntelligence,
          },
        ),
        free(next: free(plan: CommercePlan.premium)),
      ]) {
        final reader = Reader((_) async => empty);
        final result =
            await StoreSubscriptionBlockerRecovery(
              nativeReader: reader,
              freshCanonicalReader: () async => canonical,
            ).assess(
              currentContext: () => context(),
              expectedVisit: visit,
              visitIsCurrent: (_) => true,
            );
        expect(
          result,
          canonical.authority == EntitlementAuthority.localDefault
              ? StoreSubscriptionBlockerRecoveryResult.unavailable
              : StoreSubscriptionBlockerRecoveryResult.blocked,
        );
        expect(reader.calls, 1);
      }
    },
  );

  group('counts-only native channel', () {
    const channel = MethodChannel('bil/store_subscription_blocker_recovery');
    const reader = NativeStoreSubscriptionInventoryReader(channel: channel);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('accepts only an exact verified counts protocol response', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readInventory');
        expect(call.arguments, null);
        return {
          'scopeVersion': 1,
          'currentEntitlementCount': 0,
          'unfinishedCount': 0,
        };
      });
      expect((await reader.read()).isEmpty, true);
    });

    test(
      'null, partial, unknown, unverified and malformed results never become empty',
      () async {
        for (final result in [
          null,
          {},
          {
            'scopeVersion': 1.0,
            'currentEntitlementCount': 0,
            'unfinishedCount': 0,
          },
          {
            'scopeVersion': 0,
            'currentEntitlementCount': 0,
            'unfinishedCount': 0,
          },
          {
            'scopeVersion': 1,
            'currentEntitlementCount': 0.0,
            'unfinishedCount': 0,
          },
          {
            'scopeVersion': 1,
            'currentEntitlementCount': 0,
            'unfinishedCount': -1,
          },
          {
            'scopeVersion': 1,
            'currentEntitlementCount': 10001,
            'unfinishedCount': 0,
          },
          {
            'scopeVersion': 1,
            'currentEntitlementCount': 0,
            'unfinishedCount': 0,
            'unverified': true,
          },
        ]) {
          messenger.setMockMethodCallHandler(channel, (_) async => result);
          await expectLater(reader.read(), throwsFormatException);
        }
      },
    );

    test(
      'native unsupported, error, unverified, timeout and missing plugin are failures',
      () async {
        for (final code in [
          'store_inventory_unsupported',
          'store_inventory_unverified',
          'store_inventory_timeout',
          'store_inventory_unavailable',
        ]) {
          messenger.setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: code),
          );
          await expectLater(reader.read(), throwsA(isA<PlatformException>()));
        }
        messenger.setMockMethodCallHandler(channel, null);
        await expectLater(
          reader.read(),
          throwsA(isA<MissingPluginException>()),
        );
      },
    );

    test('other platforms fail before any native call', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return null;
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await expectLater(reader.read(), throwsUnsupportedError);
      expect(calls, 0);
    });
  });

  test(
    'native source registration is counts-only and uses the actual StoreKit sequences',
    () {
      final source = File(
        'ios/Runner/BILStoreSubscriptionBlockerRecoveryBridge.swift',
      ).readAsStringSync();
      expect(source, contains('StoreKit.Transaction.currentEntitlements'));
      expect(source, contains('StoreKit.Transaction.unfinished'));
      expect(source, contains('guard case .verified = entry'));
      expect(source, contains('guard #available(iOS 15.0, *)'));
      expect(source, contains('store_inventory_timeout'));
      for (final forbidden in [
        'Transaction.all',
        '.finish(',
        '.sync(',
        '.purchase(',
        'jwsRepresentation',
        '.productID',
        '.originalID',
        '.transactionID',
      ]) {
        expect(source.contains(forbidden), false, reason: forbidden);
      }
      expect(
        File('ios/Runner/AppDelegate.swift').readAsStringSync(),
        contains(
          'storeSubscriptionBlockerRecoveryBridge = BILStoreSubscriptionBlockerRecoveryBridge(',
        ),
      );
      expect(
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
        contains('BILStoreSubscriptionBlockerRecoveryBridge.swift in Sources'),
      );
    },
  );
}
