import 'package:body_intelligence_log/shared/widgets/calendar/bil_crystal_calendar_date_picker.dart';
import 'package:body_intelligence_log/shared/widgets/calendar/bil_crystal_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'pinned calendar keeps real SDK date constraints and navigation $language dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          Future<List<DateTime>> exercise(bool crystal) async {
            final selected = <DateTime>[];
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => SizedBox(
                      height: 400,
                      child: crystal
                          ? BilCrystalCalendarDatePicker(
                              initialDate: DateTime(2026, 10, 25),
                              currentDate: DateTime(2026, 10, 25),
                              firstDate: DateTime(2026, 10, 1),
                              lastDate: DateTime(2026, 11, 30),
                              onDateChanged: selected.add,
                            )
                          : CalendarDatePicker(
                              initialDate: DateTime(2026, 10, 25),
                              currentDate: DateTime(2026, 10, 25),
                              firstDate: DateTime(2026, 10, 1),
                              lastDate: DateTime(2026, 11, 30),
                              onDateChanged: selected.add,
                            ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final local = MaterialLocalizations.of(
              tester.element(find.byType(Scaffold)),
            );
            if (crystal) {
              expect(
                find.byKey(const Key('bil-crystal-arrow-bubble')),
                findsNWidgets(3),
              );
            }
            final prev = tester
                .widgetList<IconButton>(find.byType(IconButton))
                .where((w) => w.onPressed == null);
            expect(
              prev.length,
              1,
              reason: 'October is the first permitted month',
            );
            await tester.tap(find.text(local.formatDecimal(26)).first);
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip(local.nextMonthTooltip));
            await tester.pumpAndSettle();
            await tester.tap(find.text(local.formatDecimal(2)).first);
            await tester.pumpAndSettle();
            expect(selected, [DateTime(2026, 10, 26), DateTime(2026, 11, 2)]);
            final nextDisabled = tester
                .widgetList<IconButton>(find.byType(IconButton))
                .where((w) => w.onPressed == null);
            expect(
              nextDisabled.length,
              1,
              reason: 'November is the last permitted month',
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            return selected;
          }

          final sdk = await exercise(false);
          final bil = await exercise(true);
          expect(bil, sdk);
        },
      );
    }
  }

  testWidgets(
    'date dialog cancel returns no date; confirmation returns the selected actual date',
    (tester) async {
      DateTime? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showBilCrystalDatePicker(
                    context: context,
                    initialDate: DateTime(2026, 10, 25),
                    firstDate: DateTime(2026, 10, 1),
                    lastDate: DateTime(2026, 10, 31),
                  );
                },
                child: const Text('Open date'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open date'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('bil-crystal-arrow-bubble')),
        findsNWidgets(3),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('26').first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 26));
      expect(tester.takeException(), isNull);
    },
  );
}
