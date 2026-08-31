import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/wellness/presentation/workout_entry_chooser_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('exercise chooser routes each reference path explicitly', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/wellness/workouts',
      routes: [
        GoRoute(
          path: '/wellness/workouts',
          builder: (_, _) => const WorkoutEntryChooserPage(),
        ),
        GoRoute(
          path: '/wellness/workouts/routines',
          builder: (_, _) => const Scaffold(body: Text('guided-routines')),
        ),
        GoRoute(
          path: '/wellness/workouts/log',
          builder: (_, state) => Scaffold(
            body: Text('manual-${state.uri.queryParameters['category']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_LocalizedApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('Cardio'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Workout Videos & Routines'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exercise-path-cardio')));
    await tester.pumpAndSettle();
    expect(find.text('manual-Cardio'), findsOneWidget);

    router.go('/wellness/workouts');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exercise-path-strength')));
    await tester.pumpAndSettle();
    expect(find.text('manual-Strength'), findsOneWidget);

    router.go('/wellness/workouts');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exercise-path-routines')));
    await tester.pumpAndSettle();
    expect(find.text('guided-routines'), findsOneWidget);
  });

  testWidgets('manual logger honors and can change its initial category', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkoutLibraryPage(initialCategory: 'Cardio'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Brisk walk'), findsOneWidget);
    expect(find.text('Full-body strength'), findsOneWidget);
    expect(find.text('Yoga'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
    await tester.pumpAndSettle();

    expect(find.text('Brisk walk'), findsNothing);
    expect(find.text('Full-body strength'), findsNWidgets(2));
    expect(find.text('Yoga'), findsNothing);
  });

  testWidgets(
    'Strength chooser logs to the authoritative diary and survives History rebuild',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final router = GoRouter(
        initialLocation: '/wellness/workouts',
        routes: [
          GoRoute(
            path: '/wellness/workouts',
            builder: (_, _) => const WorkoutEntryChooserPage(),
          ),
          GoRoute(
            path: '/wellness/workouts/log',
            builder: (_, state) => WorkoutLibraryPage(
              initialCategory: state.uri.queryParameters['category'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      Widget app() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: _LocalizedApp(router: router),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exercise-path-strength')));
      await tester.pumpAndSettle();
      expect(find.text('Strength'), findsWidgets);

      await tester.tap(find.text('Full-body strength').last);
      await tester.pump(const Duration(milliseconds: 400));
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Log workout'),
          )
          .onPressed!();
      await tester.pump(const Duration(seconds: 1));
      final stored = await DailyLogRepository(
        database,
      ).getForDay(DateTime.now());
      expect(stored?.exerciseNotes, contains('"id":"strength"'));

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Full-body strength'), findsWidgets);
      expect(find.textContaining('20 min'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      router.go('/wellness/workouts/log?category=Strength');
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Full-body strength'), findsWidgets);
      expect(find.textContaining('20 min'), findsWidgets);
    },
  );
}

class _LocalizedApp extends StatelessWidget {
  const _LocalizedApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
  );
}
