import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/history/history_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/shared/widgets/wheel_number_field.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final confirm in [false, true]) {
    testWidgets(
      '${confirm ? 'confirm' : 'cancel'} weight deletion closes only its root dialog inside a shell',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = WeightRepository(database);
        final keptId = await repository.addWeight(
          80,
          date: DateTime(2026, 10, 30),
        );
        final testId = await repository.addWeight(
          79.1,
          date: DateTime(2026, 10, 18),
        );
        final rootKey = GlobalKey<NavigatorState>();
        final shellKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: rootKey,
          initialLocation: '/progress',
          routes: [
            ShellRoute(
              navigatorKey: shellKey,
              builder: (_, _, child) => child,
              routes: [
                GoRoute(
                  path: '/progress',
                  builder: (context, _) => Scaffold(
                    body: TextButton(
                      onPressed: () => context.push('/weight-history'),
                      child: const Text('Open weight history'),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/weight-history',
                  builder: (_, _) => const HistoryPage(),
                ),
              ],
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          router.dispose();
          await database.close();
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(database)],
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
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
        await tester.tap(find.text('Open weight history'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('2026-10-18'),
          220,
          scrollable: find.byType(Scrollable).last,
        );
        final row = find.ancestor(
          of: find.text('2026-10-18'),
          matching: find.byType(ListTile),
        );
        final trash = find.descendant(
          of: row,
          matching: find.byTooltip('Delete'),
        );
        await tester.ensureVisible(trash);
        await tester.tap(trash);
        await tester.pumpAndSettle();
        expect(find.text('Delete weight?'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byWidgetPredicate((widget) => widget is AlertDialog),
            matching: find.text(confirm ? 'Delete' : 'Cancel'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Delete weight?'), findsNothing);
        expect(
          shellKey.currentState!.canPop(),
          isTrue,
          reason: 'The pushed history route must remain on the shell stack',
        );
        expect(find.text('Weight history'), findsOneWidget);
        final rows = await repository.getAll();
        expect(rows.map((row) => row.id), contains(keptId));
        expect(rows.any((row) => row.id == testId), !confirm);
        expect(
          find.text('2026-10-18'),
          confirm ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  for (final input in ['81.25', '81,25', '٨١٫٢٥', '۸۱٫۲۵']) {
    testWidgets('historical weight accepts precise manual value $input', (
      tester,
    ) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WeightRepository(database);
      await repository.addWeight(
        80,
        date: DateTime(2026, 10, 18),
        note: 'Keep this note',
      );
      await _openStandalone(tester, database);
      await _openWeightEditor(tester);
      await tester.tap(find.byKey(const Key('smart-weight-scale-readout')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('weight-history-precise-input'));
      expect(field, findsOneWidget);
      await tester.enterText(field, input);
      await tester.tap(find.byKey(const Key('weight-history-precise-apply')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SmartWeightScaleField>(find.byType(SmartWeightScaleField))
            .value,
        81.25,
      );
      expect(
        (await repository.getAll()).single.weight,
        80,
        reason: 'Typing changes only the draft',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await repository.getAll()).single;
      expect(saved.weight, 81.25);
      expect(saved.date, DateTime(2026, 10, 18));
      expect(saved.note, 'Keep this note');
      expect(find.text('81.25 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final kilograms in [20.0, 350.0]) {
    testWidgets(
      'imperial endpoint $kilograms kg accepts unchanged and retyped displayed pounds',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = WeightRepository(database);
        await repository.addWeight(kilograms, date: DateTime(2026, 10, 18));
        await _openStandalone(tester, database, imperial: true);
        for (final retype in [false, true]) {
          await _openWeightEditor(tester);
          await tester.tap(find.byKey(const Key('smart-weight-scale-readout')));
          await tester.pumpAndSettle();
          final field = find.byKey(const Key('weight-history-precise-input'));
          final expectedText = kilograms == 20 ? '44.09' : '771.62';
          expect(
            find.descendant(of: field, matching: find.text(expectedText)),
            findsOneWidget,
          );
          if (retype) {
            await tester.enterText(field, '');
            await tester.pump();
            await tester.enterText(field, expectedText);
          }
          await tester.tap(
            find.byKey(const Key('weight-history-precise-apply')),
          );
          await tester.pumpAndSettle();
          expect(field, findsNothing);
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          expect((await repository.getAll()).single.weight, kilograms);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'imperial manual input preserves a normal decimal and rejects outside displayed endpoints',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WeightRepository(database);
      await repository.addWeight(80, date: DateTime(2026, 10, 18));
      await _openStandalone(tester, database, imperial: true);
      await _openWeightEditor(tester);
      await tester.tap(find.byKey(const Key('smart-weight-scale-readout')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('weight-history-precise-input'));
      for (final invalid in ['44.08', '771.63']) {
        await tester.enterText(field, invalid);
        await tester.tap(find.byKey(const Key('weight-history-precise-apply')));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid weight.'), findsOneWidget);
        expect((await repository.getAll()).single.weight, 80);
      }
      await tester.enterText(field, '180.25');
      await tester.tap(find.byKey(const Key('weight-history-precise-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        (await repository.getAll()).single.weight,
        UnitConverter.weightToKg(180.25, MeasurementSystem.imperial),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unchanged imperial text preserves exact kg; intentional retyping uses entered lb',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WeightRepository(database);
      await repository.addWeight(81.25, date: DateTime(2026, 10, 18));
      await _openStandalone(tester, database, imperial: true);
      for (final retype in [false, true]) {
        await _openWeightEditor(tester);
        await tester.tap(find.byKey(const Key('smart-weight-scale-readout')));
        await tester.pumpAndSettle();
        if (retype) {
          await tester.enterText(
            find.byKey(const Key('weight-history-precise-input')),
            '',
          );
          await tester.pump();
          await tester.enterText(
            find.byKey(const Key('weight-history-precise-input')),
            '179.13',
          );
        }
        await tester.tap(find.byKey(const Key('weight-history-precise-apply')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          (await repository.getAll()).single.weight,
          retype
              ? UnitConverter.weightToKg(179.13, MeasurementSystem.imperial)
              : 81.25,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'invalid precise weights are rejected and cancellation keeps the record',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WeightRepository(database);
      await repository.addWeight(80, date: DateTime(2026, 10, 18));
      await _openStandalone(tester, database);
      await _openWeightEditor(tester);
      await tester.tap(find.byKey(const Key('smart-weight-scale-readout')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('weight-history-precise-input'));
      for (final input in [
        '',
        '19.99',
        '350.01',
        '81.250',
        'NaN',
        'Infinity',
        '-81',
        '1e2',
      ]) {
        await tester.enterText(field, input);
        await tester.tap(find.byKey(const Key('weight-history-precise-apply')));
        await tester.pumpAndSettle();
        expect(field, findsOneWidget, reason: input);
        expect(
          find.text('Enter a valid weight.'),
          findsOneWidget,
          reason: input,
        );
        expect((await repository.getAll()).single.weight, 80);
      }
      final dialog = find.ancestor(
        of: field,
        matching: find.byWidgetPredicate((widget) => widget is AlertDialog),
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Cancel')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await repository.getAll()).single.weight, 80);
      expect(tester.takeException(), isNull);
    },
  );

  for (final contextValue in ['afterFood', 'unspecified']) {
    testWidgets(
      'editing stored $contextValue is supported without a dropdown assertion',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = WeightRepository(database);
        await repository.addWeight(
          81.25,
          date: DateTime(2026, 10, 18),
          measurementContext: contextValue,
        );
        await _openStandalone(tester, database);
        await _openWeightEditor(tester);
        expect(find.text(contextValue), findsNothing);
        expect(
          find.text(
            contextValue == 'afterFood' ? 'After eating' : 'Not specified',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          (await repository.getAll()).single.measurementContext,
          contextValue,
        );
        expect((await repository.getAll()).single.weight, 81.25);
      },
    );
  }

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'weight conditions have readable labels for ${locale.toLanguageTag()}',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        await WeightRepository(
          database,
        ).addWeight(80, date: DateTime(2026, 10, 18));
        await _openStandalone(tester, database, locale: locale);
        await _openWeightEditor(tester);
        final dropdown = tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>),
        );
        final items = dropdown.items!;
        expect(items.map((item) => item.value).toSet(), {
          'morning',
          'afterFood',
          'afterBathroom',
          'beforeFoodDrink',
          'differentConditions',
          'unspecified',
        });
        for (final item in items) {
          final label = (item.child as Text).data!;
          expect(label.trim(), isNotEmpty);
          expect(
            label,
            isNot(item.value),
            reason: '${locale.toLanguageTag()}/${item.value}',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final operation in ['edit', 'delete']) {
    testWidgets(
      'owner switch while $operation dialog is open cannot change either account',
      (tester) async {
        final first = AppDatabase.forTesting(NativeDatabase.memory());
        final second = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(second.close);
        final a = WeightRepository(first);
        final b = WeightRepository(second);
        final aId = await a.addWeight(80, date: DateTime(2026, 10, 18));
        final bId = await b.addWeight(90, date: DateTime(2026, 10, 18));
        expect(
          aId,
          bId,
          reason: 'Must exercise the same row id in different owner databases',
        );
        final container = await _openStandalone(tester, first);
        if (operation == 'edit') {
          await _openWeightEditor(tester);
          await tester.tap(
            find.byKey(const Key('smart-weight-scale-increase')),
          );
        } else {
          await tester.scrollUntilVisible(
            find.text('2026-10-18'),
            220,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.byTooltip('Delete'));
        }
        await tester.pumpAndSettle();
        container.updateOverrides([databaseProvider.overrideWithValue(second)]);
        await tester.pumpAndSettle();
        final action = operation == 'edit' ? 'Save' : 'Delete';
        await tester.tap(
          find.descendant(
            of: find.byWidgetPredicate((widget) => widget is AlertDialog),
            matching: find.text(action),
          ),
        );
        await tester.pumpAndSettle();
        expect((await a.getAll()).single.weight, 80);
        expect((await b.getAll()).single.weight, 90);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<ProviderContainer> _openStandalone(
  WidgetTester tester,
  AppDatabase database, {
  Locale locale = const Locale('en'),
  bool imperial = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      if (imperial)
        measurementSystemProvider.overrideWith(
          (ref) => Stream.value(MeasurementSystem.imperial),
        ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await database.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HistoryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openWeightEditor(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('2026-10-18'),
    220,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
  final row = find.ancestor(
    of: find.text('2026-10-18'),
    matching: find.byType(ListTile),
  );
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}
