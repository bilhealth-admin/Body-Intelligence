import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/daily_water_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final water in [false, true]) {
        testWidgets(
          'real ${water ? 'water' : 'focused meal'} canvas and header contrast $language dark=$dark',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final database = AppDatabase.forTesting(NativeDatabase.memory());
            final repaint = GlobalKey();
            final theme = visualEvidenceTheme(
              dark
                  ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                  : BilFlagshipTheme.light(isArabic: language == 'ar'),
              fontFamily: language == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            );
            final page = water
                ? const DailyWaterPage(returnPath: '/origin')
                : const DailyLogPage(
                    initialMealType: 'breakfast',
                    focusMealEntry: true,
                    returnPath: '/origin',
                  );
            final router = GoRouter(
              initialLocation: '/entry',
              routes: [
                GoRoute(path: '/entry', builder: (_, _) => page),
                GoRoute(
                  path: '/origin',
                  builder: (_, _) =>
                      const Scaffold(body: Text('original page')),
                ),
              ],
            );
            try {
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    databaseProvider.overrideWithValue(database),
                    seedCatalogProvider.overrideWith((ref) async {}),
                    foodsProvider.overrideWithValue(const AsyncData([])),
                    userProfileProvider.overrideWithValue(
                      const AsyncData(null),
                    ),
                    verifiedSubscriptionAccessProvider.overrideWithValue(
                      AsyncData(FreePlan.createState()),
                    ),
                    verifiedSubscriptionStateProvider.overrideWithValue(
                      AsyncData(FreePlan.createState()),
                    ),
                    selectedLogDateProvider.overrideWith(
                      (ref) => DateTime(2026, 11, 8),
                    ),
                    dailyMealsProvider.overrideWith((ref) => Stream.value([])),
                    dailyWaterProvider.overrideWithValue(const AsyncData([])),
                    selectedDailyLogProvider.overrideWithValue(
                      const AsyncData(null),
                    ),
                    diaryMealNamesProvider.overrideWithValue(
                      const AsyncData([null, null, null, null]),
                    ),
                    nutritionGoalScheduleProvider.overrideWithValue(
                      const AsyncData(NutritionGoalSchedule()),
                    ),
                  ],
                  child: MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    theme: theme,
                    locale: Locale(language),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      ...GlobalMaterialLocalizations.delegates,
                    ],
                    builder: (context, child) =>
                        RepaintBoundary(key: repaint, child: child),
                    routerConfig: router,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final canvas = tester
                  .widget<Scaffold>(find.byType(Scaffold).first)
                  .backgroundColor!;
              if (dark) {
                expect(canvas, theme.colorScheme.surfaceContainerLowest);
              } else {
                expect(canvas, const Color(0xFFF5F5F8));
              }
              final titleFinder = water
                  ? find.descendant(
                      of: find.byType(AppBar),
                      matching: find.byType(Text),
                    )
                  : find.byKey(const Key('daily-meal-detail-title'));
              expect(titleFinder, findsOneWidget);
              final paragraph = tester.renderObject<RenderParagraph>(
                titleFinder,
              );
              final ink = paragraph.text.style!.color!;
              final high = ink.computeLuminance() > canvas.computeLuminance()
                  ? ink
                  : canvas;
              final low = high == ink ? canvas : ink;
              expect(
                (high.computeLuminance() + .05) /
                    (low.computeLuminance() + .05),
                greaterThanOrEqualTo(4.5),
              );
              if (water) {
                expect(
                  tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
                  canvas,
                );
              } else {
                final overlay = tester
                    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                      find
                          .descendant(
                            of: find.byType(DailyLogPage),
                            matching: find.byType(
                              AnnotatedRegion<SystemUiOverlayStyle>,
                            ),
                          )
                          .first,
                    )
                    .value;
                expect(
                  overlay.statusBarIconBrightness,
                  dark ? Brightness.light : Brightness.dark,
                );
              }
              final captureDir =
                  Platform.environment['BIL_ENTRY_THEME_CAPTURE_DIR'];
              if (captureDir != null && captureDir.isNotEmpty) {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(repaint),
                );
                await tester.runAsync(() async {
                  final image = await boundary.toImage();
                  final png = (await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  ))!;
                  image.dispose();
                  final directory = Directory(captureDir);
                  await directory.create(recursive: true);
                  await File(
                    '${directory.path}/${water ? 'water' : 'meal'}-$language-${dark ? 'dark' : 'light'}.png',
                  ).writeAsBytes(png.buffer.asUint8List());
                });
              }
              await tester.tap(find.byType(BackButton).first);
              await tester.pumpAndSettle();
              expect(find.text('original page'), findsOneWidget);
            } finally {
              // Dispose providers while the test body still owns the fake
              // clock. Drift retires query streams through Timer.run, before
              // the framework's automatic unmount/invariant verification.
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(Duration.zero);
              await tester.idle();
              router.dispose();
              await tester.runAsync(database.close);
              await tester.pump(Duration.zero);
              await tester.idle();
            }
          },
        );
      }
    }
  }
}
