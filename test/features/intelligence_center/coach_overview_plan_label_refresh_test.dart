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
  _OverviewFixture() {
    subscription = Future.value(paid());
    usage = Future.value(quota(2500));
    container = ProviderContainer(
      overrides: [
        verifiedEntitlementOwnerSeedProvider.overrideWithValue(_ownerA),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWithValue(() {
          subscriptionLoads++;
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
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> close(WidgetTester tester) async {
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
