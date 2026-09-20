import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/connected_health/steps_settings_page.dart';
import 'package:body_intelligence_log/features/history/progress_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('step history opens the progress page inside the shell', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final router = GoRouter(
      initialLocation: '/connected-health/steps',
      routes: [
        GoRoute(
          path: '/connected-health/steps',
          builder: (_, _) => const StepsSettingsPage(),
        ),
        ShellRoute(
          builder: (_, _, child) => ResponsiveAppShell(child: child),
          routes: [
            GoRoute(path: '/history', builder: (_, _) => const ProgressPage()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            PreferencesRepository(database),
          ),
          progressDailyLogsProvider.overrideWith((_) => Stream.value([])),
          weightHistoryProvider.overrideWith((_) => Stream.value([])),
          bodyMeasurementHistoryProvider.overrideWith((_) => Stream.value([])),
          measurementSystemProvider.overrideWith(
            (_) => Stream.value(MeasurementSystem.metric),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('steps-history-link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-metric-selector')), findsOneWidget);
    expect(find.byKey(const Key('glass-bottom-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
