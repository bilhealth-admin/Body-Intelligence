import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_nutrition_goal_schedule.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/nutrition_goal_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = NutritionGoalTarget(
    calories: 2000,
    carbsPercent: 45,
    proteinPercent: 30,
    fatPercent: 25,
  );
  const schedule = NutritionGoalSchedule(
    dayTargets: <int, NutritionGoalTarget>{DateTime.monday: target},
    mealTargets: <String, NutritionGoalTarget>{'breakfast': target},
  );

  test('reviewed scheduled-goal catalog is complete for all 25 locales', () {
    final appTags = AppLocalizations.supportedLocales
        .map(BilLocalePolicy.canonicalTag)
        .toSet();

    expect(NutritionGoalScheduleRuntimeCopy.supported, hasLength(25));
    expect(NutritionGoalScheduleRuntimeCopy.supported, appTags);
    expect(NutritionGoalScheduleRuntimeCopy.balanced, isTrue);

    for (final tag in NutritionGoalScheduleRuntimeCopy.supported) {
      for (final source in NutritionGoalScheduleRuntimeCopy.sources) {
        expect(
          NutritionGoalScheduleRuntimeCopy.resolve(source, tag)?.trim(),
          isNotEmpty,
          reason: '$tag: $source',
        );
      }
      if (tag != 'en') {
        expect(
          NutritionGoalScheduleRuntimeCopy.resolve(
            NutritionGoalScheduleRuntimeCopy.scheduledGoals,
            tag,
          ),
          isNot(NutritionGoalScheduleRuntimeCopy.scheduledGoals),
          reason: '$tag must not fall back to the English screen title',
        );
      }
    }
  });

  test('goal summaries localize numbers without false trailing precision', () {
    final english = NutritionGoalScheduleRuntimeCopy.formatGoalSummary(
      locale: const Locale('en'),
      calories: 2000,
      carbs: 225,
      protein: 150,
      fat: 55.56,
    );
    final arabic = NutritionGoalScheduleRuntimeCopy.formatGoalSummary(
      locale: const Locale('ar'),
      calories: 2000,
      carbs: 225,
      protein: 150,
      fat: 55.56,
    );

    expect(english, contains('2,000 kcal'));
    expect(english, contains('225 g C'));
    expect(english, contains('55.6 g F'));
    expect(english, isNot(contains('225.0')));
    expect(arabic, isNot(equals(english)));
    expect(arabic, isNot(contains('225.0')));
  });

  testWidgets(
    'all 25 locales render localized data, RTL direction, and error copy',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> pump(
        Locale locale,
        AsyncValue<NutritionGoalSchedule> value,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [nutritionGoalScheduleProvider.overrideWithValue(value)],
            child: MaterialApp(
              key: ValueKey('${locale.toLanguageTag()}-$value'),
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const NutritionGoalSchedulePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final locale in AppLocalizations.supportedLocales) {
        final tag = BilLocalePolicy.canonicalTag(locale);
        await pump(locale, const AsyncData(schedule));

        expect(
          find.text(
            NutritionGoalScheduleRuntimeCopy.text(
              NutritionGoalScheduleRuntimeCopy.scheduledGoals,
              locale,
            ),
          ),
          findsOneWidget,
          reason: '$tag title',
        );
        expect(
          find.text(
            NutritionGoalScheduleRuntimeCopy.formatGoalSummary(
              locale: locale,
              calories: 2000,
              carbs: 225,
              protein: 150,
              fat: 55.56,
            ),
          ),
          findsWidgets,
          reason: '$tag gram summary',
        );
        expect(
          Directionality.of(
            tester.element(find.byType(NutritionGoalSchedulePage)),
          ),
          BilLocalePolicy.directionFor(locale),
          reason: '$tag text direction',
        );
        expect(tester.takeException(), isNull, reason: '$tag data state');

        await pump(
          locale,
          AsyncError<NutritionGoalSchedule>(
            StateError('simulated read failure'),
            StackTrace.empty,
          ),
        );
        expect(
          find.text(
            NutritionGoalScheduleRuntimeCopy.text(
              NutritionGoalScheduleRuntimeCopy.goalsUnavailable,
              locale,
            ),
          ),
          findsOneWidget,
          reason: '$tag error state',
        );
        expect(tester.takeException(), isNull, reason: '$tag error state');
      }
    },
  );
}
