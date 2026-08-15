import 'package:body_intelligence_log/features/daily_log/presentation/quick_macro_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Future<void> Function(QuickMacroDraft draft) onSave,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showQuickMacroEntryDialog(
                context: context,
                copy: (english, _) => english,
                mealLabel: 'Breakfast',
                onSave: onSave,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('saves explicit fields without inventing blank macro evidence', (
    tester,
  ) async {
    QuickMacroDraft? saved;
    await open(tester, (draft) async => saved = draft);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories'),
      '455',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(saved?.calories, 455);
    expect(saved?.caloriesKnown, isTrue);
    expect(saved?.protein, 0);
    expect(saved?.proteinKnown, isFalse);
    expect(find.text('Quick Add macros'), findsNothing);
  });

  testWidgets('write failure keeps the dialog and entered draft', (
    tester,
  ) async {
    await open(tester, (_) async => throw StateError('rejected'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories'),
      '455',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Quick Add macros'), findsOneWidget);
    expect(find.text('Could not save this entry. Try again.'), findsOneWidget);
    expect(find.text('455'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
