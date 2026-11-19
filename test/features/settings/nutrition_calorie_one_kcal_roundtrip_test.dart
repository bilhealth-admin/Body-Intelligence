import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/macro_goal_editor.dart';
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
import '../../visual_closure/visual_evidence_font.dart';
import 'nutrition_goal_provenance_ui_test.dart' show settle, waitFor;

void main() {
  setUpAll(loadVisualEvidenceFont);
  test(
    'actual calorie allocator preserves2184 exactly and same rounded grams do not imply unchanged kcal',
    () {
      const before = MacroGoalAllocation(2183, 52, 18, 30);
      final after = before.withCalories(2184);
      expect(after.calories, 2184);
      expect(after.toPreferences()['goal.calories'], '2184.0');
      for (final macro in MacroGoal.values) {
        expect(after.grams(macro).round(), before.grams(macro).round());
      }
    },
  );
  for (final origin in ['manual', 'suggested', 'untouched-fractional']) {
    testWidgets(
      'real calorie editor $origin enter/save/provider/reopen one-kcal boundary',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = PreferencesRepository(db);
        final defaults = <String, double>{
          ...NutrientDailyReferences.values,
          'goal.calories': 2183,
          'goal.carbsPercent': 52,
          'goal.proteinPercent': 18,
          'goal.fatPercent': 30,
        };
        await tester.runAsync(() async {
          await repository.get('goal.calories');
          if (origin != 'suggested') {
            await repository.setMany({
              ...MacroGoalAllocation(
                origin == 'untouched-fractional' ? 2183.125 : 2183,
                52,
                18,
                30,
              ).toPreferences(),
              'goal.macroEditor.v2': 'true',
            });
          }
        });
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            preferencesRepositoryProvider.overrideWithValue(repository),
            nutritionGoalDefaultsProvider.overrideWithValue(defaults),
          ],
        );
        final subscription = container.listen(
          nutritionGoalSnapshotProvider,
          (_, _) {},
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: const Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                theme: visualEvidenceTheme(
                  BilFlagshipTheme.light(),
                  fontFamily: 'RobotoEvidence',
                ),
                home: const ReferenceNutritionGoalsPage(),
              ),
            ),
          );
          await settle(tester);
          await waitFor(
            tester,
            () async =>
                container.read(nutritionGoalCurrentSnapshotProvider) != null,
          );
          final row = find.byKey(
            const ValueKey('nutrition-goal-goal.calories'),
          );
          expect(row, findsOneWidget);
          await tester.tap(row);
          await tester.pumpAndSettle();
          final field = find.byType(TextField);
          expect(field, findsOneWidget);
          expect(tester.widget<TextField>(field).controller!.text, '2183');
          if (origin != 'untouched-fractional') {
            // Actual Flutter text input pipeline, not controller assignment or
            // direct invocation of onChanged/onPressed production callbacks.
            await tester.enterText(field, '2184');
            expect(tester.widget<TextField>(field).controller!.text, '2184');
          }
          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          final expected = origin == 'untouched-fractional' ? 2183.125 : 2184.0;
          await waitFor(
            tester,
            () async =>
                double.tryParse(await repository.get('goal.calories') ?? '') ==
                expected,
          );
          await settle(tester);
          expect(find.byType(TextField), findsNothing);
          expect(
            container
                .read(nutritionGoalCurrentSnapshotProvider)!
                .goals['goal.calories']!
                .value,
            expected,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.text(expected.round().toString()),
            ),
            findsOneWidget,
          );
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            expected.round().toString(),
          );
          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await settle(tester);
          final saved = await tester.runAsync<String?>(
            () => repository.get('goal.calories'),
          );
          expect(double.parse(saved!), expected);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 400));
          subscription.close();
          container.dispose();
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 4)),
          );
          await tester.pump();
          var closed = false;
          Object? failure;
          StackTrace? failureStack;
          Future<void>.sync(db.close).then<void>(
            (_) => closed = true,
            onError: (Object e, StackTrace st) {
              failure = e;
              failureStack = st;
              closed = true;
            },
          );
          await waitFor(tester, () async => closed);
          if (failure != null) {
            Error.throwWithStackTrace(failure!, failureStack!);
          }
        }
      },
    );
  }
}
