import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_today_sections.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('selected date remains centred after navigation in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var date = DateTime(2026, 10, 11);
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, update) => DailyLogWeekStrip(
              date: date,
              onSelected: (value) => update(() => date = value),
            ),
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      final circle = find.byKey(const Key('daily-log-selected-date-circle'));
      final strip = find.byKey(const Key('daily-log-week-strip'));
      void expectNeighbours() {
        final previous = DateTime(date.year, date.month, date.day - 1);
        final next = DateTime(date.year, date.month, date.day + 1);
        final previousButton = find.byKey(
          ValueKey('daily-log-week-${previous.toIso8601String()}'),
        );
        final nextButton = find.byKey(
          ValueKey('daily-log-week-${next.toIso8601String()}'),
        );
        final centre = tester.getCenter(circle).dx;
        final columnWidth = tester.getSize(strip).width / 7;
        final logicalDirection = locale.languageCode == 'ar' ? -1 : 1;
        expect(
          tester.getCenter(previousButton).dx,
          closeTo(centre - logicalDirection * columnWidth, .1),
        );
        expect(
          tester.getCenter(nextButton).dx,
          closeTo(centre + logicalDirection * columnWidth, .1),
        );
      }

      expect(tester.getSize(circle), const Size(36, 36));
      expectNeighbours();
      expect(
        tester.getCenter(circle).dx,
        closeTo(tester.getCenter(strip).dx, 0.1),
      );
      final next = DateTime(2026, 10, 12);
      await tester.tap(
        find.byKey(ValueKey('daily-log-week-${next.toIso8601String()}')),
      );
      await tester.pumpAndSettle();
      expect(date, next);
      expect(
        tester.getCenter(circle).dx,
        closeTo(tester.getCenter(strip).dx, 0.1),
      );
      expect(
        find.descendant(of: circle, matching: find.text('12')),
        findsOneWidget,
      );
      expectNeighbours();
      final previous = DateTime(2026, 10, 11);
      await tester.tap(
        find.byKey(ValueKey('daily-log-week-${previous.toIso8601String()}')),
      );
      await tester.pumpAndSettle();
      expect(date, previous);
      expect(
        tester.getCenter(circle).dx,
        closeTo(tester.getCenter(strip).dx, .1),
      );
      expectNeighbours();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Today cards stay distinct from the light canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const DailyLogTodayBackground(
          child: DailyLogTodayCard(child: Text('Today card')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final background = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DailyLogTodayBackground),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final gradient = (background.decoration as BoxDecoration).gradient!;
    final card = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(DailyLogTodayCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(gradient.colors.last, const Color(0xFFE0ECF6));
    expect(card.color, isNot(gradient.colors.last));
    expect(tester.takeException(), isNull);
  });

  testWidgets('week strip cannot select outside the diary planning window', (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      _app(
        DailyLogWeekStrip(
          date: DateTime(2026, 9, 21),
          lastDate: DateTime(2026, 9, 21),
          onSelected: (day) => selected = day,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey('daily-log-week-${DateTime(2026, 9, 22).toIso8601String()}'),
      ),
    );
    expect(selected, isNull);
    await tester.tap(
      find.byKey(
        ValueKey('daily-log-week-${DateTime(2026, 9, 21).toIso8601String()}'),
      ),
    );
    expect(selected, DateTime(2026, 9, 21));
  });
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'Today week and habits title use ${locale.toLanguageTag()} at large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        DateTime? selected;
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => Column(
                children: [
                  Text(dailyLogHabitsTitle(context)),
                  DailyLogWeekStrip(
                    date: DateTime(2026, 9, 21),
                    onSelected: (day) => selected = day,
                  ),
                ],
              ),
            ),
            locale: locale,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(InkWell), findsNWidgets(7));
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(
            ValueKey(
              'daily-log-week-${DateTime(2026, 9, 22).toIso8601String()}',
            ),
          ),
        );
        expect(selected, DateTime(2026, 9, 22));
        if (locale.languageCode != 'en') {
          expect(find.text('Healthy habits'), findsNothing);
        }
      },
    );
  }
  for (final system in MeasurementSystem.values) {
    testWidgets(
      'historical Today weight is real, date-bounded and uses $system',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repository = WeightRepository(db);
        await repository.addWeight(87, date: DateTime(2026, 9, 18));
        await repository.addWeight(83, date: DateTime(2026, 9, 24));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              measurementSystemProvider.overrideWithValue(AsyncData(system)),
            ],
            child: _app(DailyLogWeightShortcut(date: DateTime(2026, 9, 21))),
          ),
        );
        await tester.pumpAndSettle();
        final text = tester
            .widget<Text>(find.byKey(const Key('daily-log-weight-value')))
            .data;
        expect(
          text,
          '${UnitConverter.weightFromKg(87, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
