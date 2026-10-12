import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrient_daily_references.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_snapshot_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/closure_surface_capture.dart';
import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  late AppDatabase db;
  late PreferencesRepository repository;
  var closed = false;
  setUp(() async {
    closed = false;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PreferencesRepository(db);
    await repository.get('goal.calories');
  });
  tearDown(() async {
    if (!closed) await db.close();
  });
  for (final language in ['ar', 'en']) {
    for (final state in ['default', 'custom', 'legacy', 'grams']) {
      for (final narrow
          in (state == 'default' || state == 'grams' || state == 'custom')
              ? [false, true]
              : [false]) {
        testWidgets(
          'actual goal provenance $language $state with source and real editor taps${narrow ? ' narrow 320 2x' : ''}',
          (tester) async {
            final values = state == 'custom'
                ? {
                    'goal.fiber': '979',
                    'goal.sugar': '765',
                    'goal.transFat': '89',
                    'goal.saturatedFat': '54',
                    'goal.cholesterol': '799',
                  }
                : state == 'legacy'
                ? {
                    'goal.vitaminA': '10',
                    'goal.vitaminC': '10',
                    'goal.calcium': '10',
                    'goal.iron': '10',
                    'goal.calories': 'NaN',
                  }
                : <String, String>{};
            debugPrint('goal fixture phase: seed committed');
            await tester.runAsync(() => repository.setMany(values));
            final container = ProviderContainer(
              overrides: [
                databaseProvider.overrideWithValue(db),
                preferencesRepositoryProvider.overrideWithValue(repository),
                nutritionGoalDefaultsProvider.overrideWithValue({
                  ...NutrientDailyReferences.values,
                  ...const {
                    'goal.calories': 1000.0,
                    'goal.carbsPercent': 45.0,
                    'goal.proteinPercent': 20.0,
                    'goal.fatPercent': 35.0,
                  },
                }),
              ],
            );
            final calorieSubscription = container.listen(
              dashboardNutrientGoalProvider('goal.calories'),
              (_, _) {},
            );
            tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  locale: Locale(language),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  theme: visualEvidenceTheme(
                    BilFlagshipTheme.light(isArabic: language == 'ar'),
                    fontFamily: language == 'ar'
                        ? 'NotoArabicEvidence'
                        : 'RobotoEvidence',
                  ),
                  builder: (context, child) => RepaintBoundary(
                    key: const Key('goal-current-capture'),
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
                      child: child!,
                    ),
                  ),
                  home: const ReferenceNutritionGoalsPage(),
                ),
              ),
            );
            debugPrint('goal fixture phase: UI pumped');
            await settle(tester);
            await waitFor(
              tester,
              () async =>
                  container.read(nutritionGoalSnapshotProvider).hasValue,
            );
            expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
            expect(
              find.text(language == 'ar' ? 'تحتاج مراجعة' : 'Review needed'),
              findsNothing,
            );
            expect(
              find.text(
                language == 'ar'
                    ? 'مرجع عام للملصق'
                    : 'General label reference',
              ),
              findsNothing,
            );
            expect(
              find.textContaining(
                language == 'ar' ? 'ثبّت هدفك' : 'Lock your target',
              ),
              findsNothing,
            );
            debugPrint('goal fixture phase: snapshot ready');
            final snapshot = container
                .read(nutritionGoalSnapshotProvider)
                .value!;
            final read = container
                .read(dashboardNutrientGoalProvider('goal.calories'))
                .value;
            expect(read, snapshot.goals['goal.calories']!.value);
            expect(
              container.read(defaultNutritionGoalTargetProvider)?.calories,
              read,
            );
            expect(
              container
                  .read(dashboardPercentageNutritionGoalsProvider)
                  ?.calories,
              read,
            );
            if (state == 'legacy') {
              expect(read, isNull);
              expect(
                await tester.runAsync<String?>(
                  () => repository.get('goal.calories'),
                ),
                'NaN',
              );
              expect(
                await tester.runAsync<String?>(
                  () => repository.get('goal.vitaminA'),
                ),
                '10',
              );
            }
            if (state == 'custom') {
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('nutrition-goal-goal.fiber')),
                350,
                scrollable: find.byType(Scrollable).first,
              );
              await settle(tester);
              expect(find.text('979 g'), findsNothing);
              expect(
                find.text(language == 'ar' ? 'تحتاج مراجعة' : 'Review needed'),
                findsNothing,
              );
              expect(snapshot.goals['goal.fiber']!.value, isNull);
              expect(
                await tester.runAsync<String?>(
                  () => repository.get('goal.fiber'),
                ),
                '979',
              );
              expect(snapshot.goals['goal.fiber']!.source, 'reviewRequired');
              if (narrow) {
                tester.view.viewInsets = const FakeViewPadding(bottom: 240);
              }
              await tester.tap(
                find.byKey(const ValueKey('nutrition-goal-goal.fiber')),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(const Key('nutrition-goal-editor-notice')),
                findsOneWidget,
              );
              expect(
                tester
                    .widget<TextField>(find.byType(TextField))
                    .controller!
                    .text,
                '979',
              );
              await captureClosureSurface(
                tester,
                find.byKey(const Key('goal-current-capture')),
                'goals-provenance-$language-custom-editor',
              );
              await tester.tap(
                find.byKey(const Key('nutrition-goal-editor-book')),
              );
              await tester.pumpAndSettle();
              expect(find.textContaining('FDA Daily Value:'), findsOneWidget);
              expect(find.textContaining('القيمة الأصلية'), findsNothing);
              expect(find.textContaining('الأصل محفوظ'), findsNothing);
              expect(find.textContaining('original preserved'), findsNothing);
              expect(find.textContaining('Original value'), findsNothing);
              await captureClosureSurface(
                tester,
                find.byKey(const Key('goal-current-capture')),
                'goals-provenance-$language-fiber-book',
              );
              await tester.tap(
                find.widgetWithText(
                  TextButton,
                  language == 'ar' ? 'إغلاق' : 'Close',
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.widgetWithText(
                  TextButton,
                  language == 'ar' ? 'إلغاء' : 'Cancel',
                ),
              );
              await settle(tester);
              if (narrow) tester.view.resetViewInsets();
              expect(
                find.byKey(const Key('nutrition-goal-editor-notice')),
                findsNothing,
              );
              expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
            }
            if (state == 'grams') {
              final row = find.byKey(
                const ValueKey('nutrition-goal-goal.proteinGrams'),
              );
              debugPrint('goal fixture phase: scroll to grams');
              await tester.scrollUntilVisible(
                row,
                250,
                scrollable: find.byType(Scrollable).first,
              );
              await settle(tester);
              debugPrint('goal fixture phase: editor tap');
              await tester.tap(row);
              await tester.pumpAndSettle();
              debugPrint('goal fixture phase: entry');
              await tester.enterText(
                find.byType(TextField),
                language == 'ar' ? '٦٠' : '60',
              );
              await tester.tap(
                find.widgetWithText(
                  FilledButton,
                  language == 'ar' ? 'حفظ' : 'Save',
                ),
              );
              debugPrint('goal fixture phase: save waiting');
              await waitFor(
                tester,
                () => repository
                    .get('goal.proteinGrams')
                    .then((v) => v == '60.0'),
              );
              expect(
                await tester.runAsync(
                  () => repository.get('goal.proteinPercent'),
                ),
                '24.0',
              );
              expect(
                await tester.runAsync<String?>(
                  () => repository.get('goal.carbsPercent'),
                ),
                '45.0',
              );
              expect(
                double.parse(
                  (await tester.runAsync<String?>(
                    () => repository.get('goal.fatGrams'),
                  ))!,
                ),
                closeTo(1000 * .31 / 9, 1e-10),
              );
              await settle(tester);
              await tester.tap(row);
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<TextField>(find.byType(TextField))
                    .controller!
                    .text,
                '60.0',
              );
            }
            debugPrint('goal fixture phase: capture');
            await captureClosureSurface(
              tester,
              find.byKey(const Key('goal-current-capture')),
              'goals-provenance-$language-$state${narrow ? '-320-2x' : ''}',
            );
            if (state != 'grams') {
              final book = find.byKey(const Key('nutrition-goals-source-book'));
              await tester.ensureVisible(book);
              await settle(tester);
              await tester.tap(book);
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsOneWidget);
              expect(
                find.textContaining(language == 'ar' ? 'الماكروز' : 'Macros:'),
                findsWidgets,
              );
              await captureClosureSurface(
                tester,
                find.byKey(const Key('goal-current-capture')),
                'goals-provenance-$language-$state-book${narrow ? '-320-2x' : ''}',
              );
              if (state == 'custom') {
                await tester.tap(
                  find.byKey(const Key('restore-all-nutrition-goals')),
                );
                await tester.pump(const Duration(milliseconds: 400));
                expect(
                  find.byKey(const Key('confirm-all-goal-restore')),
                  findsOneWidget,
                );
                await tester.tap(
                  find.byKey(const Key('confirm-all-goal-restore')),
                );
                await waitFor(
                  tester,
                  () => repository
                      .get('goal.fiber')
                      .then((value) => value == null),
                );
                await settle(tester);
                final restored = container.read(
                  nutritionGoalCurrentSnapshotProvider,
                )!;
                expect(restored.goals['goal.fiber']!.value, 28);
                expect(restored.goals['goal.sugar']!.value, isNull);
                final savedBackups = await tester.runAsync(
                  () async => (await db.select(db.preferences).get())
                      .where((row) => row.key.startsWith('goal.backup.v1.'))
                      .map((row) => row.value)
                      .toList(),
                );
                expect(savedBackups!.single, contains('979'));
                expect(savedBackups.single, contains('765'));
                await tester.tap(
                  find.widgetWithText(
                    TextButton,
                    language == 'ar' ? 'إغلاق' : 'Close',
                  ),
                );
                await tester.pumpAndSettle();
                await captureClosureSurface(
                  tester,
                  find.byKey(const Key('goal-current-capture')),
                  'goals-provenance-$language-restored-reference',
                );
              }
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 400));
            calorieSubscription.close();
            debugPrint('goal fixture phase: finished');
            container.dispose();
            var closeFinished = false;
            final closing = db.close().whenComplete(() => closeFinished = true);
            await waitFor(tester, () async => closeFinished);
            await closing;
            closed = true;
            await tester.pump();
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 4)),
            );
          },
        );
      }
    }
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 4)),
    );
  }
}

Future<void> waitFor(WidgetTester tester, Future<bool> Function() check) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (await tester.runAsync(check) == true) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('SQLite goal update did not reach the UI.');
}
