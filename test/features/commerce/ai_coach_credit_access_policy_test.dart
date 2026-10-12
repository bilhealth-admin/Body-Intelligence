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
      await expectLater(retry, throwsStateError);
      expect(container.read(aiCoachCreditAccessProvider).hasError, isTrue);
      expect(
        container.read(aiCoachAccessSnapshotStoreProvider).verifiedAccess,
        isFalse,
      );
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

  test(
    'malformed quota is unavailable while valid zero alone means insufficient',
    () async {
      for (final value in [
        null,
        {},
        usage('ai_coach', null),
        usage('ai_coach', '2500'),
        usage('ai_coach', -1),
        usage('ai_coach', double.nan),
        usage('ai_coach', double.infinity),
      ]) {
        expect(verifiedAiCoachAccessFromUsageStatus(value), isNull);
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-a'),
            aiCoachUsageStatusLoaderProvider.overrideWithValue(
              () async => value,
            ),
          ],
        );
        final listener = container.listen(
          aiCoachCreditAccessProvider,
          (_, _) {},
        );
        try {
          await expectLater(
            container.read(aiCoachCreditAccessProvider.future),
            throwsA(isA<StateError>()),
          );
          expect(container.read(aiCoachCreditAccessProvider).hasError, isTrue);
          expect(
            container.read(aiCoachAccessSnapshotStoreProvider).verifiedAccess,
            isNull,
            reason: 'unavailable response is never cached as zero',
          );
        } finally {
          listener.close();
          container.dispose();
        }
      }
      expect(verifiedAiCoachAccessFromUsageStatus(usage('free', 0)), isFalse);
      expect(verifiedAiCoachAccessFromUsageStatus(usage('free', 1)), isTrue);
    },
  );

  test(
    'malformed reload preserves same-owner authority but cannot seed a new account',
    () async {
      Object? value = usage('free', 100);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-a'),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(() async => value),
        ],
      );
      final listener = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
      value = {'credits': {}};
      container.invalidate(aiCoachCreditAccessProvider);
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
      container.updateOverrides([
        verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-b'),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(() async => value),
      ]);
      await expectLater(
        container.read(aiCoachCreditAccessProvider.future),
        throwsA(isA<StateError>()),
      );
      container.updateOverrides([
        verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-a'),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(() async => value),
      ]);
      await expectLater(
        container.read(aiCoachCreditAccessProvider.future),
        throwsA(isA<StateError>()),
      );
      value = usage('free', 0);
      container.invalidate(aiCoachCreditAccessProvider);
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
    },
  );

  test(
    'verified zero followed by malformed quota stays unavailable across A B A',
    () async {
      Object? value = usage('free', 0);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-a'),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(() async => value),
        ],
      );
      final listener = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
      value = usage('free', '2500');
      container.invalidate(aiCoachCreditAccessProvider);
      await expectLater(
        container.read(aiCoachCreditAccessProvider.future),
        throwsStateError,
      );
      expect(container.read(aiCoachCreditAccessProvider).hasError, isTrue);
      for (final owner in ['owner-b', 'owner-a']) {
        container.updateOverrides([
          verifiedEntitlementOwnerIdProvider.overrideWithValue(owner),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(() async => value),
        ]);
        await expectLater(
          container.read(aiCoachCreditAccessProvider.future),
          throwsStateError,
        );
        expect(
          container.read(aiCoachAccessSnapshotStoreProvider).verifiedAccess,
          isNull,
        );
      }
      value = usage('free', 100);
      container.invalidate(aiCoachCreditAccessProvider);
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
    },
  );

  for (final race in [(100, 0), (0, 100)]) {
    test(
      'late quota ${race.$1} cannot replace newer ${race.$2} before failed refresh',
      () async {
        final stale = Completer<Object?>();
        Future<Object?> response = stale.future;
        var loads = 0;
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-a'),
            aiCoachUsageStatusLoaderProvider.overrideWithValue(() {
              loads++;
              return response;
            }),
          ],
        );
        final listener = container.listen(
          aiCoachCreditAccessProvider,
          (_, _) {},
        );
        addTearDown(() {
          listener.close();
          container.dispose();
        });
        // Riverpod may redirect a superseded public future to the new generation.
        // Observe either completion safely; the snapshot/current reader is the
        // contract, not the detached request's completion behavior.
        final oldRequest = container
            .read(aiCoachCreditAccessProvider.future)
            .then<bool?>(
              (value) => value,
              onError: (Object _, StackTrace _) => null,
            );
        await Future<void>.delayed(Duration.zero);
        expect(loads, 1);
        response = Future.value(usage('free', race.$2));
        container.invalidate(aiCoachCreditAccessProvider);
        expect(
          await container.read(aiCoachCreditAccessProvider.future),
          race.$2 > 0,
        );
        expect(loads, 2);
        stale.complete(usage('free', race.$1));
        await oldRequest;
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(aiCoachAccessSnapshotStoreProvider).verifiedAccess,
          race.$2 > 0,
        );
        final outage = Completer<Object?>();
        response = outage.future;
        container.invalidate(aiCoachCreditAccessProvider);
        final currentRequest = container.read(
          aiCoachCreditAccessProvider.future,
        );
        final assertion = race.$2 == 0
            ? expectLater(currentRequest, throwsStateError)
            : expectLater(currentRequest, completion(isTrue));
        outage.completeError(StateError('third load unavailable'));
        await assertion;
        expect(loads, 3);
        expect(
          container.read(aiCoachAccessSnapshotStoreProvider).verifiedAccess,
          race.$2 > 0,
        );
        if (race.$2 == 0) {
          expect(container.read(aiCoachCreditAccessProvider).hasError, isTrue);
        }
      },
    );
  }

  test('late quota from disposed owner A cannot seed A after A B A', () async {
    final stale = Completer<Object?>();
    Future<Object?> response = stale.future;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-a'),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(() => response),
      ],
    );
    final listener = container.listen(aiCoachCreditAccessProvider, (_, _) {});
    addTearDown(() {
      listener.close();
      container.dispose();
    });
    final oldRequest = container
        .read(aiCoachCreditAccessProvider.future)
        .then<bool?>(
          (value) => value,
          onError: (Object _, StackTrace _) => null,
        );
    final oldSnapshot = container.read(aiCoachAccessSnapshotStoreProvider);
    await Future<void>.delayed(Duration.zero);
    response = Future.value(usage('free', 100));
    container.updateOverrides([
      verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-b'),
      aiCoachUsageStatusLoaderProvider.overrideWithValue(() => response),
    ]);
    expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
    response = Future.value(usage('free', 0));
    container.updateOverrides([
      verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-a'),
      aiCoachUsageStatusLoaderProvider.overrideWithValue(() => response),
    ]);
    expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
    stale.complete(usage('free', 2500));
    await oldRequest;
    await Future<void>.delayed(Duration.zero);
    expect(
      oldSnapshot.verifiedAccess,
      isNull,
      reason: 'disposed request never writes its old owner store',
    );
    expect(
      container.read(aiCoachAccessSnapshotStoreProvider).verifiedAccess,
      isFalse,
    );
    final outage = Completer<Object?>();
    response = outage.future;
    container.invalidate(aiCoachCreditAccessProvider);
    final assertion = expectLater(
      container.read(aiCoachCreditAccessProvider.future),
      throwsStateError,
    );
    outage.completeError(StateError('owner A reload unavailable'));
    await assertion;
    expect(container.read(aiCoachCreditAccessProvider).hasError, isTrue);
    expect(
      container.read(aiCoachAccessSnapshotStoreProvider).verifiedAccess,
      isFalse,
    );
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
