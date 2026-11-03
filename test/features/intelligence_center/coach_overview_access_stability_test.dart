import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_overview_paid_label_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _label = Key('coach-workspace-plan-label');
const _tab = Key('coach-workspace-tab-coach');
final _now = DateTime(2026, 11, 1, 12);
final _snapshot = CoachContextSnapshot(
  generatedAt: _now,
  profile: const {'displayName': 'Owner A'},
  weights: const [],
  nutritionDays: const [
    CoachNutritionDay(
      day: '2026-11-01',
      meals: [],
      calories: 964,
      protein: 50,
      carbs: 192,
      fat: 4.2,
      sodium: 0,
    ),
  ],
  waterHistory: const [],
  computedHealth: const {
    'dailyTargets': {
      'caloriesKcal': 2103,
      'proteinG': 114,
      'carbsG': 254,
      'fatG': 70,
    },
  },
);

Object _quota(int value) => {
  'credits': {'total_remaining': value},
};

class _Fixture {
  final boundaryKey = GlobalKey();
  final owners = StreamController<String?>.broadcast(sync: true);
  Future<Object?> response = Future.value(_quota(2500));
  late final container = ProviderContainer(
    overrides: [
      verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
      verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
      coachOverviewPaidLabelProvider.overrideWith((_) => null),
      aiCoachUsageStatusLoaderProvider.overrideWithValue(() => response),
    ],
  );
  Future<void> mount(
    WidgetTester tester, {
    bool arabic = false,
    bool dark = false,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: CoachReferenceWorkspace(
              snapshot: _snapshot,
              now: _now,
              onChat: () {},
              onRoute: (_) {},
              onQuickAdd: () {},
              onPhoto: () {},
              onVoice: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    // The comparison is about a quota reload, not the unrelated first decode
    // of the two shipped images. Await their real image streams before BEFORE.
    await tester.runAsync(() async {
      final context = tester.element(find.byType(CoachReferenceWorkspace));
      await Future.wait([
        precacheImage(
          const AssetImage(
            'assets/images/commerce/bil_ai_boost_coach_icon_512.png',
          ),
          context,
        ),
        precacheImage(
          const AssetImage(
            'assets/images/professional/mediterranean_protein_bowl.png',
          ),
          context,
        ),
      ]);
    });
    await tester.pump();
  }

  List<double?> progress(WidgetTester tester) => tester
      .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .take(4)
      .map((item) => item.value)
      .toList();

  Future<Uint8List> pixels(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final raw = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final output = Platform.environment['BIL_PREMIUM_CAPTURE_DIR'];
        if (output != null) {
          await Directory(output).create(recursive: true);
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await File(
            '$output/$name.png',
          ).writeAsBytes(png.buffer.asUint8List());
        }
        return Uint8List.fromList(raw.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }))!;
  }

  void reload() => container
      .read(aiCoachUsageRefreshProvider.notifier)
      .requestAuthoritativeReload();
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await owners.close();
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final arabic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Boost badge and all nutrient pixels survive reload arabic=$arabic dark=$dark',
        (tester) async {
          final f = _Fixture();
          final pending = Completer<Object?>();
          final stem =
              'boost-${arabic ? "ar" : "en"}-${dark ? "dark" : "light"}';
          try {
            await f.mount(tester, arabic: arabic, dark: dark);
            final rect = tester.getRect(find.byKey(_tab));
            final progress = f.progress(tester);
            expect(progress.length, 4);
            expect(progress, everyElement(greaterThan(0)));
            final before = await f.pixels(tester, '$stem-before');
            f.response = pending.future;
            f.reload();
            await tester.pump();
            expect(find.byKey(_label), findsOneWidget);
            expect(tester.getRect(find.byKey(_tab)), rect);
            expect(f.progress(tester), progress);
            expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
            final during = await f.pixels(tester, '$stem-reload');
            expect(
              listEquals(during, before),
              isTrue,
              reason:
                  'Rendered Boost label and nutrient cards must not change during this reload.',
            );
            pending.complete(_quota(2500));
            await f.container.read(aiCoachCreditAccessProvider.future);
            await tester.pump();
            expect(tester.getRect(find.byKey(_tab)), rect);
            expect(f.progress(tester), progress);
            final after = await f.pixels(tester, '$stem-after');
            expect(
              listEquals(after, before),
              isTrue,
              reason:
                  'Unchanged verified values must render the same after this reload.',
            );
            expect(tester.takeException(), isNull);
          } finally {
            if (!pending.isCompleted) pending.complete(_quota(0));
            await f.close(tester);
          }
        },
      );
    }
  }

  testWidgets('scaled Boost label keeps its slot on fresh denial', (
    tester,
  ) async {
    final f = _Fixture();
    try {
      await f.mount(tester, arabic: true, textScale: 2);
      final rect = tester.getRect(find.byKey(_tab));
      f.response = Future.value(_quota(0));
      f.reload();
      await f.container.read(aiCoachCreditAccessProvider.future);
      await tester.pump();
      expect(find.byKey(_label), findsNothing);
      expect(tester.getRect(find.byKey(_tab)), rect);
      expect(tester.takeException(), isNull);
    } finally {
      await f.close(tester);
    }
  });
  testWidgets(
    'transient failure keeps this visit, fresh zero removes access without moving tabs',
    (tester) async {
      final f = _Fixture();
      final pending = Completer<Object?>();
      try {
        await f.mount(tester);
        final geometry = tester.getRect(find.byKey(_tab));
        f.response = pending.future;
        f.reload();
        await tester.pump();
        expect(find.text('Verified AI Boost access'), findsOneWidget);
        pending.completeError(StateError('synthetic unavailable authority'));
        expect(
          await f.container.read(aiCoachCreditAccessProvider.future),
          isTrue,
        );
        await tester.pump();
        expect(find.text('964 / 2103'), findsOneWidget);
        expect(tester.getRect(find.byKey(_tab)), geometry);
        f.response = Future.value(_quota(0));
        f.reload();
        expect(
          await f.container.read(aiCoachCreditAccessProvider.future),
          isFalse,
        );
        await tester.pump();
        expect(find.byKey(_label), findsNothing);
        expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(4));
        expect(tester.getRect(find.byKey(_tab)), geometry);
        f.response = Future.error(StateError('later offline state'));
        f.response.ignore();
        f.reload();
        await expectLater(
          f.container.read(aiCoachCreditAccessProvider.future),
          throwsStateError,
        );
        await tester.pump();
        expect(find.byKey(_label), findsNothing);
        expect(find.text('964 / 2103'), findsNothing);
      } finally {
        if (!pending.isCompleted) pending.complete(_quota(0));
        await f.close(tester);
      }
    },
  );

  for (final logout in [false, true]) {
    testWidgets(
      'old positive quota cannot cross ${logout ? "logout" : "rapid A B A"} or a late completion',
      (tester) async {
        final f = _Fixture();
        final old = Completer<Object?>();
        final fresh = Completer<Object?>();
        try {
          await f.mount(tester);
          f.response = old.future;
          f.reload();
          await tester.pump();
          f.container.read(aiCoachCreditAccessProvider.future).ignore();
          f.response = fresh.future;
          f.owners.add(logout ? null : 'owner-b');
          if (!logout) f.owners.add('owner-a');
          await tester.pump();
          await tester.pump();
          expect(find.byKey(_label), findsNothing);
          expect(find.text('964 / 2103'), findsNothing);
          old.complete(_quota(9999));
          await tester.pump();
          expect(find.byKey(_label), findsNothing);
          if (!logout) {
            fresh.complete(_quota(0));
            await f.container.read(aiCoachCreditAccessProvider.future);
            await tester.pump();
            expect(find.byKey(_label), findsNothing);
          }
        } finally {
          if (!old.isCompleted) old.complete(_quota(0));
          if (!fresh.isCompleted) fresh.complete(_quota(0));
          await f.close(tester);
        }
      },
    );
  }

  testWidgets(
    'same-owner periodic credit reload preserves Boost label, all nutrients and tab geometry',
    (tester) async {
      Future<Object?> response = Future.value(_quota(2500));
      var loads = 0;
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value('owner-a'),
          ),
          coachOverviewPaidLabelProvider.overrideWith((_) => null),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(() {
            loads++;
            return response;
          }),
        ],
      );
      addTearDown(container.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: CoachReferenceWorkspace(
              snapshot: _snapshot,
              now: _now,
              onChat: () {},
              onRoute: (_) {},
              onQuickAdd: () {},
              onPhoto: () {},
              onVoice: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Verified AI Boost access'), findsOneWidget);
      final geometry = tester.getRect(find.byKey(_tab));
      final pending = Completer<Object?>();
      response = pending.future;
      final beforeLoads = loads;
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(loads, beforeLoads + 1);
      expect(container.read(aiCoachCreditAccessProvider).isLoading, isTrue);
      expect(find.byKey(_label), findsOneWidget);
      expect(tester.getRect(find.byKey(_tab)), geometry);
      for (final value in [
        '964 / 2103',
        '50 / 114 g',
        '192 / 254 g',
        '4.2 / 70 g',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      pending.complete(_quota(2500));
      await container.read(aiCoachCreditAccessProvider.future);
      await tester.pump();
      expect(tester.getRect(find.byKey(_tab)), geometry);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'fresh positive credit is accepted after an in-flight rapid A B A',
    (tester) async {
      final f = _Fixture();
      final old = Completer<Object?>();
      final fresh = Completer<Object?>();
      try {
        await f.mount(tester);
        f.response = old.future;
        f.reload();
        await tester.pump();
        f.container.read(aiCoachCreditAccessProvider.future).ignore();
        f.response = fresh.future;
        f.owners.add('owner-b');
        f.owners.add('owner-a');
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_label), findsNothing);
        old.complete(_quota(9999));
        await tester.pump();
        expect(find.byKey(_label), findsNothing);
        fresh.complete(_quota(2500));
        await f.container.read(aiCoachCreditAccessProvider.future);
        await tester.pump();
        expect(find.text('Verified AI Boost access'), findsOneWidget);
        expect(find.text('964 / 2103'), findsOneWidget);
      } finally {
        if (!old.isCompleted) old.complete(_quota(0));
        if (!fresh.isCompleted) fresh.complete(_quota(0));
        await f.close(tester);
      }
    },
  );
}
