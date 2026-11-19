import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/google_renewal_observation.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/google_renewal_recheck_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = 'synthetic-google-owner';
final _end = DateTime.utc(2026, 11, 18, 10);
GoogleRenewalObservation _hint({DateTime? end}) => GoogleRenewalObservation(
  ownerId: _owner,
  periodEnd: end ?? _end,
  verifiedAt: _end.subtract(const Duration(minutes: 5)),
  lineage: 'synthetic-lineage',
  revision: 7,
);
Map<String, dynamic> _row() => {
  'owner_id': _owner,
  'provider': 'google',
  'lifecycle': 'active',
  'auto_renews': true,
  'expires_at': _end.toIso8601String(),
  'verified_at': _end.subtract(const Duration(minutes: 5)).toIso8601String(),
  'original_transaction_id': 'synthetic-lineage',
  'revision': 7,
};

void main() {
  test(
    'Google observation preserves identity but serializes no payment proof',
    () {
      final hint = GoogleRenewalObservation.fromCanonicalRow(
        _row(),
        ownerId: _owner,
      )!;
      expect(hint.ownerId, _owner);
      expect(hint.lineage, 'synthetic-lineage');
      expect(hint.revision, 7);
      expect(hint.periodEnd, _end);
      expect(hint.pendingAt(_end), isTrue);
      expect(
        () => jsonEncode(hint),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    },
  );
  for (final negative in [
    'apple',
    'nonrenewing',
    'terminal',
    'wrong-owner',
    'malformed',
  ]) {
    test('$negative cannot create a Google renewal observation', () {
      final row = _row();
      switch (negative) {
        case 'apple':
          row['provider'] = 'apple';
        case 'nonrenewing':
          row['auto_renews'] = false;
        case 'terminal':
          row['lifecycle'] = 'expired';
        case 'wrong-owner':
          row['owner_id'] = 'other';
        case 'malformed':
          row['expires_at'] = 'unknown';
      }
      expect(
        GoogleRenewalObservation.fromCanonicalRow(row, ownerId: _owner),
        isNull,
      );
    });
  }

  testWidgets(
    'one owner-period burst is bounded, single-flight and re-arms only a new period',
    (tester) async {
      var now = _end, busy = false, active = true, reads = 0;
      final burst = GoogleRenewalReadBurst(
        ownerId: _owner,
        now: () => now,
        current: () => active,
        relevant: (_) => true,
        loading: () => busy,
        refresh: () => reads++,
      );
      try {
        final hint = _hint();
        burst.begin(hint);
        await tester.pump(Duration.zero);
        expect(reads, 1);
        busy = true;
        now = now.add(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        expect(
          reads,
          1,
          reason: 'No second load while the canonical read is pending.',
        );
        busy = false;
        for (final seconds in [3, 5, 10, 5]) {
          now = now.add(Duration(seconds: seconds));
          await tester.pump(Duration(seconds: seconds));
        }
        expect(reads, 4);
        expect(burst.timedOut(hint), isTrue);
        burst.begin(hint);
        await tester.pump(const Duration(seconds: 2));
        expect(reads, 4);
        final next = _hint(end: now);
        burst.begin(next);
        await tester.pump(Duration.zero);
        expect(reads, 5);
        active = false;
        await tester.pump(const Duration(seconds: 25));
        expect(
          reads,
          5,
          reason: 'Retirement cancels effects of every queued attempt.',
        );
      } finally {
        burst.dispose();
      }
    },
  );

  testWidgets(
    'Google paid nutrition route still requires its verified capability',
    (tester) async {
      var builds = 0;
      final state = SubscriptionState(
        plan: CommercePlan.premium,
        entitlements: const {},
        authority: EntitlementAuthority.verifiedServer,
        provider: SubscriptionProvider.google,
        currentPeriodEndsAt: _end.add(const Duration(minutes: 1)),
        verifiedAt: _end,
        isPurchasable: false,
        canRestorePurchases: true,
      );
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue(_owner),
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value(_owner),
          ),
          verifiedEntitlementClockProvider.overrideWithValue(() => _end),
          verifiedEntitlementLoaderProvider.overrideWithValue(
            () async => state,
          ),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premium,
          ),
        ],
      );
      try {
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
                feature: PremiumGateFeature.nutritionPrograms,
                child: Builder(
                  builder: (_) {
                    builds++;
                    return const Text('Private nutrition');
                  },
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump();
        }
        expect(
          builds,
          0,
          reason: 'Paid tier alone cannot bypass the feature capability.',
        );
        expect(find.text('Plans'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'initial expired Google observation never mounts protected content or offers Plans',
    (tester) async {
      var builds = 0;
      final free = SubscriptionState(
        plan: CommercePlan.free,
        entitlements: FreePlan.entitlements,
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: false,
        canRestorePurchases: false,
        googleRenewalObservation: _hint(),
      );
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue(_owner),
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value(_owner),
          ),
          verifiedEntitlementClockProvider.overrideWithValue(() => _end),
          verifiedEntitlementLoaderProvider.overrideWithValue(() async => free),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premium,
          ),
        ],
      );
      try {
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
                feature: PremiumGateFeature.workoutLibrary,
                child: Builder(
                  builder: (_) {
                    builds++;
                    return const Text('Private content');
                  },
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        expect(builds, 0);
        expect(find.text('Plans'), findsNothing);
        await tester.pump(const Duration(seconds: 25));
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        expect(builds, 0);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Plans'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'delivered A to B to A retires retained child and old pending read',
    (tester) async {
      var now = _end.subtract(const Duration(seconds: 5)), loads = 0;
      final owners = StreamController<String?>.broadcast(sync: true);
      final held = <Completer<SubscriptionState>>[];
      final paid = SubscriptionState(
        plan: CommercePlan.premium,
        entitlements: const {},
        authority: EntitlementAuthority.verifiedServer,
        provider: SubscriptionProvider.google,
        startedAt: now.subtract(const Duration(minutes: 1)),
        currentPeriodEndsAt: _end,
        googleRenewalObservation: _hint(),
        isPurchasable: false,
        canRestorePurchases: false,
      );
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue(_owner),
          verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
          verifiedEntitlementClockProvider.overrideWithValue(() => now),
          verifiedEntitlementLoaderProvider.overrideWithValue(() {
            if (++loads == 1) return Future.value(paid);
            final result = Completer<SubscriptionState>();
            held.add(result);
            return result.future;
          }),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premium,
          ),
        ],
      );
      try {
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
                child: Text('Previously authorized owner data'),
              ),
            ),
          ),
        );
        owners.add(_owner);
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        expect(find.text('Previously authorized owner data'), findsOneWidget);
        now = _end;
        await tester.pump(const Duration(seconds: 5));
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        expect(held, isNotEmpty);
        final oldRead = held.first;
        owners.add('owner-b');
        owners.add(_owner);
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        oldRead.complete(paid);
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        expect(find.text('Previously authorized owner data'), findsNothing);
        expect(
          container.read(verifiedEntitlementOwnerVisitProvider),
          greaterThanOrEqualTo(2),
        );
      } finally {
        for (final result in held) {
          if (!result.isCompleted) result.complete(FreePlan.createState());
        }
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await owners.close();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'valid Google startup lease keeps the same child when fresh metadata arrives',
    (tester) async {
      var mounts = 0, unmounts = 0;
      SubscriptionState paid(GoogleRenewalObservation? hint) =>
          SubscriptionState(
            plan: CommercePlan.premium,
            entitlements: const {},
            authority: EntitlementAuthority.verifiedServer,
            provider: SubscriptionProvider.google,
            currentPeriodEndsAt: _end,
            googleRenewalObservation: hint,
            isPurchasable: false,
            canRestorePurchases: false,
          );
      var snapshot = paid(null);
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue(_owner),
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value(_owner),
          ),
          verifiedEntitlementClockProvider.overrideWithValue(
            () => _end.subtract(const Duration(seconds: 5)),
          ),
          verifiedEntitlementLoaderProvider.overrideWithValue(
            () async => snapshot,
          ),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premium,
          ),
        ],
      );
      try {
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
                child: _MountProbe(() => mounts++, () => unmounts++),
              ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        expect(mounts, 1);
        snapshot = paid(_hint());
        container.invalidate(verifiedSubscriptionStateProvider);
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
        expect(mounts, 1);
        expect(unmounts, 0);
        expect(find.text('Same mounted Google child'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      }
    },
  );
}

class _MountProbe extends StatefulWidget {
  const _MountProbe(this.onMount, this.onDispose);
  final VoidCallback onMount, onDispose;
  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Same mounted Google child');
}
