import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'P3-E5-001 weight chart explains measured scope, trend sufficiency, and safe limits',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weightHistoryProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            allMealsProvider.overrideWith(
              (ref) => Stream.value(const <MealWithItems>[]),
            ),
            allWaterProvider.overrideWith(
              (ref) => Stream.value(<WaterEntry>[]),
            ),
            insightLifeContextProvider.overrideWith(
              (ref) => Stream.value(<LifeContextEntry>[]),
            ),
            measurementSystemProvider.overrideWith(
              (ref) => Stream.value(MeasurementSystem.metric),
            ),
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
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
      await tester.pumpAndSettle();

      expect(find.text('Analytics overview'), findsOneWidget);
      expect(find.textContaining('A personal comparison needs at least 7 earlier and 3 recent days'), findsOneWidget);
      expect(
        find.textContaining('No population average is substituted for your missing data.'),
        findsOneWidget,
      );
    },
  );
}
