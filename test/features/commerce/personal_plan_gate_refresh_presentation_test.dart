import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _ctaKey = ValueKey('premium-route-upgrade-cta');
const _checkingKey = ValueKey('premium-route-access-checking');
const _protectedKey = ValueKey('protected-personal-plan');
const _captureKey = ValueKey('personal-plan-gate-capture');

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in const ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      _boundedTestWidgets(
        '$language $brightness: 30s Free recheck preserves gate element and geometry without granting access',
        (tester) async {
          final fixture = _GateFixture();
          try {
            await fixture.mount(tester, language, brightness);
            expect(find.byKey(_checkingKey), findsOneWidget);
            expect(find.byKey(_ctaKey), findsNothing);
            expect(find.byKey(_protectedKey), findsNothing);
            fixture.requests.single.complete(_free());
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            final originalElement = tester.element(find.byKey(_ctaKey));
            final originalRect = tester.getRect(find.byKey(_ctaKey));
            final originalLabel = tester
                .widget<FilledButton>(find.byKey(_ctaKey))
                .child;
            expect(
              tester.widget<FilledButton>(find.byKey(_ctaKey)).onPressed,
              isNotNull,
            );
            await _captureIfRequested(
              tester,
              '$language-${brightness.name}-before',
            );

            await tester.pump(const Duration(seconds: 30));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            expect(fixture.requests, hasLength(2));
            // The existing authority contract remains neutral/loading. Only
            // the public gate presentation is retained; no cached grant exists.
            expect(
              fixture.container
                  .read(verifiedSubscriptionAccessProvider)
                  .isLoading,
              isTrue,
            );
            expect(find.byKey(_checkingKey), findsNothing);
            expect(find.byKey(_protectedKey), findsNothing);
            expect(tester.element(find.byKey(_ctaKey)), same(originalElement));
            expect(tester.getRect(find.byKey(_ctaKey)), originalRect);
            expect(
              (tester.widget<FilledButton>(find.byKey(_ctaKey)).child as Text)
                  .data,
              (originalLabel as Text).data,
            );
            expect(
              tester.widget<FilledButton>(find.byKey(_ctaKey)).onPressed,
              isNull,
            );
            await _captureIfRequested(
              tester,
              '$language-${brightness.name}-during',
            );

            fixture.requests.last.complete(_free());
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            expect(tester.element(find.byKey(_ctaKey)), same(originalElement));
            expect(tester.getRect(find.byKey(_ctaKey)), originalRect);
            expect(
              tester.widget<FilledButton>(find.byKey(_ctaKey)).onPressed,
              isNotNull,
            );
            expect(fixture.requests, hasLength(2));
            await _captureIfRequested(
              tester,
              '$language-${brightness.name}-after',
            );
          } finally {
            await fixture.close(tester);
          }
        },
      );
    }
  }

  _boundedTestWidgets('fresh paid response opens the actual protected child', (
    tester,
  ) async {
    final fixture = _GateFixture();
    try {
      await fixture.mount(tester);
      fixture.requests.single.complete(_free());
      await tester.pump();
      await tester.pump();
      fixture.container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pump();
      expect(find.byKey(_ctaKey), findsOneWidget);
      expect(find.byKey(_protectedKey), findsNothing);
      fixture.requests.last.complete(fixture.paid());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_protectedKey), findsOneWidget);
      expect(find.byKey(_ctaKey), findsNothing);
      expect(find.byKey(_checkingKey), findsNothing);
    } finally {
      await fixture.close(tester);
    }
  });

  _boundedTestWidgets(
    'refresh failure replaces retained offer with existing Retry surface',
    (tester) async {
      final fixture = _GateFixture();
      try {
        await fixture.mount(tester);
        fixture.requests.single.complete(_free());
        await tester.pump();
        await tester.pump();
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        expect(find.byKey(_ctaKey), findsOneWidget);
        fixture.requests.last.completeError(StateError('offline-test'));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_ctaKey), findsNothing);
        expect(find.byKey(_protectedKey), findsNothing);
        expect(
          find.byKey(const ValueKey('premium-route-access-unavailable')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('premium-route-access-retry')),
        );
        await tester.pump();
        expect(find.byKey(_checkingKey), findsOneWidget);
        expect(find.byKey(_ctaKey), findsNothing);
        fixture.requests.last.complete(_free());
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_ctaKey), findsOneWidget);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  _boundedTestWidgets(
    'A to B to A rejects retained card and late source generations',
    (tester) async {
      final fixture = _GateFixture();
      try {
        await fixture.mount(tester);
        fixture.requests.single.complete(_free());
        await tester.pump();
        await tester.pump();
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        final oldA = fixture.requests.last;
        expect(find.byKey(_ctaKey), findsOneWidget);

        fixture.owners.add('owner-b');
        await tester.pump();
        await tester.pump();
        final ownerB = fixture.requests.last;
        expect(identical(ownerB, oldA), isFalse);
        expect(find.byKey(_checkingKey), findsOneWidget);
        expect(find.byKey(_ctaKey), findsNothing);
        fixture.owners.add('owner-a');
        await tester.pump();
        await tester.pump();
        final newA = fixture.requests.last;
        expect(identical(newA, ownerB), isFalse);
        expect(find.byKey(_checkingKey), findsOneWidget);

        oldA.complete(_free());
        ownerB.complete(fixture.paid());
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_ctaKey), findsNothing);
        expect(find.byKey(_protectedKey), findsNothing);
        expect(find.byKey(_checkingKey), findsOneWidget);
        newA.complete(_free());
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_ctaKey), findsOneWidget);
        expect(find.byKey(_protectedKey), findsNothing);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  _boundedTestWidgets(
    'raw A to B to A between frames clears Free retention even when scalar owner coalesces',
    (tester) async {
      final fixture = _GateFixture(coalescedOwner: true);
      try {
        await fixture.mount(tester);
        fixture.requests.single.complete(_free());
        await tester.pump();
        await tester.pump();
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        expect(find.byKey(_ctaKey), findsOneWidget);
        fixture.owners
          ..add('owner-b')
          ..add('owner-a');
        await tester.pump();
        await tester.pump();
        expect(
          fixture.container.read(verifiedEntitlementOwnerIdProvider),
          'owner-a',
        );
        expect(fixture.requests, hasLength(2));
        expect(find.byKey(_ctaKey), findsNothing);
        expect(find.byKey(_checkingKey), findsOneWidget);
        expect(find.byKey(_protectedKey), findsNothing);
        // The deliberately coalesced scalar fixture does not create a new
        // authority request for the owner excursion. Its old Future can settle,
        // but must not seed retained presentation for the returned owner's visit.
        fixture.requests.last.complete(_free());
        await tester.pump();
        await tester.pump();
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        expect(find.byKey(_checkingKey), findsOneWidget);
        expect(find.byKey(_ctaKey), findsNothing);
        fixture.requests.last.complete(_free());
        await tester.pump();
        await tester.pump();
        fixture.container.invalidate(verifiedSubscriptionStateProvider);
        await tester.pump();
        expect(find.byKey(_checkingKey), findsNothing);
        expect(find.byKey(_ctaKey), findsOneWidget);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  _boundedTestWidgets(
    'exact paid expiry still removes protected content immediately',
    (tester) async {
      final fixture = _GateFixture();
      try {
        await fixture.mount(tester);
        final end = fixture.now.add(const Duration(seconds: 1));
        fixture.requests.single.complete(fixture.paid(end: end));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_protectedKey), findsOneWidget);
        fixture.now = end;
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.byKey(_protectedKey), findsNothing);
        expect(find.byKey(_ctaKey), findsOneWidget);
        expect(
          fixture.container
              .read(verifiedSubscriptionAccessProvider)
              .value
              ?.plan,
          CommercePlan.free,
        );
      } finally {
        await fixture.close(tester);
      }
    },
  );
}

SubscriptionState _free() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: FreePlan.entitlements,
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: false,
);

class _GateFixture {
  _GateFixture({this.coalescedOwner = false});

  final bool coalescedOwner;
  final owners = StreamController<String?>();
  final requests = <Completer<SubscriptionState>>[];
  DateTime now = DateTime.utc(2026, 11, 6);
  late final ProviderContainer container = ProviderContainer(
    overrides: [
      verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
      verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
      if (coalescedOwner)
        verifiedEntitlementOwnerIdProvider.overrideWithValue('owner-a'),
      verifiedEntitlementClockProvider.overrideWithValue(() => now),
      verifiedEntitlementLoaderProvider.overrideWithValue(() {
        final next = Completer<SubscriptionState>();
        requests.add(next);
        return next.future;
      }),
      storefrontTargetPlanProvider.overrideWith(
        (_) async => CommercePlan.premium,
      ),
    ],
  );

  SubscriptionState paid({DateTime? end}) => SubscriptionState(
    plan: CommercePlan.premium,
    entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.premium),
    authority: EntitlementAuthority.verifiedServer,
    lifecycle: SubscriptionLifecycle.active,
    startedAt: now.subtract(const Duration(minutes: 1)),
    currentPeriodEndsAt: end ?? now.add(const Duration(hours: 1)),
    isPurchasable: false,
    canRestorePurchases: false,
  );

  Future<void> mount(
    WidgetTester tester, [
    String language = 'en',
    Brightness brightness = Brightness.light,
  ]) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(
            brightness == Brightness.dark
                ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                : BilFlagshipTheme.light(isArabic: language == 'ar'),
            fontFamily: language == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          home: const Scaffold(
            body: RepaintBoundary(
              key: _captureKey,
              child: PremiumRouteGlassGate(
                feature: PremiumGateFeature.personalPlan,
                child: Text('Protected personal plan', key: _protectedKey),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
    await tester.runAsync(owners.close);
  }
}

Future<void> _captureIfRequested(WidgetTester tester, String filename) async {
  final destination = Platform.environment['BIL_PREMIUM_CAPTURE_DIR'];
  if (destination == null || destination.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Real render returned no PNG');
      final folder = Directory(destination)..createSync(recursive: true);
      await File('${folder.path}/$filename.png').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}

void _boundedTestWidgets(String name, WidgetTesterCallback body) {
  testWidgets(name, body, timeout: const Timeout(Duration(seconds: 30)));
}
