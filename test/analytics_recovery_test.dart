import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:body_intelligence_log/shared/widgets/actionable_error_state.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AnalyticsPage shows privacy-safe retry for local data load failures', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          measurementSystemProvider.overrideWith(
            (ref) => Stream.value(MeasurementSystem.metric),
          ),
          weightHistoryProvider.overrideWith(
            (ref) => Stream.error(Exception('private analytics weight detail')),
          ),
          allMealsProvider.overrideWith(
            (ref) => Stream.error(Exception('private analytics meals detail')),
          ),
          allWaterProvider.overrideWith(
            (ref) => Stream.error(Exception('private analytics water detail')),
          ),
          insightLifeContextProvider.overrideWith(
            (ref) =>
                Stream.error(Exception('private analytics context detail')),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AnalyticsPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('private analytics'), findsNothing);
    expect(find.byType(ActionableErrorState), findsOneWidget);
    expect(find.text('حاول مرة أخرى'), findsOneWidget);

    await tester.ensureVisible(find.text('حاول مرة أخرى'));
    await tester.tap(find.text('حاول مرة أخرى'), warnIfMissed: false);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
