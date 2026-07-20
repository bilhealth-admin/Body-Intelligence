import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'P3-E5-006 analytics loading uses premium calm semantics without spinner',
    (tester) async {
      final completer = Stream<Never>.empty();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weightHistoryProvider.overrideWith((ref) => completer),
            allMealsProvider.overrideWith((ref) => completer),
            allWaterProvider.overrideWith((ref) => completer),
            insightLifeContextProvider.overrideWith((ref) => completer),
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
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Loading analytics' &&
              widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'P3-E5-006 analytics recovery keeps privacy-safe retry context',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weightHistoryProvider.overrideWith(
              (ref) => Stream.error(StateError('private analytics detail')),
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
      await tester.pumpAndSettle();

      expect(find.textContaining('private analytics detail'), findsNothing);
      expect(find.text('تعذر تحميل بيانات التحليلات.'), findsOneWidget);
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
      await tester.tap(find.text('حاول مرة أخرى'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
