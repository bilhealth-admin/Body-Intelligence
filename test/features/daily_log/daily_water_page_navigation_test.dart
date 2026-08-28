import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/daily_log/daily_water_page.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_input_sections.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('water shortcut opens focused page and persists a quick amount', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = WaterRepository(database);
    final selectedDate = DateTime(2026, 8, 21);
    final router = GoRouter(
      initialLocation: '/daily-log',
      routes: [
        GoRoute(
          path: '/daily-log',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => DailyWaterShortcut(
                entries: ref.watch(dailyWaterProvider),
                onTap: () => context.go('/daily-log/water?from=/daily-log'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/daily-log/water',
          builder: (_, state) =>
              DailyWaterPage(returnPath: state.uri.queryParameters['from']),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          waterRepositoryProvider.overrideWithValue(repository),
          selectedLogDateProvider.overrideWith((ref) => selectedDate),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-log-water-shortcut')), findsOneWidget);
    expect(find.byKey(const Key('daily-log-water-section')), findsNothing);

    await tester.tap(find.byKey(const Key('daily-log-water-shortcut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-water-page')), findsOneWidget);
    expect(find.byKey(const Key('daily-log-water-section')), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '+250 ml'));
    await tester.pumpAndSettle();
    expect(await repository.totalForDay(selectedDate), 250);
    expect(find.text('Water total: 250 ml'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-log-water-shortcut')), findsOneWidget);
    expect(find.text('Today: 250 ml'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.idle();
    router.dispose();
    await database.close();
    await tester.pump();
  });
}
