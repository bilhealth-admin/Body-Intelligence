import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_grid.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_data_gate.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_header.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI Coach hero uses solid high-contrast copy in light theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latestWeightProvider.overrideWith((ref) => Stream.value(null)),
          measurementSystemProvider.overrideWith(
            (ref) => Stream.value(MeasurementSystem.metric),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(body: DashboardHeader()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('AI COACH');
    expect(title, findsOneWidget);
    expect(
      find.ancestor(of: title, matching: find.byType(ShaderMask)),
      findsNothing,
    );
    expect(tester.widget<Text>(title).style?.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI Coach hero stays independent from local data failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latestWeightProvider.overrideWith(
            (ref) => Stream.error(Exception('sensitive database detail')),
          ),
          measurementSystemProvider.overrideWith(
            (ref) => Stream.value(MeasurementSystem.metric),
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
          home: Scaffold(body: DashboardHeader()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining('sensitive database detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today suppresses stale insight and retries local load failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => Stream.error(StateError('private database detail')),
          ),
          weightHistoryProvider.overrideWith(
            (ref) => Stream.value(<WeightEntry>[]),
          ),
          todayMealsProvider.overrideWith(
            (ref) => Stream.value(<MealWithItems>[]),
          ),
          todayWaterProvider.overrideWith(
            (ref) => Stream.value(<WaterEntry>[]),
          ),
          allMealsProvider.overrideWith(
            (ref) => Stream.value(<MealWithItems>[]),
          ),
          allWaterProvider.overrideWith((ref) => Stream.value(<WaterEntry>[])),
          weightReminderSkippedTodayProvider.overrideWith(
            (ref) => Stream.value(false),
          ),
          todayLifeContextProvider.overrideWith(
            (ref) => Stream.value(<LifeContextEntry>[]),
          ),
          insightLifeContextProvider.overrideWith(
            (ref) => Stream.value(<LifeContextEntry>[]),
          ),
          decisionMemoriesProvider.overrideWith(
            (ref) => Stream.value(<DecisionMemory>[]),
          ),
          decisionMemoryEnabledProvider.overrideWith(
            (ref) => Stream.value(true),
          ),
          usualMealsProvider(
            'breakfast',
          ).overrideWith((ref) async => <UsualMealCandidate>[]),
          measurementSystemProvider.overrideWith(
            (ref) => Stream.value(MeasurementSystem.metric),
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
          home: Scaffold(body: DashboardGrid()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardDataGate), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.textContaining('private database detail'), findsNothing);
    expect(find.text('أفضل إجراء واحد'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Dispose Drift-backed provider streams and flush their zero-duration
    // close callbacks before the test binding verifies pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
