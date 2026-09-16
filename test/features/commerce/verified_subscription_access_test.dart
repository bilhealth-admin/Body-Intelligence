import 'dart:async';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

SubscriptionState _paid(
  DateTime end, {
  SubscriptionLifecycle lifecycle = SubscriptionLifecycle.active,
}) => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  lifecycle: lifecycle,
  currentPeriodEndsAt: end,
  trialEndsAt: lifecycle == SubscriptionLifecycle.trial ? end : null,
  isPurchasable: false,
  canRestorePurchases: true,
);

void main() {
  testWidgets('same owner auth startup does not reload a verified paid grant', (
    tester,
  ) async {
    final owners = StreamController<String?>();
    addTearDown(owners.close);
    final now = DateTime.utc(2026, 9, 16);
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        verifiedEntitlementLoaderProvider.overrideWithValue(() async {
          loads++;
          return _paid(now.add(const Duration(hours: 1)));
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _AccessProbe(),
      ),
    );
    await tester.pump();
    expect(find.text('premium'), findsOneWidget);
    expect(loads, 1);
    owners.add('owner-a');
    await tester.pump();
    expect(find.text('premium'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
    expect(loads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    // This test owns an UncontrolledProviderScope: dispose its timers before
    // Flutter checks the fake-clock invariants, not in the later teardown.
    container.dispose();
    await tester.pump();
  });

  for (final lifecycle in [
    SubscriptionLifecycle.active,
    SubscriptionLifecycle.trial,
    SubscriptionLifecycle.cancelled,
  ]) {
    testWidgets(
      '$lifecycle locks at its exact deadline without a server response',
      (tester) async {
        var now = DateTime.utc(2026, 9, 16);
        final end = now.add(const Duration(seconds: 1));
        final container = ProviderContainer(
          overrides: [
            verifiedEntitlementClockProvider.overrideWithValue(() => now),
            verifiedSubscriptionStateProvider.overrideWith(
              (_) async => _paid(end, lifecycle: lifecycle),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _AccessProbe(),
          ),
        );
        await tester.pump();
        expect(find.text('premium'), findsOneWidget);
        now = end;
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.text('free'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'real owner stream reload drops the old grant and sign-out wins over seed',
    (tester) async {
      final owners = StreamController<String?>();
      addTearDown(owners.close);
      final now = DateTime.utc(2026, 9, 16);
      final nextOwner = Completer<SubscriptionState>();
      var loads = 0;
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
          verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
          verifiedEntitlementLoaderProvider.overrideWithValue(() {
            loads++;
            return loads == 1
                ? Future.value(_paid(now.add(const Duration(hours: 1))))
                : nextOwner.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _AccessProbe(),
        ),
      );
      await tester.pump();
      expect(find.text('premium'), findsOneWidget);
      owners.add('owner-b');
      await tester.pump();
      await tester.pump();
      expect(loads, 2);
      expect(find.text('premium'), findsNothing);
      expect(find.text('loading'), findsOneWidget);
      nextOwner.complete(FreePlan.createState());
      await container.read(verifiedSubscriptionStateProvider.future);
      await tester.pump();
      await tester.pump();
      expect(find.text('free'), findsOneWidget);
      owners.add(null);
      await tester.pump();
      await tester.pump();
      expect(container.read(verifiedEntitlementOwnerIdProvider), isNull);
      expect(find.text('premium'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'same-owner refresh retains valid access, then a terminal response locks immediately',
    (tester) async {
      final now = DateTime.utc(2026, 9, 16);
      var response = Future.value(_paid(now.add(const Duration(hours: 1))));
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedSubscriptionStateProvider.overrideWith((_) => response),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _AccessProbe(),
        ),
      );
      await tester.pump();
      final pending = Completer<SubscriptionState>();
      response = pending.future;
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pump();
      expect(find.text('premium'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
      pending.complete(FreePlan.createState());
      await container.read(verifiedSubscriptionStateProvider.future);
      await tester.pump();
      await tester.pump();
      expect(find.text('free'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'account dependency reload never retains the previous owner paid access',
    (tester) async {
      final owner = StateProvider<String?>((_) => 'owner-a');
      final now = DateTime.utc(2026, 9, 16);
      final second = Completer<SubscriptionState>();
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedSubscriptionStateProvider.overrideWith((ref) {
            return ref.watch(owner) == 'owner-a'
                ? Future.value(_paid(now.add(const Duration(hours: 1))))
                : second.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _AccessProbe(),
        ),
      );
      await tester.pump();
      expect(find.text('premium'), findsOneWidget);
      container.read(owner.notifier).state = null;
      await tester.pump();
      expect(find.text('premium'), findsNothing);
      expect(find.text('loading'), findsOneWidget);
      second.complete(FreePlan.createState());
      await container.read(verifiedSubscriptionStateProvider.future);
      await tester.pump();
      await tester.pump();
      expect(find.text('free'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _AccessProbe extends ConsumerWidget {
  const _AccessProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(verifiedSubscriptionAccessProvider);
    return MaterialApp(home: Text(access.value?.plan.name ?? 'loading'));
  }
}
