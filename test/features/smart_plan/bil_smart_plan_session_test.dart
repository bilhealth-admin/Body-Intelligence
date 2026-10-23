import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_page.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../../visual_closure/visual_evidence_font.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_localizer.dart';
import 'smart_plan_contrast_review.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BilSmartPlan plan;
  late BilSmartPlan homePlan;
  late List<WellnessContentItem> items;
  late WorkoutDiscoveryLocalizer localizer;
  setUpAll(() async {
    await loadVisualEvidenceFont();
    final catalog = const BilSmartPlanCatalog();
    final workouts = await catalog.gymSessions(sessionMinutes: 35);
    final now = DateTime(2026, 10, 23);
    plan = const BilSmartPlanEngine()
        .generate(
          BilPlanCreationRequest(
            ownerId: 'session-owner',
            planId: 'session-plan',
            startOn: now,
            horizon: BilPlanHorizon.week,
            focus: BilPlanFocus.training,
            workoutsPerWeek: 3,
            confirmedPreferences: true,
            adultConfirmed: true,
            workoutCatalog: workouts,
            recipeCatalog: const [],
          ),
          now,
        )
        .withStatus(BilPlanStatus.active, now);
    final homeSetup = BilPlanSetup(
      environment: BilPlanEnvironment.home,
      experience: BilPlanExperience.beginner,
      sessionMinutes: 25,
      equipment: const {'none'},
    );
    homePlan = const BilSmartPlanEngine()
        .generate(
          BilPlanCreationRequest(
            ownerId: 'session-owner',
            planId: 'home-session-plan',
            startOn: now,
            horizon: BilPlanHorizon.week,
            focus: BilPlanFocus.training,
            workoutsPerWeek: 3,
            confirmedPreferences: true,
            adultConfirmed: true,
            workoutCatalog: await catalog.homeSessions(homeSetup),
            recipeCatalog: const [],
            setup: homeSetup,
          ),
          now,
        )
        .withStatus(BilPlanStatus.active, now);
    items = const WorkoutDiscoveryCatalogRepository().parse(
      await rootBundle.loadString(WorkoutDiscoveryCatalogRepository.assetPath),
      await const WorkoutReleaseCatalogRepository().load(),
    );
    localizer = WorkoutDiscoveryLocalizer.fromDiscovery(items);
  });
  Future<void> pump(
    WidgetTester tester, {
    String locale = 'en',
    bool dark = false,
    double width = 390,
    double scale = 1,
    bool allowed = true,
    List<WellnessContentItem>? source,
    bool showWarmup = false,
    BilSmartPlan? selectedPlan,
    List<String>? openedMovements,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('session-owner'),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: visualEvidenceTheme(
            dark
                ? BilFlagshipTheme.dark(isArabic: locale == 'ar')
                : BilFlagshipTheme.light(isArabic: locale == 'ar'),
            fontFamily: locale == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: visualEvidenceTextSurface(
              child,
              fontFamily: locale == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            ),
          ),
          home: RepaintBoundary(
            key: const ValueKey('bil-smart-plan-session-capture'),
            child: BilSmartPlanSessionPage(
              plan: selectedPlan ?? plan,
              day: (selectedPlan ?? plan).days.first,
              checkAccess: () {
                if (!allowed) throw StateError('changed');
              },
              loadItems: (_) => Future.value(
                source ??
                    (locale == 'ar'
                        ? items
                              .map((item) => localizer.localize(item, 'ar'))
                              .toList(growable: false)
                        : items),
              ),
              openExercise: (id) async {
                openedMovements?.add(id);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (!showWarmup &&
        find
            .byKey(const ValueKey('bil-smart-plan-warmup-continue'))
            .evaluate()
            .isNotEmpty) {
      final proceed = find.byKey(
        const ValueKey('bil-smart-plan-warmup-continue'),
      );
      await tester.ensureVisible(proceed);
      await tester.pumpAndSettle();
      await tester.tap(proceed);
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'warm-up is a separate preparation route; exact video action and reviewed transition never log completion',
    (tester) async {
      final opened = <String>[];
      await pump(
        tester,
        showWarmup: true,
        selectedPlan: homePlan,
        openedMovements: opened,
      );
      expect(
        find.byKey(const ValueKey('bil-smart-plan-warmup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bil-smart-plan-session-step-done')),
        findsNothing,
      );
      final view = find
          .widgetWithText(OutlinedButton, 'View verified movement')
          .first;
      await tester.ensureVisible(view);
      await tester.pumpAndSettle();
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(opened, ['cardio-low-impact-march-in-place-steady']);
      final next = find.byKey(const ValueKey('bil-smart-plan-warmup-continue'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bil-smart-plan-warmup')), findsNothing);
      expect(find.text('Sets: 2'), findsOneWidget);
      expect(find.textContaining('8-12'), findsOneWidget);
      expect(find.text('Rest seconds: 120'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('bil-smart-plan-session-exercise')),
            )
            .dy,
        greaterThan(0),
      );
      expect(homePlan.days.first.workout!.completed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing warm-up media blocks the whole session without silently replacing the source',
    (tester) async {
      await pump(
        tester,
        showWarmup: true,
        selectedPlan: homePlan,
        source: items
            .where(
              (item) => item.id != 'cardio-low-impact-march-in-place-steady',
            )
            .toList(),
      );
      expect(find.textContaining('could not be opened'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bil-smart-plan-warmup-continue')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('bil-smart-plan-session-step-done')),
        findsNothing,
      );
    },
  );

  for (final locale in ['ar', 'en']) {
    for (final dark in [false, true]) {
      for (final warmup in [true, false]) {
        testWidgets(
          'Home ${warmup ? 'warmup' : 'exercise'} $locale ${dark ? 'dark' : 'light'} visual and semantic evidence',
          (tester) async {
            await pump(
              tester,
              locale: locale,
              dark: dark,
              selectedPlan: homePlan,
              showWarmup: warmup,
            );
            final name =
                'smart_plan_home_${warmup ? 'warmup' : 'exercise'}_${locale}_${dark ? 'dark' : 'light'}';
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('bil-smart-plan-session-capture')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final out = File('build/coach-ci-compat/visuals/$name.png');
                await out.parent.create(recursive: true);
                await out.writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
            final semantics = tester.ensureSemantics();
            try {
              expect(
                await smartPlanTextContrastFailures(
                  tester,
                  find.byKey(const ValueKey('bil-smart-plan-session-capture')),
                ),
                isEmpty,
              );
              await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            } finally {
              semantics.dispose();
            }
            expect(tester.takeException(), isNull);
            if (Platform.environment['BIL_CAPTURE_SMART_PLAN_GOLDENS'] != '0') {
              await expectLater(
                find.byKey(const ValueKey('bil-smart-plan-session-capture')),
                matchesGoldenFile('goldens/$name.png'),
              );
            }
          },
        );
      }
      testWidgets(
        'Home warm-up $locale ${dark ? 'dark' : 'light'} 320px at 200% remains scrollable through its real action',
        (tester) async {
          await pump(
            tester,
            locale: locale,
            dark: dark,
            selectedPlan: homePlan,
            showWarmup: true,
            width: 320,
            scale: 2,
          );
          final next = find.byKey(
            const ValueKey('bil-smart-plan-warmup-continue'),
          );
          await tester.ensureVisible(next);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('bil-smart-plan-session-exercise')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Start opens the exact ordered saved session; finish waits for every step and writes nothing',
    (tester) async {
      await pump(tester);
      final ids = plan.days.first.workout!.exerciseIds;
      for (var i = 0; i < ids.length; i++) {
        final title = items
            .singleWhere(
              (item) =>
                  item.id == ids[i] && item.releaseBundleId == 'gym-six-month',
            )
            .title;
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('bil-smart-plan-session-exercise')),
              )
              .data,
          title,
        );
        expect(find.byType(BilSmartPlanPanel), findsWidgets);
        final done = find.byKey(
          const ValueKey('bil-smart-plan-session-step-done'),
        );
        await tester.ensureVisible(done);
        await tester.tap(done);
        await tester.pumpAndSettle();
        if (i + 1 < ids.length) {
          final next = find.byKey(
            const ValueKey('bil-smart-plan-session-next'),
          );
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
      }
      final finish = find.byKey(
        const ValueKey('bil-smart-plan-session-finish'),
      );
      await tester.ensureVisible(finish);
      expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);
      expect(plan.days.first.workout!.completed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'account cancellation hides a loaded session and disables completion',
    (tester) async {
      await pump(tester, allowed: false);
      expect(
        find.byKey(const ValueKey('bil-smart-plan-session-access-changed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bil-smart-plan-session-exercise')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('bil-smart-plan-session-finish')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'missing catalog movement fails closed without partial or fabricated steps',
    (tester) async {
      await pump(tester, source: const []);
      expect(find.textContaining('could not be opened'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bil-smart-plan-session-step-done')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('session visual evidence $locale ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await pump(tester, locale: locale, dark: dark);
        final semantics = tester.ensureSemantics();
        try {
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        } finally {
          semantics.dispose();
        }

        expect(tester.takeException(), isNull);
        if (Platform.environment['BIL_CAPTURE_SMART_PLAN_GOLDENS'] != '0') {
          await expectLater(
            find.byKey(const ValueKey('bil-smart-plan-session-capture')),
            matchesGoldenFile(
              'goldens/smart_plan_session_${locale}_${dark ? 'dark' : 'light'}.png',
            ),
          );
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('bil-smart-plan-session-capture')),
          );
          await tester.runAsync(() async {
            final pixels = await boundary.toImage(pixelRatio: 1);
            final png = await pixels.toByteData(format: ui.ImageByteFormat.png);
            final out = File(
              'build/release-ios38-android33/visuals/session_${locale}_${dark ? 'dark' : 'light'}.png',
            );
            await out.parent.create(recursive: true);
            await out.writeAsBytes(png!.buffer.asUint8List());
            pixels.dispose();
          });
        }
      });
      testWidgets(
        'session $locale ${dark ? 'dark' : 'light'} narrow 200% text remains accessible',
        (tester) async {
          await pump(tester, locale: locale, dark: dark, width: 320, scale: 2);
          final check = find.byKey(
            const ValueKey('bil-smart-plan-session-step-done'),
          );
          await tester.ensureVisible(check);
          await tester.pumpAndSettle();
          expect(
            Directionality.of(
              tester.element(find.byType(BilSmartPlanSessionPage)),
            ),
            locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
