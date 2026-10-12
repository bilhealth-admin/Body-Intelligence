import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_first_use_experience.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/first_meal_celebration.dart';
import 'package:body_intelligence_log/features/daily_log/food_log_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../../visual_closure/visual_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';

GoRouter journeyRouter({VoidCallback? onHomeTap, bool actualHome = false}) =>
    GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              ResponsiveAppShell(currentUri: state.uri, child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => actualHome
                  ? const DashboardPage()
                  : Scaffold(
                      body: SingleChildScrollView(
                        child: DashboardFirstUseExperience(
                          ownerScope: 'reference-test',
                          ownerReady: true,
                          child: SizedBox(
                            height: 480,
                            child: Center(
                              child: TextButton(
                                key: const Key('test-home-control'),
                                onPressed: onHomeTap ?? () {},
                                child: const Text('TEST • Home stays usable'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            GoRoute(
              path: '/daily-log',
              builder: (_, state) =>
                  state.uri.queryParameters['foodLog'] == '1' ||
                      state.uri.queryParameters['guide'] == '1'
                  ? FoodLogPage(
                      startGuide: state.uri.queryParameters['guide'] == '1',
                    )
                  : const DailyLogPage(),
            ),
          ],
        ),
      ],
    );

Widget journeyApp(
  AppDatabase database,
  GoRouter router,
  String language, {
  double scale = 1,
  bool reduced = false,
  ThemeData? referenceTheme,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    seedCatalogProvider.overrideWith((ref) async {}),
    foodRuntimeSearchAuthorityProvider.overrideWithValue(
      FoodRuntimeSearchAuthority(
        FoodRepository(database),
        catalogResolver: () async => null,
      ),
    ),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    debugShowCheckedModeBanner: false,
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: visualEvidenceTheme(
      referenceTheme ?? BilFlagshipTheme.light(isArabic: language == 'ar'),
      fontFamily: language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence',
    ),
    builder: (context, child) => RepaintBoundary(
      key: const Key('first-use-capture'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: visualEvidenceTextSurface(
          child,
          fontFamily: language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence',
        ),
      ),
    ),
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['BIL_CAPTURE_FIRST_USE'] != '1') return;
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('first-use-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File('build/first-use-reference/flutter/$name.png');
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
  await captureClosureFrames(
    tester,
    find.byKey(const Key('first-use-capture')),
    'first-use-${Localizations.localeOf(tester.element(find.byType(Scaffold).first)).languageCode}-${MediaQuery.disableAnimationsOf(tester.element(find.byType(Scaffold).first)) ? 'reduced' : 'motion'}',
    step: name,
    frames: name.startsWith('05-') ? 12 : 8,
  );
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['ar', 'en']) {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.8, 2.0]) {
        testWidgets(
          '$language anchored guide $width px $scale text: Skip and Add stay reachable',
          (tester) async {
            final originalShadows = debugDisableShadows;
            debugDisableShadows = false;
            addTearDown(() => debugDisableShadows = originalShadows);
            WidgetController.hitTestWarningShouldBeFatal = true;
            addTearDown(
              () => WidgetController.hitTestWarningShouldBeFatal = false,
            );
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final db = AppDatabase.forTesting(
              NativeDatabase.memory(),
              localOwnerId: 'reference-test',
            );
            addTearDown(db.close);
            var homeTaps = 0;
            final router = journeyRouter(onHomeTap: () => homeTaps++);
            addTearDown(router.dispose);
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(milliseconds: 20));
              debugDisableShadows = originalShadows;
            });
            await tester.pumpWidget(
              journeyApp(db, router, language, scale: scale),
            );
            await tester.pumpAndSettle();
            final guide = find.byKey(
              const Key('dashboard-food-guide-anchored'),
            );
            final add = find.byKey(const Key('shell-quick-add'));
            expect(guide, findsOneWidget);
            final rect = tester.getRect(guide);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            expect(rect.bottom, lessThan(tester.getRect(add).top));
            expect(
              tester
                  .getRect(find.byKey(const Key('test-home-control')))
                  .center
                  .dy,
              closeTo(240, 1),
            );
            if (scale == 1) {
              await tester.tap(find.byKey(const Key('test-home-control')));
              expect(homeTaps, 1);
            }
            await capture(tester, 'anchor-$language-${width.toInt()}-$scale');
            await tester.tap(find.byKey(const Key('dashboard-guide-skip')));
            await tester.pumpAndSettle();
            expect(guide, findsNothing);
            expect(
              await PreferencesRepository(
                db,
              ).get('experience.dashboard_food_guide.v1.reference-test'),
              'dismissed',
            );
            // The original Quick Add chooser remains available after Skip.
            await tester.tap(add);
            await tester.pumpAndSettle();
            expect(
              router.routeInformationProvider.value.uri.path,
              '/dashboard',
            );
            expect(
              find.byKey(const Key('dashboard-food-guide-anchored')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 20));
            debugDisableShadows = originalShadows;
          },
        );
      }
    }

    for (final reduced in [false, true]) {
      testWidgets(
        '$language real food journey: cancel, edit 80g, commit once, celebrate, streak${reduced ? ' reduced motion' : ''}',
        (tester) async {
          final originalShadows = debugDisableShadows;
          debugDisableShadows = false;
          addTearDown(() => debugDisableShadows = originalShadows);
          WidgetController.hitTestWarningShouldBeFatal = true;
          addTearDown(
            () => WidgetController.hitTestWarningShouldBeFatal = false,
          );
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final db = AppDatabase.forTesting(
            NativeDatabase.memory(),
            localOwnerId: 'reference-test',
          );
          addTearDown(db.close);
          final preferences = PreferencesRepository(db);
          final foodId = await FoodRepository(db).addFood(
            name: 'TEST فول',
            category: 'beans',
            calories: 95,
            protein: 5.1,
            carbs: 11.9,
            fats: 3.4,
            servingSize: 100,
            servingUnit: 'g',
          );
          final router = journeyRouter();
          addTearDown(router.dispose);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 20));
            debugDisableShadows = originalShadows;
          });
          await tester.pumpWidget(
            journeyApp(db, router, language, reduced: reduced),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('shell-quick-add')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('quick-add-food-guide')), findsOneWidget);
          await capture(tester, '00-menu-$language');
          await tester.tap(find.byKey(const Key('quick-add-primary-0')));
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.queryParameters['guide'],
            '1',
          );
          expect(
            find.byKey(const Key('food-log-search-guide')),
            findsOneWidget,
          );
          await capture(tester, '01-search-$language');
          await tester.enterText(
            find.byKey(const Key('food-log-search')),
            'TEST',
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('food-log-choose-guide')),
            findsOneWidget,
          );
          await capture(tester, '02-choose-$language');
          final addFood = find.byKey(Key('food-log-add-$foodId'));
          await tester.ensureVisible(addFood);
          await tester.tap(addFood);
          await tester.pumpAndSettle();
          await capture(tester, '03-quantity-$language');
          await tester.tap(
            find.text(language == 'ar' ? 'إلغاء' : 'Cancel').last,
          );
          await tester.pumpAndSettle();
          expect(
            await preferences.get(firstMealCelebrationPreferenceKey),
            isNull,
          );
          expect(await MealRepository(db).watchAll().first, isEmpty);
          await tester.tap(addFood);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('food-log-serving-quantity-field')),
            '80',
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('food-log-save-guide')), findsOneWidget);
          await capture(tester, '04-ready-$language');
          final confirm = tester
              .widget<FilledButton>(
                find.byKey(const Key('food-log-serving-confirm')),
              )
              .onPressed!;
          confirm();
          confirm();
          // Allow the asynchronous SQLite commit without settling away the burst.
          for (
            var i = 0;
            i < 30 &&
                find
                    .byKey(const Key('dashboard-first-food-celebration'))
                    .evaluate()
                    .isEmpty;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(
            find.byKey(const Key('dashboard-first-food-celebration')),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 700));
          await capture(tester, '05-celebration-$language');
          expect(
            find.byKey(const Key('food-log-reference-page')),
            findsOneWidget,
          );
          final meals = await MealRepository(db).watchAll().first;
          expect(meals, hasLength(1));
          expect(meals.single.items, hasLength(1));
          expect(meals.single.items.single.quantity, 80);
          expect(
            await preferences.get(firstMealCelebrationPreferenceKey),
            'done',
          );
          expect(
            await FirstMealCelebration.showIfPending(
              tester.element(find.byType(FoodLogPage)),
              preferences,
            ),
            isFalse,
          );
          // The reduced-motion duration is a Timer, not an animation frame.
          // pumpAndSettle cannot advance that timer after the static burst.
          await tester.pump(const Duration(milliseconds: 2500));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('food-log-success-guide')),
            findsOneWidget,
          );
          await capture(tester, '06-success-$language');
          await tester.tap(
            find.byKey(const Key('food-log-success-guide-skip')),
          );
          await tester.pumpAndSettle();
          router.go('/dashboard');
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('dashboard-first-food-streak-guide')),
            findsNothing,
          );
          router.go('/daily-log');
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('daily-log-week-strip')), findsOneWidget);
          expect(
            find.byKey(const Key('dashboard-first-food-streak-guide')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('dashboard-food-guide-anchored')),
            findsNothing,
          );
          await capture(tester, '06-streak-$language');
          await tester.tap(
            find.byKey(const Key('dashboard-streak-guide-done')),
          );
          await tester.pumpAndSettle();
          expect(
            await preferences.get(firstMealStreakGuidePreferenceKey),
            'seen',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 20));
          debugDisableShadows = originalShadows;
        },
      );
    }
  }
  for (final language in ['ar', 'en']) {
    for (final reduced in [false, true]) {
      testWidgets(
        '$language celebration 320px 2x reduced=$reduced remains nonblocking',
        (tester) async {
          final originalShadows = debugDisableShadows;
          debugDisableShadows = false;
          addTearDown(() => debugDisableShadows = originalShadows);
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          final prefs = PreferencesRepository(db);
          await prefs.set(firstMealCelebrationPreferenceKey, 'ready');
          late BuildContext home;
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: visualEvidenceTheme(
                ThemeData(),
                fontFamily: language == 'ar'
                    ? 'NotoArabicEvidence'
                    : 'RobotoEvidence',
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: reduced,
                ),
                child: child!,
              ),
              home: Builder(
                builder: (context) {
                  home = context;
                  return Scaffold(
                    body: Center(
                      child: TextButton(
                        key: const Key('under-celebration'),
                        onPressed: () => taps++,
                        child: const Text('Still usable'),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(await FirstMealCelebration.showIfPending(home, prefs), isTrue);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          await tester.tap(find.byKey(const Key('under-celebration')));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
          expect(
            await FirstMealCelebration.showIfPending(home, prefs),
            isFalse,
          );
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();
          expect(
            find.byKey(const Key('dashboard-first-food-celebration')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          debugDisableShadows = originalShadows;
        },
      );
    }
  }
  for (final language in ['ar', 'en']) {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets(
        '$language Food Log $width px 2x text and keyboard can confirm quantity',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final db = AppDatabase.forTesting(
            NativeDatabase.memory(),
            localOwnerId: 'reference-test',
          );
          addTearDown(db.close);
          await PreferencesRepository(
            db,
          ).set('experience.dashboard_food_guide.v1.reference-test', 'started');
          final id = await FoodRepository(db).addFood(
            name: 'TEST portion',
            category: 'beans',
            calories: 95,
            protein: 5.1,
            carbs: 11.9,
            fats: 3.4,
            servingSize: 100,
            servingUnit: 'g',
          );
          final router = journeyRouter()..go('/daily-log?guide=1');
          addTearDown(router.dispose);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 20));
          });
          await tester.pumpWidget(journeyApp(db, router, language, scale: 2));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('food-log-search')),
            'TEST',
          );
          await tester.pumpAndSettle();
          final add = find.byKey(Key('food-log-add-$id'));
          await tester.scrollUntilVisible(
            add,
            160,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('food-log-reference-page')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await Scrollable.ensureVisible(tester.element(add), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(add);
          await tester.pumpAndSettle();
          final field = find.byKey(
            const Key('food-log-serving-quantity-field'),
          );
          await tester.ensureVisible(field);
          await tester.enterText(field, '80');
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('food-log-save-guide')), findsOneWidget);
          expect(tester.takeException(), isNull);
          WidgetController.hitTestWarningShouldBeFatal = true;
          await tester.tap(find.byKey(const Key('food-log-serving-confirm')));
          WidgetController.hitTestWarningShouldBeFatal = false;
          await tester.pumpAndSettle();
          final meals = await MealRepository(db).watchAll().first;
          expect(meals.single.items.single.quantity, 80);
          expect(meals.single.meal.type, 'breakfast');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 20));
        },
      );
    }
  }
}
