import 'dart:async';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> usage(String plan, Object? totalRemaining) => {
  'plan': plan,
  'credits': <String, Object?>{'total_remaining': totalRemaining},
};

void main() {
  test(
    'owner refresh keeps prior identity and authoritative sign-out clears it',
    () async {
      final initial = StreamController<String?>();
      final refreshed = StreamController<String?>();
      var stream = initial.stream;
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerProvider.overrideWith((_) => stream),
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
        ],
      );
      final listener = container.listen(
        verifiedEntitlementOwnerIdProvider,
        (_, _) {},
      );
      addTearDown(() async {
        listener.close();
        container.dispose();
        await initial.close();
        await refreshed.close();
      });
      initial.add('owner-a');
      await container.read(verifiedEntitlementOwnerProvider.future);
      expect(container.read(verifiedEntitlementOwnerIdProvider), 'owner-a');
      stream = refreshed.stream;
      container.invalidate(verifiedEntitlementOwnerProvider);
      expect(container.read(verifiedEntitlementOwnerIdProvider), 'owner-a');
      expect(
        container.read(verifiedEntitlementOwnerProvider).isLoading,
        isTrue,
      );
      refreshed.add(null);
      await container.read(verifiedEntitlementOwnerProvider.future);
      expect(container.read(verifiedEntitlementOwnerIdProvider), isNull);
    },
  );

  test(
    'same-owner refresh failure retains verified access, then zero revokes it',
    () async {
      Future<Object?> response = Future.value(usage('ai_coach', 1000));
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => const Stream<String?>.empty(),
          ),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(() => response),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      addTearDown(listener.close);
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);

      final pending = Completer<Object?>();
      response = pending.future;
      container.invalidate(aiCoachCreditAccessProvider);
      final refresh = container.read(aiCoachCreditAccessProvider.future);
      expect(container.read(aiCoachCreditAccessProvider).value, isTrue);
      pending.completeError(StateError('temporary RPC outage'));
      expect(await refresh, isTrue);
      listener.close();
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);

      response = Future.value(usage('ai_coach', 0));
      container
          .read(aiCoachUsageRefreshProvider.notifier)
          .requestAuthoritativeReload();
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
      final failed = Completer<Object?>();
      response = failed.future;
      container.invalidate(aiCoachCreditAccessProvider);
      final retry = container.read(aiCoachCreditAccessProvider.future);
      failed.completeError(StateError('temporary RPC outage'));
      expect(await retry, isFalse);
    },
  );

  test(
    'sign-out and owner switch cannot inherit an old access snapshot',
    () async {
      final owners = StreamController<String?>();
      final pendingOld = Completer<Object?>();
      var ownerLoads = 0;
      Future<Object?> response = Future.value(usage('ai_coach', 100));
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
          verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(() {
            ownerLoads++;
            return response;
          }),
        ],
      );
      final listener = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      addTearDown(() async {
        listener.close();
        container.dispose();
        await owners.close();
      });
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
      response = pendingOld.future;
      container.invalidate(aiCoachCreditAccessProvider);
      final oldRequest = container.read(aiCoachCreditAccessProvider.future);
      owners.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
      final loadsAfterSignOut = ownerLoads;
      pendingOld.complete(usage('ai_coach', 999));
      await oldRequest;
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
      expect(ownerLoads, loadsAfterSignOut);

      final nextOwner = Completer<Object?>();
      response = nextOwner.future;
      owners.add('owner-b');
      await Future<void>.delayed(Duration.zero);
      final nextRequest = container.read(aiCoachCreditAccessProvider.future);
      nextOwner.completeError(StateError('owner B has no verified result'));
      await expectLater(nextRequest, throwsStateError);
      expect(container.read(aiCoachCreditAccessProvider).hasError, isTrue);
      expect(
        container.read(aiCoachAccessSnapshotStoreProvider).verifiedAccess,
        isNull,
      );
    },
  );

  test(
    'a server reload signal updates a mounted gate after a Boost grant',
    () async {
      Object? serverStatus = usage('free', 0);
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value('qa-owner'),
          ),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(
            () async => serverStatus,
          ),
        ],
      );
      final listener = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
      serverStatus = usage('free', 2500);
      container
          .read(aiCoachUsageRefreshProvider.notifier)
          .requestAuthoritativeReload();
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
      serverStatus = usage('premium', 0);
      container
          .read(aiCoachUsageRefreshProvider.notifier)
          .requestAuthoritativeReload();
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
    },
  );
  test(
    'verified AI access survives listener detach and route re-entry',
    () async {
      var loads = 0;
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value('qa-owner'),
          ),
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('qa-owner'),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(() async {
            loads++;
            return usage('ai_coach', 1000);
          }),
        ],
      );
      addTearDown(container.dispose);

      final first = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
      expect(loads, 1);
      first.close();

      // Auto-disposed providers are released after their last listener leaves.
      // The verified access cache must instead survive a route pop/push for the
      // same authenticated owner.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final second = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      addTearDown(second.close);
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
      expect(loads, 1);
    },
  );

  test('zero -> Boost -> consumed zero is reflected exactly', () {
    expect(aiCoachAccessFromUsageStatus(usage('free', 0)), isFalse);
    expect(aiCoachAccessFromUsageStatus(usage('free', 15)), isTrue);
    expect(aiCoachAccessFromUsageStatus(usage('free', 2500)), isTrue);
    expect(aiCoachAccessFromUsageStatus(usage('free', 0)), isFalse);
  });

  test('AI subscription and trial require a positive total remaining', () {
    expect(aiCoachAccessFromUsageStatus(usage('ai_coach', 10000)), isTrue);
    expect(aiCoachAccessFromUsageStatus(usage('ai_coach', 0)), isFalse);
    expect(aiCoachAccessFromUsageStatus(usage('trial', 1000)), isTrue);
    expect(aiCoachAccessFromUsageStatus(usage('trial', 0)), isFalse);
  });

  test(
    'ordinary Premium unlocks only when authoritative Boost total is positive',
    () {
      expect(aiCoachAccessFromUsageStatus(usage('premium', 2500)), isTrue);
      expect(aiCoachAccessFromUsageStatus(usage('premium', 0)), isFalse);
      expect(aiCoachAccessFromUsageStatus(usage('free', 0)), isFalse);
    },
  );

  test('total remaining is authoritative regardless of its source label', () {
    expect(aiCoachAccessFromUsageStatus(usage('future_plan', 1)), isTrue);
    expect(
      aiCoachAccessFromUsageStatus(<String, Object?>{
        'credits': <String, Object?>{'total_remaining': 1},
      }),
      isTrue,
    );
  });

  test('null, non-positive, and malformed credit snapshots fail closed', () {
    for (final value in <Object?>[
      null,
      const <String, Object?>{},
      usage('ai_coach', null),
      usage('ai_coach', '1000'),
      usage('ai_coach', 0),
      usage('ai_coach', -1),
      usage('ai_coach', double.nan),
      usage('ai_coach', double.infinity),
      <Object?, Object?>{1: 'not-a-string-key'},
      <Object?, Object?>{
        'plan': 'ai_coach',
        'credits': <Object?, Object?>{1: 1000},
      },
    ]) {
      expect(aiCoachAccessFromUsageStatus(value), isFalse, reason: '$value');
    }
  });

  test('credit access provider exposes an RPC failure as AsyncError', () async {
    final rpcError = StateError('usage status unavailable');
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerProvider.overrideWith(
          (_) => Stream<String?>.value('test-owner'),
        ),
        verifiedEntitlementOwnerSeedProvider.overrideWithValue('test-owner'),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(
          () => Future<Object?>.error(rpcError),
        ),
      ],
    );
    final listener = container.listen(
      aiCoachCreditAccessProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(() {
      listener.close();
      container.dispose();
    });

    await expectLater(
      container.read(aiCoachCreditAccessProvider.future),
      throwsA(same(rpcError)),
    );
    expect(
      container.read(aiCoachCreditAccessProvider),
      isA<AsyncError<bool>>(),
    );
  });

  test('AI subscription identity requires a verified live store boundary', () {
    final now = DateTime.utc(2026, 8, 30, 12);

    SubscriptionState state({
      CommercePlan plan = CommercePlan.premiumAiCoach,
      SubscriptionLifecycle lifecycle = SubscriptionLifecycle.active,
      DateTime? currentPeriodEndsAt,
      DateTime? trialEndsAt,
      DateTime? gracePeriodEndsAt,
      EntitlementAuthority authority = EntitlementAuthority.verifiedServer,
    }) => SubscriptionState(
      plan: plan,
      entitlements: const {},
      authority: authority,
      lifecycle: lifecycle,
      currentPeriodEndsAt: currentPeriodEndsAt,
      trialEndsAt: trialEndsAt,
      gracePeriodEndsAt: gracePeriodEndsAt,
      isPurchasable: false,
      canRestorePurchases: false,
    );

    expect(
      hasVerifiedAiSubscription(
        state(currentPeriodEndsAt: now.add(const Duration(seconds: 1))),
        now: now,
      ),
      isTrue,
    );
    expect(
      hasVerifiedAiSubscription(
        state(
          lifecycle: SubscriptionLifecycle.trial,
          trialEndsAt: now.add(const Duration(days: 7)),
        ),
        now: now,
      ),
      isTrue,
    );
    expect(
      hasVerifiedAiSubscription(
        state(
          lifecycle: SubscriptionLifecycle.gracePeriod,
          gracePeriodEndsAt: now.add(const Duration(hours: 1)),
        ),
        now: now,
      ),
      isTrue,
    );
    expect(
      hasVerifiedAiSubscription(state(currentPeriodEndsAt: now), now: now),
      isFalse,
      reason: 'the exact boundary instant is expired',
    );
    expect(
      hasVerifiedAiSubscription(state(), now: now),
      isFalse,
      reason: 'a missing boundary must fail closed',
    );
    expect(
      hasVerifiedAiSubscription(
        state(
          plan: CommercePlan.premium,
          currentPeriodEndsAt: now.add(const Duration(days: 30)),
        ),
        now: now,
      ),
      isFalse,
    );
    expect(
      hasVerifiedAiSubscription(
        state(
          plan: CommercePlan.free,
          authority: EntitlementAuthority.localDefault,
          currentPeriodEndsAt: now.add(const Duration(days: 30)),
        ),
        now: now,
      ),
      isFalse,
    );
  });
}
