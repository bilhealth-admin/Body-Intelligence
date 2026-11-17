import 'dart:async';

import '../../visual_closure/visual_evidence_font.dart';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerA = 'steady-overview-owner-a';
const _ownerB = 'steady-overview-owner-b';
const _label = Key('coach-workspace-plan-label');
const _authorized = Key('steady-overview-authorized-child');

class _Read {
  _Read(this.generation, this.visit, this.rawOwner);

  final int generation;
  final int visit;
  final String? rawOwner;
  final result = Completer<SubscriptionState>();
}

class _RebindFixture {
  _RebindFixture() {
    container = ProviderContainer(
      overrides: [
        verifiedEntitlementOwnerSeedProvider.overrideWithValue(_ownerA),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWithValue(() {
          final read = _Read(
            container.read(verifiedSubscriptionReadWitnessProvider).generation,
            container.read(verifiedEntitlementOwnerVisitProvider),
            owner,
          );
          reads.add(read);
          if (reads.length == 1) read.result.complete(paid());
          return read.result.future;
        }),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(
          () async => {
            'credits': {'total_remaining': 0},
          },
        ),
        storefrontTargetPlanProvider.overrideWith(
          (_) async => CommercePlan.premium,
        ),
      ],
    );
    authority = container.listen(verifiedSubscriptionStateProvider, (_, _) {});
  }

  final now = DateTime.utc(2026, 10, 29, 12);
  final owners = StreamController<String?>.broadcast(sync: true);
  final visible = ValueNotifier(true);
  final reads = <_Read>[];
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<SubscriptionState>> authority;
  String? owner = _ownerA;
  bool _authorityClosed = false;

  SubscriptionState paid({CommercePlan plan = CommercePlan.premiumAiCoach}) =>
      SubscriptionState(
        plan: plan,
        entitlements: const {
          CommerceEntitlement.advancedIntelligence,
          CommerceEntitlement.mealPlanning,
          CommerceEntitlement.premiumPrograms,
        },
        authority: EntitlementAuthority.verifiedServer,
        currentPeriodEndsAt: now.add(const Duration(hours: 1)),
        isPurchasable: false,
        canRestorePurchases: true,
      );

  Widget _overview(bool show) => !show
      ? const SizedBox()
      : Stack(
          children: [
            CoachReferenceWorkspace(
              snapshot: null,
              now: now,
              onChat: () {},
              onRoute: (_) {},
              onQuickAdd: () {},
              onPhoto: () {},
              onVoice: () {},
            ),
            const Offstage(
              child: PremiumRouteGlassGate(
                feature: PremiumGateFeature.personalPlan,
                child: SizedBox(key: _authorized),
              ),
            ),
          ],
        );

  Widget _root() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: visualEvidenceTheme(BilFlagshipTheme.light()),
      home: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, show, _) => _overview(show),
      ),
    ),
  );

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_root());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> show(
    WidgetTester tester,
    bool value, {
    bool settle = true,
  }) async {
    visible.value = value;
    // The steady variants never replace the root scope or MaterialApp after
    // start. Their ValueListenableBuilder changes only the Overview child.
    await tester.pump();
    await tester.pump();
    if (settle) await tester.pumpAndSettle();
  }

  void emitOwner(String? next) {
    owner = next;
    owners.add(next);
  }

  void releaseAuthorityObserver() {
    if (_authorityClosed) return;
    authority.close();
    _authorityClosed = true;
  }

  Future<void> close(WidgetTester tester) async {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      releaseAuthorityObserver();
      container.dispose();
      for (final read in reads) {
        if (!read.result.isCompleted) read.result.complete(paid());
      }
      visible.dispose();
      await owners.close();
    }
    await tester.pump();
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);

  for (final variant in [
    (
      name: 'steady host with actual owner scalar',
      unobserved: false,
      expectedReads: 4,
    ),
    (
      name: 'steady host with unobserved actual owner scalar',
      unobserved: true,
      expectedReads: 5,
    ),
  ]) {
    testWidgets(variant.name, (tester) async {
      final fixture = _RebindFixture();
      try {
        await fixture.start(tester);
        expect(fixture.reads, hasLength(1));
        expect(
          tester.widget<Text>(find.byKey(_label)).data,
          'Premium AI Coach',
        );
        await fixture.show(tester, false);
        expect(find.byType(CoachReferenceWorkspace), findsNothing);
        if (variant.unobserved) fixture.releaseAuthorityObserver();

        // The controlled hidden request is part of the original failing
        // scenario. There is no preflush after either owner change or remount.
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        fixture.container
            .read(verifiedSubscriptionStateProvider.future)
            .ignore();
        expect(fixture.reads, hasLength(2));
        fixture.emitOwner(_ownerB);
        fixture.emitOwner(_ownerA);
        await tester.pump();
        if (!variant.unobserved) {
          expect(
            fixture.container.read(verifiedEntitlementOwnerVisitProvider),
            2,
          );
        }
        // The unobserved actual-scalar case does not read the scalar, visit,
        // credit, or presentation provider here. Reading a dirty dependency
        // would preflush the exact lazy-return boundary under investigation.

        await fixture.show(tester, true, settle: false);
        expect(
          tester.takeException(),
          isNull,
          reason:
              'A real hidden owner visit must not schedule an ancestor '
              'scope rebuild while Overview is building.',
        );
        expect(
          fixture.container.read(verifiedEntitlementOwnerVisitProvider),
          2,
        );
        expect(fixture.reads, hasLength(variant.expectedReads));
        expect(
          fixture.reads.map((read) => read.result.future).toSet(),
          hasLength(variant.expectedReads),
        );
        expect(
          fixture.reads.map((read) => read.generation),
          orderedEquals(
            List.generate(variant.expectedReads, (index) => index + 1),
          ),
        );
        expect(fixture.reads.first.rawOwner, _ownerA);
        expect(fixture.reads.last.rawOwner, _ownerA);
        expect(fixture.reads.last.visit, 2);
        expect(fixture.reads.last.result.isCompleted, isFalse);
        final current = fixture.reads.last;
        for (final retired in fixture.reads.sublist(
          1,
          fixture.reads.length - 1,
        )) {
          retired.result.complete(fixture.paid());
          await tester.pump();
          await tester.pump();
          expect(fixture.reads, hasLength(variant.expectedReads));
          expect(find.byKey(_label), findsNothing);
          expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
        }
        current.result.complete(fixture.paid(plan: CommercePlan.premium));
        await tester.pumpAndSettle();
        expect(fixture.reads, hasLength(variant.expectedReads));
        expect(tester.takeException(), isNull);
        expect(tester.widget<Text>(find.byKey(_label)).data, 'Premium');
        expect(find.byKey(_authorized, skipOffstage: false), findsOneWidget);
      } finally {
        await fixture.close(tester);
      }
    });
  }
}
