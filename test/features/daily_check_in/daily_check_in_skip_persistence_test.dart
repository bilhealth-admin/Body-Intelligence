import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('close persists Not now for the current local calendar day', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = PreferencesRepository(database);
    final router = GoRouter(
      initialLocation: '/daily-check-in',
      routes: [
        GoRoute(
          path: '/daily-check-in',
          builder: (_, _) => const DailyCheckInPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('dashboard')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(preferences),
          todayWeightProvider.overrideWith((ref) => Stream.value(null)),
          latestWeightProvider.overrideWith((ref) => Stream.value(null)),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          measurementSystemProvider.overrideWith(
            (ref) => Stream.value(MeasurementSystem.metric),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
    expect(
      await preferences.get('weightReminderSkippedDay'),
      dayKeyFor(DateTime.now()),
    );
  });
}
