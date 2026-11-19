import 'package:body_intelligence_log/features/exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/presentation/exercise_calorie_settings_page.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _preferences = ExerciseCaloriePreferences(
  includeInRemainingGoal: true,
  adjustMacroGoals: true,
);

GoRouter _router() => GoRouter(
  initialLocation: '/exercise-calories',
  routes: [
    GoRoute(
      path: '/exercise-calories',
      builder: (_, _) => const ExerciseCalorieSettingsPage(),
    ),
    GoRoute(
      path: '/connected-health',
      builder: (_, _) => const Scaffold(
        body: Text(
          'Existing source destination',
          key: Key('source-destination'),
        ),
      ),
    ),
  ],
);

Widget _app(
  GoRouter router, {
  AuthoritativeExerciseEnergy? energy,
  bool compactArabic = false,
}) => ProviderScope(
  overrides: [
    exerciseCaloriePreferencesProvider.overrideWithValue(
      const AsyncData(_preferences),
    ),
    todayAuthoritativeExerciseEnergyProvider.overrideWithValue(
      AsyncData(energy),
    ),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    locale: Locale(compactArabic ? 'ar' : 'en'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(compactArabic ? 2 : 1)),
      child: child!,
    ),
  ),
);

void main() {
  testWidgets(
    'missing energy offers existing source route without enabling controls',
    (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('exercise-calories-connect-health'));
      expect(action, findsOneWidget);
      for (final key in [
        'exercise-calories-include-switch',
        'exercise-calories-macros-switch',
      ]) {
        final control = tester.widget<SwitchListTile>(find.byKey(Key(key)));
        expect(control.value, isFalse);
        expect(control.onChanged, isNull);
      }
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/connected-health',
      );
      expect(find.byKey(const Key('source-destination')), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('source-destination'))),
      );
      expect(
        container.read(exerciseCaloriePreferencesProvider).asData!.value,
        same(_preferences),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'current real-evidence value preserves existing available controls',
    (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(
          router,
          energy: AuthoritativeExerciseEnergy(
            kcal: 150,
            observedAt: DateTime.now(),
            source: 'Synthetic verified test source',
            confidence: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('exercise-calories-connect-health')),
        findsNothing,
      );
      for (final key in [
        'exercise-calories-include-switch',
        'exercise-calories-macros-switch',
      ]) {
        final control = tester.widget<SwitchListTile>(find.byKey(Key(key)));
        expect(control.value, isTrue);
        expect(control.onChanged, isNotNull);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320dp Arabic at scale2 keeps source guidance reachable by scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, compactArabic: true));
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('exercise-calories-connect-health'));
      await tester.scrollUntilVisible(action, 180, scrollable: find.byType(Scrollable).first);
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/connected-health',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
