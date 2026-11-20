import 'dart:async';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:body_intelligence_log/features/commerce/providers/verified_purchase_handoff.dart';

SubscriptionState verified(CommercePlan plan, DateTime now) =>
    SubscriptionState(
      plan: plan,
      entitlements: plan == CommercePlan.free
          ? FreePlan.entitlements
          : PaidPlanCatalog.composedEntitlementsFor(plan),
      authority: EntitlementAuthority.verifiedServer,
      provider: SubscriptionProvider.apple,
      lifecycle: SubscriptionLifecycle.active,
      verifiedAt: now,
      currentPeriodEndsAt: now.add(const Duration(minutes: 1)),
      isPurchasable: false,
      canRestorePurchases: true,
    );

Future<void> settle() async {
  for (var index = 0; index < 4; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'Free periodic verification has a stable display and raw pending action',
    () async {
      final now = DateTime.utc(2026, 11, 16);
      final first = Completer<SubscriptionState>();
      final second = Completer<SubscriptionState>();
      var calls = 0;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('A'),
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(
            () => (++calls == 1 ? first : second).future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(
        verifiedSubscriptionPresentationProvider,
        (_, _) {},
      );
      addTearDown(listener.close);
      expect(
        container.read(verifiedSubscriptionPresentationProvider).isLoading,
        isTrue,
      );
      expect(
        container.read(verifiedSubscriptionPresentationProvider).hasValue,
        isFalse,
      );
      first.complete(verified(CommercePlan.free, now));
      await settle();
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value?.plan,
        CommercePlan.free,
      );
      container.invalidate(verifiedSubscriptionStateProvider);
      await settle();
      expect(
        container.read(verifiedSubscriptionAccessProvider).isLoading,
        isTrue,
      );
      expect(
        container.read(verifiedSubscriptionPresentationProvider).isLoading,
        isFalse,
      );
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value?.plan,
        CommercePlan.free,
      );
      second.complete(verified(CommercePlan.premium, now));
      await settle();
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value?.plan,
        CommercePlan.premium,
      );
    },
  );

  test(
    'a network failure retains same-owner canonical access within its exact period',
    () async {
      final now = DateTime.utc(2026, 11, 16);
      var fails = false;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('A'),
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(() async {
            if (fails) throw StateError('fixture offline');
            return verified(CommercePlan.premium, now);
          }),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(
        verifiedSubscriptionPresentationProvider,
        (_, _) {},
      );
      addTearDown(listener.close);
      await settle();
      fails = true;
      container.invalidate(verifiedSubscriptionStateProvider);
      await settle();
      expect(
        container.read(verifiedSubscriptionStateProvider).hasError,
        isTrue,
      );
      expect(
        container.read(verifiedSubscriptionAccessProvider).hasError,
        isFalse,
      );
      expect(
        container.read(verifiedSubscriptionAccessProvider).value?.plan,
        CommercePlan.premium,
      );
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value?.plan,
        CommercePlan.premium,
      );
    },
  );

  testWidgets(
    'known expiry applies during a pending refresh at the actual timer deadline',
    (tester) async {
      var now = DateTime.utc(2026, 11, 16);
      var calls = 0;
      final pending = Completer<SubscriptionState>();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('A'),
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(
            () => ++calls == 1
                ? Future.value(verified(CommercePlan.premium, now))
                : pending.future,
          ),
        ],
      );
      final listener = container.listen(
        verifiedSubscriptionPresentationProvider,
        (_, _) {},
      );
      await tester.pump();
      await tester.pump();
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value?.plan,
        CommercePlan.premium,
      );
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pump();
      await tester.pump();
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value?.plan,
        CommercePlan.free,
      );
      pending.complete(verified(CommercePlan.free, now));
      await tester.pump();
      await tester.pump();
      listener.close();
      container.dispose();
      await tester.pump();
    },
  );

  test('owner A to B to A never reuses the earlier paid display', () async {
    final now = DateTime.utc(2026, 11, 16);
    final owners = StreamController<String?>();
    final pending = <Completer<SubscriptionState>>[];
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerSeedProvider.overrideWithValue('A'),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWithValue(() {
          final read = Completer<SubscriptionState>();
          pending.add(read);
          return read.future;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await owners.close();
    });
    final listener = container.listen(
      verifiedSubscriptionPresentationProvider,
      (_, _) {},
    );
    addTearDown(listener.close);
    await settle();
    pending.last.complete(verified(CommercePlan.premium, now));
    await settle();
    expect(
      container.read(verifiedSubscriptionPresentationProvider).value?.plan,
      CommercePlan.premium,
    );
    owners.add('B');
    await settle();
    expect(
      container.read(verifiedSubscriptionPresentationProvider).value,
      isNull,
    );
    final oldB = pending.last;
    owners.add('A');
    await settle();
    expect(
      container.read(verifiedSubscriptionPresentationProvider).value,
      isNull,
    );
    oldB.complete(verified(CommercePlan.premium, now));
    await settle();
    expect(
      container.read(verifiedSubscriptionPresentationProvider).value,
      isNull,
    );
    pending.last.complete(verified(CommercePlan.free, now));
    await settle();
    expect(
      container.read(verifiedSubscriptionPresentationProvider).value?.plan,
      CommercePlan.free,
    );
  });
  test(
    'invalid source session retires paid handoff and cannot resurrect it on later network failure',
    () async {
      final now = DateTime.utc(2026, 11, 16);
      Object? failure;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('A'),
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(() async {
            if (failure != null) throw failure;
            return verified(CommercePlan.premium, now);
          }),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(
        verifiedSubscriptionPresentationProvider,
        (_, _) {},
      );
      addTearDown(listener.close);
      await settle();
      container
          .read(verifiedPurchaseHandoffProvider.notifier)
          .publish(verified(CommercePlan.premium, now));
      failure = const AuthException(
        'fixture invalid session',
        statusCode: '401',
      );
      container.invalidate(verifiedSubscriptionStateProvider);
      await settle();
      expect(
        container.read(verifiedSubscriptionAccessProvider).hasError,
        isTrue,
      );
      expect(
        container.read(verifiedSubscriptionPresentationProvider).hasError,
        isTrue,
      );
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value,
        isNull,
      );
      expect(container.read(verifiedPurchaseHandoffProvider), isNull);
      failure = StateError('fixture offline after invalid session');
      container.invalidate(verifiedSubscriptionStateProvider);
      await settle();
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value,
        isNull,
      );
    },
  );

  test('raw owner stream error denies old paid source and handoff', () async {
    final now = DateTime.utc(2026, 11, 16);
    final owners = StreamController<String?>();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerSeedProvider.overrideWithValue('A'),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWithValue(
          () async => verified(CommercePlan.premium, now),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await owners.close();
    });
    final listener = container.listen(
      verifiedSubscriptionPresentationProvider,
      (_, _) {},
    );
    addTearDown(listener.close);
    owners.add('A');
    await settle();
    expect(
      container.read(verifiedSubscriptionPresentationProvider).value?.plan,
      CommercePlan.premium,
    );
    container
        .read(verifiedPurchaseHandoffProvider.notifier)
        .publish(verified(CommercePlan.premium, now));
    owners.addError(StateError('fixture owner stream failed'));
    await settle();
    expect(container.read(verifiedSubscriptionAccessProvider).hasError, isTrue);
    expect(
      container.read(verifiedSubscriptionPresentationProvider).hasError,
      isTrue,
    );
    expect(
      container.read(verifiedSubscriptionPresentationProvider).value,
      isNull,
    );
    expect(container.read(verifiedPurchaseHandoffProvider), isNull);
  });

  test(
    'A to B to A between consumer reads retires the paid display and pending proof',
    () async {
      final now = DateTime.utc(2026, 11, 16);
      final owners = StreamController<String?>.broadcast(sync: true);
      var calls = 0;
      final pending = Completer<SubscriptionState>();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('A'),
          verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(
            () => ++calls == 1
                ? Future.value(verified(CommercePlan.premium, now))
                : pending.future,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await owners.close();
      });
      final listener = container.listen(
        verifiedSubscriptionPresentationProvider,
        (_, _) {},
      );
      addTearDown(listener.close);
      await settle();
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value?.plan,
        CommercePlan.premium,
      );
      container
          .read(verifiedPurchaseHandoffProvider.notifier)
          .publish(verified(CommercePlan.premium, now));
      owners.add('B');
      owners.add('A');
      await settle();
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value,
        isNull,
      );
      expect(container.read(verifiedPurchaseHandoffProvider), isNull);
      pending.complete(verified(CommercePlan.free, now));
      await settle();
      expect(
        container.read(verifiedSubscriptionPresentationProvider).value?.plan,
        CommercePlan.free,
      );
    },
  );
}
