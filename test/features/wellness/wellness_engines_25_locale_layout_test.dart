import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/presentation/exercise_calorie_settings_page.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_copy.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sleep and fasting engine copy is complete beyond the core locales', () {
    expect(wellnessEngineExtendedCopyIsComplete, isTrue);
    const phrases = <String>[
      'N/A',
      'Reminder',
      "Find out what's keeping you awake",
      'Choose a standard or custom intermittent fasting window',
      'Notification permission is not active',
    ];
    const corePatchPhrases = <String>[
      'Goal',
      'Time',
      'The local timer survives app restarts',
      'Review completed intermittent fasting sessions here',
      'A local intermittent fasting timer. You remain in control.',
      'No active fast',
      'Target',
      'Custom',
      'Notify me at my target',
    ];
    for (final language in const ['fr', 'es', 'tr']) {
      for (final phrase in [...phrases, ...corePatchPhrases]) {
        final translated = wellnessEngineExtendedCopyForTesting(
          phrase,
          language,
        );
        expect(translated?.trim(), isNotEmpty, reason: '$language: $phrase');
        expect(
          translated,
          isNot(phrase),
          reason: '$language fallback: $phrase',
        );
      }
    }
    for (final locale in AppLocalizations.supportedLocales.where(
      (locale) => !WellnessCopyCatalog.supportedLanguageCodes.contains(
        locale.languageCode,
      ),
    )) {
      for (final phrase in phrases) {
        final translated = wellnessEngineExtendedCopyForTesting(
          phrase,
          locale.toLanguageTag(),
        );
        expect(
          translated?.trim(),
          isNotEmpty,
          reason: '${locale.toLanguageTag()}: $phrase',
        );
        expect(
          translated,
          isNot(phrase),
          reason: '${locale.toLanguageTag()} fell back: $phrase',
        );
      }
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      '${locale.toLanguageTag()} keeps exercise, sleep and fasting usable at 160%',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues(const {});
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        Future<void> pump(Widget page) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(database),
                exerciseCaloriePreferencesProvider.overrideWithValue(
                  const AsyncData(ExerciseCaloriePreferences()),
                ),
                todayAuthoritativeExerciseEnergyProvider.overrideWithValue(
                  const AsyncData(null),
                ),
              ],
              child: MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.6)),
                  child: child ?? const SizedBox.shrink(),
                ),
                home: page,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
        }

        await pump(const ExerciseCalorieSettingsPage());
        await tester.scrollUntilVisible(
          find.byKey(
            const Key('exercise-energy-evidence-state'),
            skipOffstage: false,
          ),
          240,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        expect(
          find.byKey(const Key('exercise-energy-evidence-state')),
          findsOneWidget,
        );

        await pump(const SleepTrackerPage());
        expect(find.byKey(const Key('sleep-log-tab')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('sleep-schedule-card')),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        await pump(const FastingTimerPage());
        expect(find.byType(FastingTimerPage), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
