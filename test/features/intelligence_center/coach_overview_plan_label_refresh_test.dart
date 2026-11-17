import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../visual_closure/visual_evidence_font.dart';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_overview_paid_label_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _label = Key('coach-workspace-plan-label');
const _authorized = Key('overview-test-authorized-plan');
const _ownerA = 'overview-owner-a';
const _ownerB = 'overview-owner-b';

class _OverviewFixture {
  _OverviewFixture({
    bool coalescedOwnerProjection = false,
    bool recordSubscriptionReads = false,
    int initialCreditRemaining = 2500,
  }) {
    subscription = Future.value(paid());
    usage = Future.value(quota(initialCreditRemaining));
    container = ProviderContainer(
      overrides: [
        verifiedEntitlementOwnerSeedProvider.overrideWithValue(_ownerA),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        if (coalescedOwnerProjection)
          verifiedEntitlementOwnerIdProvider.overrideWithValue(_ownerA),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWithValue(() {
          subscriptionLoads++;
          if (recordSubscriptionReads) {
            final read = _OverviewSubscriptionRead(
              rawOwner: owner,
              scalarOwner: container.read(verifiedEntitlementOwnerIdProvider),
              visit: container.read(verifiedEntitlementOwnerVisitProvider),
              generation: container
                  .read(verifiedSubscriptionReadWitnessProvider)
                  .generation,
            );
            subscriptionReads.add(read);
            // The initial verified snapshot is explicit and has its own
            // producer. Every later real loader invocation stays independent.
            if (subscriptionReads.length == 1) read.result.complete(paid());
            return read.result.future;
          }
          return subscription;
        }),
        aiCoachUsageStatusLoaderProvider.overrideWithValue(() {
          usageLoads++;
          return usage;
        }),
        storefrontTargetPlanProvider.overrideWith(
          (_) async => CommercePlan.premium,
        ),
      ],
    );
  }

  DateTime now = DateTime.utc(2026, 10, 29, 12);
  final owners = StreamController<String?>.broadcast(sync: true);
  late Future<SubscriptionState> subscription;
  final subscriptionReads = <_OverviewSubscriptionRead>[];
  late Future<Object?> usage;
  late ProviderContainer container;
  final boundaryKey = GlobalKey();
  String? owner = _ownerA;
  int subscriptionLoads = 0;
  int usageLoads = 0;

  SubscriptionState paid({
    DateTime? end,
    CommercePlan plan = CommercePlan.premiumAiCoach,
  }) => SubscriptionState(
    plan: plan,
    entitlements: const {
      CommerceEntitlement.advancedIntelligence,
      CommerceEntitlement.mealPlanning,
      CommerceEntitlement.premiumPrograms,
    },
    authority: EntitlementAuthority.verifiedServer,
    currentPeriodEndsAt: end ?? now.add(const Duration(hours: 1)),
    isPurchasable: false,
    canRestorePurchases: true,
  );

  static Object quota(int remaining) => {
    'credits': {'total_remaining': remaining},
  };

  Future<void> mount(
    WidgetTester tester, {
    bool arabic = false,
    bool dark = false,
    bool showOverview = true,
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(arabic ? 'ar' : 'en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(
            dark
                ? BilFlagshipTheme.dark(isArabic: arabic)
                : BilFlagshipTheme.light(isArabic: arabic),
            fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
          ),
          home: !showOverview
              ? const SizedBox()
              : RepaintBoundary(
                  key: boundaryKey,
                  child: Stack(
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
                  ),
                ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    if (settle) await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> close(WidgetTester tester) async {
    for (final read in subscriptionReads) {
      if (!read.result.isCompleted) read.result.complete(_free());
    }
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
    await owners.close();
  }

  String label(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(_label)).data!;

  void emitOwner(String? next) {
    owner = next;
    owners.add(next);
  }

  Future<Uint8List> headerPixels(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final rows =
        (tester
                    .getTopLeft(
                      find.byKey(const Key('coach-workspace-tab-coach')),
                    )
                    .dy *
                2)
            .floor();
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final raw = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final bytes = Uint8List.fromList(
          raw.buffer.asUint8List(raw.offsetInBytes, rows * image.width * 4),
        );
        final output = Platform.environment['BIL_PREMIUM_CAPTURE_DIR'];
        if (output != null) {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await Directory(output).create(recursive: true);
          await File(
            '$output/$name.png',
          ).writeAsBytes(png.buffer.asUint8List());
        }
        return bytes;
      } finally {
        image.dispose();
      }
    }))!;
  }
}

final class _OverviewSubscriptionRead {
  _OverviewSubscriptionRead({
    required this.rawOwner,
    required this.scalarOwner,
    required this.visit,
    required this.generation,
  });

  final String? rawOwner;
  final String? scalarOwner;
  final int visit;
  final int generation;
  final result = Completer<SubscriptionState>();

  Map<String, Object?> get trace => {
    'rawOwner': rawOwner,
    'scalarOwner': scalarOwner,
    'visit': visit,
    'readGeneration': generation,
  };
}

void _expectDistinctOwnerReads(
  _OverviewFixture fixture,
  int count, {
  int expectedVisit = 2,
}) {
  final reads = fixture.subscriptionReads;
  final trace = reads.map((read) => read.trace).toList();
  expect(fixture.subscriptionLoads, count, reason: '$trace');
  expect(reads.length, count, reason: '$trace');
  expect(reads.map((read) => read.result.future).toSet().length, count);
  expect(
    reads.map((read) => read.generation),
    orderedEquals(List.generate(count, (index) => index + 1)),
    reason: '$trace',
  );
  expect(reads.first.rawOwner, _ownerA);
  expect(reads.first.scalarOwner, _ownerA);
  expect(reads.first.visit, 0);
  expect(reads.last.rawOwner, _ownerA, reason: '$trace');
  expect(reads.last.scalarOwner, _ownerA, reason: '$trace');
  expect(reads.last.visit, expectedVisit, reason: '$trace');
  expect(
    fixture.container.read(verifiedEntitlementOwnerVisitProvider),
    expectedVisit,
    reason: 'Completing a retired source must not manufacture another visit.',
  );
}

void _expectPendingOwnerRead(
  _OverviewFixture fixture,
  int count, {
  int expectedVisit = 2,
}) {
  _expectDistinctOwnerReads(fixture, count, expectedVisit: expectedVisit);
  final credits = fixture.container.read(aiCoachCreditAccessProvider);
  expect(credits.isLoading, isFalse);
  expect(credits.hasError, isFalse);
  expect(credits.requireValue, isFalse);
  expect(find.byKey(_label), findsNothing);
  expect(find.text('Premium AI Coach'), findsNothing);
  expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
  final raw = fixture.container.read(verifiedSubscriptionAccessProvider);
  expect(raw.isLoading, isTrue);
  expect(
    raw.asData?.value.grants(CommerceEntitlement.advancedIntelligence),
    isNot(true),
  );
}

Future<void> _completeOnlyCurrentOwnerRead(
  WidgetTester tester,
  _OverviewFixture fixture,
  int count, {
  int expectedVisit = 2,
}) async {
  _expectPendingOwnerRead(fixture, count, expectedVisit: expectedVisit);
  // Each retired request returns a paid result independently. None may seed
  // the label or mount the protected child while the newest read is pending.
  for (final retired in fixture.subscriptionReads.sublist(1, count - 1)) {
    retired.result.complete(fixture.paid());
    await tester.pump();
    await tester.pump();
    _expectPendingOwnerRead(fixture, count, expectedVisit: expectedVisit);
  }
  final current = fixture.subscriptionReads.last;
  expect(current.result.isCompleted, isFalse);
  current.result.complete(fixture.paid(plan: CommercePlan.premium));
  await tester.pump();
  await tester.pumpAndSettle();
  _expectDistinctOwnerReads(fixture, count, expectedVisit: expectedVisit);
  expect(fixture.label(tester), 'Premium');
  expect(find.text('Premium AI Coach'), findsNothing);
  expect(find.byKey(_authorized, skipOffstage: false), findsOneWidget);
  final raw = fixture.container.read(verifiedSubscriptionAccessProvider);
  expect(raw.isLoading, isFalse);
  expect(raw.hasError, isFalse);
  expect(raw.asData?.value.plan, CommercePlan.premium);
  expect(
    raw.asData?.value.grants(CommerceEntitlement.advancedIntelligence),
    isTrue,
  );
  await tester.pump();
  await tester.pump();
  _expectDistinctOwnerReads(fixture, count, expectedVisit: expectedVisit);
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  testWidgets(
    'quota refresh keeps a verified Premium badge and stable Overview geometry',
    (tester) async {
      final fixture = _OverviewFixture();
      final refresh = Completer<Object?>();
      try {
        await fixture.mount(tester);
        final initialLabel = fixture.label(tester);
        expect(initialLabel, 'Premium AI Coach');
        final initialTab = tester.getRect(
          find.byKey(const Key('coach-workspace-tab-coach')),
        );
        fixture.usage = refresh.future;
        fixture.container
            .read(aiCoachUsageRefreshProvider.notifier)
            .requestAuthoritativeReload();
        await tester.pump();
        expect(
          fixture.container.read(aiCoachCreditAccessProvider).isLoading,
          isTrue,
        );
        expect(find.byKey(_label), findsOneWidget);
        expect(fixture.label(tester), initialLabel);
        expect(
          tester.getRect(find.byKey(const Key('coach-workspace-tab-coach'))),
          initialTab,
        );
        refresh.complete(_OverviewFixture.quota(2500));
        await fixture.container.read(aiCoachCreditAccessProvider.future);
        await tester.pumpAndSettle();
        expect(fixture.label(tester), initialLabel);
      } finally {
        if (!refresh.isCompleted) {
          refresh.complete(_OverviewFixture.quota(2500));
        }
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'transient subscription failure retains only the paid label while the real gate fails closed',
    (tester) async {
      final fixture = _OverviewFixture();
      final refresh = Completer<SubscriptionState>();
      try {
        await fixture.mount(tester);
        final initialLabel = fixture.label(tester);
        expect(initialLabel, 'Premium AI Coach');
        expect(find.byKey(_authorized, skipOffstage: false), findsOneWidget);
        fixture.subscription = refresh.future;
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        expect(fixture.label(tester), initialLabel);
        final observed = fixture.container
            .read(verifiedSubscriptionStateProvider.future)
            .then<Object?>((_) => null, onError: (Object error) => error);
        refresh.completeError(
          StateError('Synthetic subscription authority unavailable'),
        );
        await observed;
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const Key('premium-route-access-unavailable'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
        expect(fixture.label(tester), initialLabel);
      } finally {
        if (!refresh.isCompleted) refresh.complete(fixture.paid());
        await fixture.close(tester);
      }
    },
  );

  for (final arabic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Overview paid label pixels stay stable during quota refresh arabic=$arabic dark=$dark',
        (tester) async {
          final fixture = _OverviewFixture();
          final pending = Completer<Object?>();
          final stem = '${arabic ? "ar" : "en"}-${dark ? "dark" : "light"}';
          try {
            await fixture.mount(tester, arabic: arabic, dark: dark);
            final initialLabel = fixture.label(tester);
            final before = await fixture.headerPixels(tester, '$stem-before');
            fixture.usage = pending.future;
            fixture.container
                .read(aiCoachUsageRefreshProvider.notifier)
                .requestAuthoritativeReload();
            await tester.pump();
            expect(fixture.label(tester), initialLabel);
            final during = await fixture.headerPixels(tester, '$stem-refresh');
            expect(during.length, before.length);
            final changedBytes = List.generate(
              before.length,
              (index) => index,
            ).where((index) => before[index] != during[index]).length;
            expect(
              changedBytes,
              0,
              reason:
                  'Actual rendered header pixels must remain identical during a same-owner quota reload.',
            );
            pending.complete(_OverviewFixture.quota(2500));
            await fixture.container.read(aiCoachCreditAccessProvider.future);
            await tester.pumpAndSettle();
            expect(fixture.label(tester), initialLabel);
          } finally {
            if (!pending.isCompleted) {
              pending.complete(_OverviewFixture.quota(2500));
            }
            await fixture.close(tester);
          }
        },
      );
    }
  }

  for (final failed in [false, true]) {
    testWidgets(
      'cached paid label expires during ${failed ? "failed" : "pending"} verification without granting access',
      (tester) async {
        final fixture = _OverviewFixture();
        final end = fixture.now.add(const Duration(seconds: 2));
        fixture.subscription = Future.value(fixture.paid(end: end));
        fixture.usage = Future.value(_OverviewFixture.quota(0));
        final pending = Completer<SubscriptionState>();
        try {
          await fixture.mount(tester);
          expect(fixture.label(tester), 'Premium AI Coach');
          fixture.subscription = pending.future;
          fixture.container.invalidate(verifiedSubscriptionStateProvider);
          await tester.pump();
          final observed = fixture.container
              .read(verifiedSubscriptionStateProvider.future)
              .then<Object?>((_) => null, onError: (Object error) => error);
          if (failed) {
            pending.completeError(StateError('Synthetic offline verification'));
            await observed;
            await tester.pump();
            expect(fixture.label(tester), 'Premium AI Coach');
            expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
          }
          fixture.now = end;
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          expect(find.byKey(_label), findsNothing);
          expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
        } finally {
          if (!pending.isCompleted) pending.complete(fixture.paid(end: end));
          await fixture.close(tester);
        }
      },
    );
  }

  testWidgets(
    'verified downgrade clears the paid label and later error cannot restore it',
    (tester) async {
      final fixture = _OverviewFixture();
      try {
        await fixture.mount(tester);
        expect(fixture.label(tester), 'Premium AI Coach');
        fixture.usage = Future.value(_OverviewFixture.quota(0));
        fixture.container
            .read(aiCoachUsageRefreshProvider.notifier)
            .requestAuthoritativeReload();
        await fixture.container.read(aiCoachCreditAccessProvider.future);
        await tester.pump();
        expect(
          fixture.label(tester),
          'Premium AI Coach',
          reason: 'Tier label is independent of an exhausted quota.',
        );
        fixture.subscription = Future.value(_free());
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await fixture.container.read(verifiedSubscriptionStateProvider.future);
        await tester.pump();
        expect(find.byKey(_label), findsNothing);
        expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
        final error = Completer<SubscriptionState>();
        fixture.subscription = error.future;
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        final observed = fixture.container
            .read(verifiedSubscriptionStateProvider.future)
            .then<Object?>((_) => null, onError: (Object error) => error);
        error.completeError(StateError('Synthetic later failure'));
        await observed;
        await tester.pump();
        expect(find.byKey(_label), findsNothing);
        expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  test(
    'headless coalesced raw owner visits retire every old producer and accept only the current read',
    () async {
      // This models a scalar fixed at A while raw auth makes A -> B -> A.
      // Keep the real providers and strict producer retirement here. Native
      // widget scheduling is covered separately with the actual scalar graph.
      final fixture = _OverviewFixture(
        coalescedOwnerProjection: true,
        recordSubscriptionReads: true,
        initialCreditRemaining: 0,
      );
      final labels = fixture.container.listen(
        coachOverviewPaidLabelProvider,
        (_, _) {},
      );
      final credits = fixture.container.listen(
        coachOverviewCreditAccessProvider,
        (_, _) {},
      );
      final access = fixture.container.listen(
        verifiedSubscriptionAccessProvider,
        (_, _) {},
      );
      try {
        await fixture.container.read(verifiedSubscriptionStateProvider.future);
        await fixture.container.read(aiCoachCreditAccessProvider.future);
        await fixture.container.pump();
        expect(fixture.subscriptionLoads, 1);
        expect(
          fixture.container.read(coachOverviewPaidLabelProvider),
          CommercePlan.premiumAiCoach,
        );
        expect(
          fixture.container.read(coachOverviewCreditAccessProvider),
          isFalse,
        );

        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        fixture.container
            .read(verifiedSubscriptionStateProvider.future)
            .ignore();
        expect(fixture.subscriptionLoads, 2);
        fixture.emitOwner(_ownerB);
        // A real read begun for the intermediate raw owner is an independent
        // producer. This is a headless business operation, not a UI preflush.
        fixture.container
            .read(verifiedSubscriptionStateProvider.future)
            .ignore();
        expect(fixture.subscriptionLoads, 3);
        expect(fixture.subscriptionReads.last.visit, 1);
        final returnedA = Completer<void>();
        final rawOwnerReturn = fixture.container.listen(
          verifiedEntitlementOwnerProvider,
          (_, next) {
            if (!next.isLoading &&
                next.hasValue &&
                next.value == _ownerA &&
                !returnedA.isCompleted) {
              returnedA.complete();
            }
          },
          fireImmediately: false,
        );
        try {
          fixture.emitOwner(_ownerA);
          // Await the actual raw A delivery. ProviderContainer.pump waits for
          // scheduled provider work, not a paused stream's buffered auth event.
          await returnedA.future.timeout(const Duration(seconds: 5));
          fixture.container
              .read(verifiedSubscriptionStateProvider.future)
              .ignore();
          await fixture.container.pump();
          _expectDistinctOwnerReads(fixture, 4);
        } finally {
          rawOwnerReturn.close();
        }
        // Credit authority is independent and asynchronous. Await this current
        // zero-credit result before asserting the subscription-only boundary.
        await fixture.container.read(aiCoachCreditAccessProvider.future);
        await fixture.container.pump();

        void expectPendingAuthority() {
          _expectDistinctOwnerReads(fixture, 4);
          final currentAccess = fixture.container.read(
            verifiedSubscriptionAccessProvider,
          );
          expect(currentAccess.isLoading, isTrue);
          expect(
            currentAccess.asData?.value.grants(
              CommerceEntitlement.advancedIntelligence,
            ),
            isNot(true),
          );
          expect(
            fixture.container.read(coachOverviewPaidLabelProvider),
            isNull,
          );
          final currentCredits = fixture.container.read(
            aiCoachCreditAccessProvider,
          );
          expect(currentCredits.isLoading, isFalse);
          expect(currentCredits.hasError, isFalse);
          expect(currentCredits.requireValue, isFalse);
          expect(
            fixture.container.read(coachOverviewCreditAccessProvider),
            isFalse,
          );
        }

        expectPendingAuthority();
        for (final retired in fixture.subscriptionReads.sublist(1, 3)) {
          expect(retired.result.isCompleted, isFalse);
          retired.result.complete(fixture.paid());
          await fixture.container.pump();
          expectPendingAuthority();
        }
        final current = fixture.subscriptionReads.last;
        expect(current.result.isCompleted, isFalse);
        current.result.complete(fixture.paid(plan: CommercePlan.premium));
        await fixture.container.read(verifiedSubscriptionStateProvider.future);
        await fixture.container.pump();
        _expectDistinctOwnerReads(fixture, 4);
        final currentAccess = fixture.container.read(
          verifiedSubscriptionAccessProvider,
        );
        expect(currentAccess.isLoading, isFalse);
        expect(currentAccess.hasError, isFalse);
        expect(currentAccess.requireValue.plan, CommercePlan.premium);
        expect(
          currentAccess.requireValue.grants(
            CommerceEntitlement.advancedIntelligence,
          ),
          isTrue,
        );
        expect(
          fixture.container.read(coachOverviewPaidLabelProvider),
          CommercePlan.premium,
        );
        expect(
          fixture.container.read(coachOverviewCreditAccessProvider),
          isFalse,
        );
      } finally {
        labels.close();
        credits.close();
        access.close();
        fixture.container.dispose();
        for (final read in fixture.subscriptionReads) {
          if (!read.result.isCompleted) read.result.complete(_free());
        }
        await fixture.owners.close();
      }
    },
  );

  testWidgets(
    'real owner visits ignore old producer results and accept the current producer',
    (tester) async {
      final fixture = _OverviewFixture(
        recordSubscriptionReads: true,
        initialCreditRemaining: 0,
      );
      try {
        await fixture.mount(tester);
        expect(fixture.subscriptionLoads, 1);
        expect(fixture.label(tester), 'Premium AI Coach');
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        expect(fixture.subscriptionLoads, 2);
        fixture.emitOwner(_ownerB);
        await tester.pump();
        fixture.emitOwner(_ownerA);
        await tester.pump();
        await tester.pump();
        // The real scalar projection and mounted gate have three bounded
        // invocations across these two delivered visits. No queue reuses old.
        _expectDistinctOwnerReads(fixture, 5);
        await _completeOnlyCurrentOwnerRead(tester, fixture, 5);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'a read begun while Overview is hidden is retired before the next UI pump',
    (tester) async {
      final fixture = _OverviewFixture(
        recordSubscriptionReads: true,
        initialCreditRemaining: 0,
      );
      final authorityObserver = fixture.container.listen(
        verifiedSubscriptionStateProvider,
        (_, _) {},
      );
      try {
        await fixture.mount(tester);
        expect(fixture.subscriptionLoads, 1);
        final initialVisit = fixture.container.read(
          verifiedEntitlementOwnerVisitProvider,
        );
        expect(initialVisit, 0);
        await fixture.mount(tester, showOverview: false);
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        fixture.container
            .read(verifiedSubscriptionStateProvider.future)
            .ignore();
        expect(fixture.subscriptionLoads, 2);
        fixture.emitOwner(_ownerB);
        fixture.emitOwner(_ownerA);
        await tester.pump();
        final currentVisit = fixture.container.read(
          verifiedEntitlementOwnerVisitProvider,
        );
        // Both raw visits have arrived, but the latest loader was begun in
        // the retired visit. A dirty lazy provider need not start its next
        // producer until the real Overview watches it again.
        expect(currentVisit, 2);
        final hiddenReads = fixture.subscriptionReads;
        expect(fixture.subscriptionLoads, 3);
        expect(hiddenReads, hasLength(3));
        expect(
          hiddenReads.map((read) => read.result.future).toSet(),
          hasLength(3),
        );
        expect(
          hiddenReads.map((read) => read.generation),
          orderedEquals([1, 2, 3]),
        );
        expect(hiddenReads.last.visit, 1);
        expect(hiddenReads.last.visit, lessThan(currentVisit));
        expect(hiddenReads.last.result.isCompleted, isFalse);
        // Reopen the actual Overview; its real watch starts generation four
        // for visit two. No fixture invalidation forces a replacement read.
        // Checking has a live animation, so drain frames without settling it.
        await fixture.mount(tester, settle: false);
        _expectDistinctOwnerReads(fixture, 4, expectedVisit: currentVisit);
        // Retired generations two and three each return paid independently;
        // neither may grant before the current generation four completes.
        await _completeOnlyCurrentOwnerRead(
          tester,
          fixture,
          4,
          expectedVisit: currentVisit,
        );
      } finally {
        authorityObserver.close();
        await fixture.close(tester);
      }
    },
  );

  for (final rapid in [false, true]) {
    testWidgets(
      'owner A B A cannot restore the old label before fresh verification rapid=$rapid',
      (tester) async {
        final fixture = _OverviewFixture();
        final ownerB = Completer<SubscriptionState>();
        final ownerA = Completer<SubscriptionState>();
        try {
          await fixture.mount(tester);
          expect(fixture.label(tester), 'Premium AI Coach');
          fixture.subscription = ownerB.future;
          fixture.emitOwner(_ownerB);
          if (!rapid) {
            await tester.pump();
            await tester.pump();
            expect(find.text('Premium AI Coach'), findsNothing);
            expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
          }
          fixture.subscription = ownerA.future;
          fixture.emitOwner(_ownerA);
          await tester.pump();
          await tester.pump();
          expect(find.text('Premium AI Coach'), findsNothing);
          ownerB.complete(fixture.paid());
          await tester.pump();
          expect(find.text('Premium AI Coach'), findsNothing);
          // Explicitly request the current owner's new verification if stream
          // notifications were coalesced into one rendered frame.
          fixture.container.invalidate(verifiedSubscriptionStateProvider);
          await tester.pump();
          ownerA.complete(fixture.paid(plan: CommercePlan.premium));
          await fixture.container.read(
            verifiedSubscriptionStateProvider.future,
          );
          await tester.pump();
          expect(fixture.label(tester), 'Premium');
          expect(find.byKey(_authorized, skipOffstage: false), findsOneWidget);
        } finally {
          if (!ownerB.isCompleted) ownerB.complete(_free());
          if (!ownerA.isCompleted) ownerA.complete(_free());
          await fixture.close(tester);
        }
      },
    );
  }

  testWidgets(
    'sign out drops paid presentation and a late old-owner result cannot restore it',
    (tester) async {
      final fixture = _OverviewFixture();
      final old = Completer<SubscriptionState>();
      try {
        await fixture.mount(tester);
        fixture.subscription = old.future;
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        fixture.emitOwner(null);
        fixture.subscription = Future.value(_free());
        fixture.usage = Future.value(_OverviewFixture.quota(0));
        await tester.pump();
        await tester.pump();
        expect(find.text('Premium AI Coach'), findsNothing);
        expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
        old.complete(fixture.paid());
        await tester.pump();
        expect(find.text('Premium AI Coach'), findsNothing);
      } finally {
        if (!old.isCompleted) old.complete(_free());
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'reopening Overview during an error retains its bounded label without hidden quota polls',
    (tester) async {
      final fixture = _OverviewFixture();
      final pending = Completer<SubscriptionState>();
      try {
        await fixture.mount(tester);
        fixture.subscription = pending.future;
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        final observed = fixture.container
            .read(verifiedSubscriptionStateProvider.future)
            .then<Object?>((_) => null, onError: (Object error) => error);
        pending.completeError(
          StateError('Synthetic temporary authority failure'),
        );
        await observed;
        await tester.pump();
        expect(fixture.label(tester), 'Premium AI Coach');
        await fixture.mount(tester, showOverview: false);
        await tester.pump();
        await tester.pump();
        final subscriptionLoads = fixture.subscriptionLoads;
        final usageLoads = fixture.usageLoads;
        await tester.pump(const Duration(seconds: 31));
        expect(fixture.subscriptionLoads, subscriptionLoads);
        expect(fixture.usageLoads, usageLoads);
        await fixture.mount(tester);
        expect(fixture.label(tester), 'Premium AI Coach');
        expect(find.byKey(_authorized, skipOffstage: false), findsNothing);
      } finally {
        if (!pending.isCompleted) pending.complete(fixture.paid());
        await fixture.close(tester);
      }
    },
  );
}

SubscriptionState _free() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: false,
);
