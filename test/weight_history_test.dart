import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/history/history_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('weight history renders an accessible smoothed trend', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final weights = WeightRepository(database);
    for (var index = 0; index < 4; index++) {
      await weights.addWeight(
        80 - index * 0.2,
        date: DateTime(2026, 7, 1 + index),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weight trend'), findsOneWidget);
    expect(find.textContaining('Smoothed weekly direction'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith(
              'Recorded weight trend over time',
            ) &&
            widget.properties.image == true,
      ),
      findsOneWidget,
    );
    expect(find.text('Show raw measurements'), findsOneWidget);
    expect(find.textContaining('Confidence:'), findsNWidgets(2));
    expect(find.textContaining('Cautious goal estimate'), findsNWidgets(2));
    expect(
      find.textContaining('At least four comparable measurements are needed'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Current direction is not yet moving toward the selected goal direction.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('do not prove fat or muscle change'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Add weight'));
    await tester.pumpAndSettle();
    expect(find.text('Add weight'), findsOneWidget);
    expect(find.text('Measurement date'), findsOneWidget);
    expect(find.text('Measurement conditions'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    semantics.dispose();
  });
}
