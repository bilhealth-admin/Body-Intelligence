import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/verified_purchase_handoff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _dependency = StateProvider<int>((_) => 0);
final _deadline = DateTime.utc(2026, 11, 19, 22, 10, 16);

SubscriptionState _paid() => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.premium),
  authority: EntitlementAuthority.verifiedServer,
  provider: SubscriptionProvider.apple,
  lifecycle: SubscriptionLifecycle.active,
  startedAt: DateTime.utc(2026, 11, 19, 21, 34, 16),
  currentPeriodEndsAt: _deadline,
  verifiedAt: DateTime.utc(2026, 11, 19, 21, 33, 30, 232),
  serverRevision: 665,
  storeOriginalTransactionId: 'synthetic-apple-canonical-665',
  isPurchasable: false,
  canRestorePurchases: true,
);

SubscriptionState _revoked({
  SubscriptionLifecycle lifecycle = SubscriptionLifecycle.revoked,
}) => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: FreePlan.entitlements,
  authority: EntitlementAuthority.verifiedServer,
  lifecycle: lifecycle,
  provider: SubscriptionProvider.apple,
  verifiedAt: DateTime.utc(2026, 11, 19, 21, 56),
  serverRevision: 666,
  storeRenewalDefinitivelyInactive: true,
  isPurchasable: false,
  canRestorePurchases: false,
);

void main() {
  for (final event in ['revoked', 'switched', 'outage', '401']) {
    test('offscreen read followed by route reentry after $event', () async {
      final owners = StreamController<String?>();
      final pending = <Completer<SubscriptionState>>[];
      var loaderPaused = false;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('A'),
          verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
          verifiedEntitlementClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 11, 19, 21, 55, 41),
          ),
          verifiedEntitlementLoaderProvider.overrideWith((ref) {
            ref.onCancel(() => loaderPaused = true);
            ref.onResume(() => loaderPaused = false);
            return () {
              final next = Completer<SubscriptionState>();
              pending.add(next);
              return next.future;
            };
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        for (final read in pending) {
          if (!read.isCompleted) read.complete(_revoked());
        }
        await owners.close();
      });
      final listener = container.listen(
        verifiedSubscriptionPresentationProvider,
        (_, _) {},
      );
      owners.add('A');
      await container.pump();
      pending.single.complete(_paid());
      await container.pump();
      expect(listener.read().value?.serverRevision, 665);
      if (event == '401' || event == 'revoked') {
        container
            .read(verifiedPurchaseHandoffProvider.notifier)
            .publish(_paid());
      }
      container.invalidate(verifiedSubscriptionStateProvider);
      await container.pump();
      final inFlight = pending.last;
      expect(inFlight.isCompleted, isFalse);
      listener.close();
      await container.pump();
      expect(
        container.read(verifiedSubscriptionAccessProvider.exists),
        isFalse,
      );
      expect(
        container.read(verifiedSubscriptionPresentationProvider.exists),
        isFalse,
      );
      expect(
        loaderPaused,
        isTrue,
        reason: 'the authority loader has no active consumer',
      );
      if (event == 'switched') {
        owners.add('B');
        owners.add('A');
      }
      if (event == '401') {
        inFlight.completeError(
          const AuthException('invalid session', statusCode: '401'),
        );
      } else if (event == 'outage') {
        inFlight.completeError(StateError('unavailable'));
      } else {
        inFlight.complete(event == 'switched' ? _paid() : _revoked());
      }
      await container.pump();
      container.invalidate(verifiedSubscriptionStateProvider);
      final next = container.listen(
        verifiedSubscriptionPresentationProvider,
        (_, _) {},
      );
      addTearDown(next.close);
      // A command can synchronously read the newly mounted route's first state.
      final expected = event == 'outage'
          ? equals(CommercePlan.premium)
          : isNot(CommercePlan.premium);
      expect(
        container.read(verifiedSubscriptionAccessProvider).value?.plan,
        expected,
      );
      expect(next.read().value?.plan, expected);
      await container.pump();
      expect(
        container.read(verifiedSubscriptionAccessProvider).value?.plan,
        expected,
      );
      expect(next.read().value?.plan, expected);
    });
  }

  for (final event in ['revoked', 'free', '401', '403']) {
    for (final reentry in ['pending', 'error']) {
      test(
        'unobserved access cannot revive after $event then $reentry',
        () async {
          final h = _SourceLifecycle();
          try {
            await h.open();
            await h.removeAccess();
            await h.reload();
            if (event == '401' || event == '403') {
              h.pending.last.completeError(
                AuthException('unobserved invalidity', statusCode: event),
              );
            } else {
              h.pending.last.complete(
                _revoked(
                  lifecycle: event == 'free'
                      ? SubscriptionLifecycle.inactive
                      : SubscriptionLifecycle.revoked,
                ),
              );
            }
            await h.settle();
            final denied = h.container.read(verifiedSubscriptionStateProvider);
            expect(
              event == '401' || event == '403'
                  ? denied.hasError
                  : denied.value?.plan == CommercePlan.free,
              isTrue,
            );
            expect(
              h.container.read(verifiedSubscriptionAccessProvider.exists),
              isFalse,
            );
            await h.reload();
            if (reentry == 'error') {
              h.pending.last.completeError(
                StateError('unobserved later outage'),
              );
              await h.settle();
            }
            h.observeAccess();
            await h.settle();
            expect(
              h.container
                      .read(verifiedSubscriptionAccessProvider)
                      .value
                      ?.plan ==
                  CommercePlan.premium,
              isFalse,
              reason: 'a later retry must not resurrect retired665',
            );
          } finally {
            h.close();
          }
        },
      );
    }
  }

  test(
    'reopening after unobserved pending read retains unrevoked period',
    () async {
      final h = _SourceLifecycle();
      try {
        await h.open();
        await h.removeAccess();
        await h.reload();
        h.observeAccess();
        await h.settle();
        final access = h.container.read(verifiedSubscriptionAccessProvider);
        expect(access.isLoading, isFalse);
        expect(access.hasError, isFalse);
        expect(access.value?.serverRevision, 665);
        expect(access.value?.currentPeriodEndsAt, _deadline);
      } finally {
        h.close();
      }
    },
  );

  testWidgets(
    'same-owner dependency reload and outage retain actual paid actions',
    (tester) async {
      final h = _Harness();
      try {
        await h.open(tester);
        h.container.read(_dependency.notifier).state++;
        await h.flush(tester);
        expect(
          h.container.read(verifiedSubscriptionStateProvider).isReloading,
          isTrue,
          reason: 'exercise dependency reload, not manual invalidation',
        );
        h.expectPaid();
        await h.tap(tester);
        expect(h.writes, 1);
        expect(h.mounts, 1);
        expect(h.disposals, 0);
        expect(
          find.byKey(const ValueKey('premium-route-access-checking')),
          findsNothing,
        );
        h.pending.last.completeError(StateError('synthetic transient outage'));
        await h.flush(tester);
        expect(
          h.container.read(verifiedSubscriptionStateProvider).hasError,
          isTrue,
        );
        h.expectPaid();
        await h.tap(tester);
        expect(h.writes, 2);
        expect(h.mounts, 1);
        expect(h.disposals, 0);

        h.container.read(_dependency.notifier).state++;
        await h.flush(tester);
        h.pending.last.complete(_revoked());
        await h.flush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(
          find.byKey(const ValueKey('canonical-protected-action')),
          findsNothing,
        );
        expect(h.disposals, 1);
        h.container.read(_dependency.notifier).state++;
        await h.flush(tester);
        h.pending.last.completeError(
          StateError('outage after real revocation'),
        );
        await h.flush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).hasError,
          isTrue,
        );
        expect(
          find.byKey(const ValueKey('canonical-protected-action')),
          findsNothing,
        );
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'unverified Free cannot replace the same owner canonical period',
    (tester) async {
      final h = _Harness();
      try {
        await h.open(tester);
        h.container.read(_dependency.notifier).state++;
        await h.flush(tester);
        h.pending.last.complete(FreePlan.createState());
        await h.flush(tester);
        h.expectPaid();
        await h.tap(tester);
        expect(h.writes, 1);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'same-owner pending canonical proof cuts off at exact real deadline',
    (tester) async {
      final h = _Harness();
      try {
        await h.open(tester);
        h.container.read(_dependency.notifier).state++;
        await h.flush(tester);
        h.expectPaid();
        final elapsed = _deadline.difference(h.now);
        h.now = _deadline;
        await tester.pump(elapsed);
        await h.flush(tester);
        expect(
          h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
          CommercePlan.free,
        );
        expect(
          find.byKey(const ValueKey('canonical-protected-action')),
          findsNothing,
        );
      } finally {
        await h.close(tester);
      }
    },
  );

  for (final status in ['401', '403']) {
    testWidgets(
      'invalid session $status immediately retires canonical paid proof',
      (tester) async {
        final h = _Harness();
        try {
          await h.open(tester);
          h.container.read(_dependency.notifier).state++;
          await h.flush(tester);
          h.pending.last.completeError(
            AuthException('synthetic invalid session', statusCode: status),
          );
          await h.flush(tester);
          expect(
            h.container.read(verifiedSubscriptionAccessProvider).hasError,
            isTrue,
          );
          expect(
            find.byKey(const ValueKey('canonical-protected-action')),
            findsNothing,
          );
          h.container.read(_dependency.notifier).state++;
          await h.flush(tester);
          h.pending.last.completeError(
            StateError('outage after invalid session'),
          );
          await h.flush(tester);
          expect(
            h.container.read(verifiedSubscriptionAccessProvider).hasError,
            isTrue,
          );
          expect(
            find.byKey(const ValueKey('canonical-protected-action')),
            findsNothing,
          );
        } finally {
          await h.close(tester);
        }
      },
    );
  }

  testWidgets('owner A to B to A never borrows retired canonical paid proof', (
    tester,
  ) async {
    final h = _Harness();
    try {
      await h.open(tester);
      h.owners.add('synthetic-owner-B');
      await h.flush(tester);
      expect(
        h.container.read(verifiedSubscriptionAccessProvider).isLoading,
        isTrue,
      );
      h.owners.add('synthetic-owner-A');
      await h.flush(tester);
      expect(
        h.container.read(verifiedSubscriptionAccessProvider).isLoading,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('canonical-protected-action')),
        findsNothing,
      );
      h.pending.last.complete(_revoked());
      await h.flush(tester);
      expect(
        h.container.read(verifiedSubscriptionAccessProvider).value?.plan,
        CommercePlan.free,
      );
    } finally {
      await h.close(tester);
    }
  });
}

// Own subscriptions explicitly: no widget or presentation-dependent listener
// remains when removeAccess proves the actual autoDispose transition.
class _SourceLifecycle {
  final pending = <Completer<SubscriptionState>>[];
  late ProviderContainer container;
  ProviderSubscription<AsyncValue<SubscriptionState>>? access;
  late ProviderSubscription<AsyncValue<SubscriptionState>> raw;

  Future<void> open() async {
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerIdProvider.overrideWithValue(
          'synthetic-owner-A',
        ),
        verifiedEntitlementClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 11, 19, 21, 55, 41),
        ),
        verifiedEntitlementLoaderProvider.overrideWith((ref) {
          ref.watch(_dependency);
          return () {
            final read = Completer<SubscriptionState>();
            pending.add(read);
            return read.future;
          };
        }),
      ],
    );
    raw = container.listen(
      verifiedSubscriptionStateProvider,
      (_, _) {},
      fireImmediately: true,
    );
    observeAccess();
    await settle();
    pending.single.complete(_paid());
    await settle();
    expect(
      container.read(verifiedSubscriptionAccessProvider).value?.plan,
      CommercePlan.premium,
    );
  }

  void observeAccess() {
    access = container.listen(
      verifiedSubscriptionAccessProvider,
      (_, _) {},
      fireImmediately: true,
    );
  }

  Future<void> removeAccess() async {
    access!.close();
    access = null;
    await container.pump();
    await settle();
    expect(
      container.read(verifiedSubscriptionAccessProvider.exists),
      isFalse,
      reason: 'the sole access subscription must actually auto-dispose',
    );
  }

  Future<void> reload() async {
    container.read(_dependency.notifier).state++;
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void close() {
    access?.close();
    raw.close();
    container.dispose();
    for (final read in pending) {
      if (!read.isCompleted) read.complete(_revoked());
    }
  }
}

class _Harness {
  DateTime now = DateTime.utc(2026, 11, 19, 21, 55, 41);
  final owners = StreamController<String?>();
  final pending = <Completer<SubscriptionState>>[];
  late ProviderContainer container;
  int mounts = 0, disposals = 0, writes = 0;

  Future<void> open(
    WidgetTester tester, {
    bool checkPresentation = true,
  }) async {
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerSeedProvider.overrideWithValue(
          'synthetic-owner-A',
        ),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWith((ref) {
          ref.watch(_dependency);
          return () {
            final read = Completer<SubscriptionState>();
            pending.add(read);
            return read.future;
          };
        }),
        storefrontTargetPlanProvider.overrideWith(
          (_) async => CommercePlan.premium,
        ),
      ],
    );
    await mount(tester);
    pending.single.complete(_paid());
    await flush(tester);
    expectPaid(checkPresentation: checkPresentation);
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PremiumRouteGlassGate(
            feature: PremiumGateFeature.personalPlan,
            child: _Protected(this),
          ),
        ),
      ),
    );
    await flush(tester);
  }

  void expectPaid({bool checkPresentation = true}) {
    final access = container.read(verifiedSubscriptionAccessProvider);
    expect(access.isLoading, isFalse);
    expect(access.hasError, isFalse);
    expect(access.value?.serverRevision, 665);
    expect(access.value?.plan, CommercePlan.premium);
    expect(access.value?.currentPeriodEndsAt, _deadline);
    if (checkPresentation) {
      final display = container.read(verifiedSubscriptionPresentationProvider);
      expect(display.isLoading, isFalse);
      expect(display.value?.plan, CommercePlan.premium);
    }
  }

  Future<void> tap(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('canonical-protected-action')));
    await tester.pump();
  }

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    for (final read in pending) {
      if (!read.isCompleted) read.complete(_revoked());
    }
    unawaited(owners.close());
    await tester.pump();
  }
}

class _Protected extends ConsumerStatefulWidget {
  const _Protected(this.h);
  final _Harness h;
  @override
  ConsumerState<_Protected> createState() => _ProtectedState();
}

class _ProtectedState extends ConsumerState<_Protected> {
  @override
  void initState() {
    super.initState();
    widget.h.mounts++;
  }

  @override
  void dispose() {
    widget.h.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const ValueKey('canonical-protected-action'),
        onPressed: () {
          final access = ref.read(verifiedSubscriptionAccessProvider);
          if (!access.isLoading &&
              !access.hasError &&
              access.value?.plan == CommercePlan.premium &&
              access.value?.authority == EntitlementAuthority.verifiedServer) {
            widget.h.writes++;
          }
        },
        child: const Text('Protected action'),
      ),
    ),
  );
}
