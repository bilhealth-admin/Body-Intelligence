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

  testWidgets('compact RTL dark layout keeps identity, fields, and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1D4ED8),
            brightness: Brightness.dark,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showQuickMacroEntryDialog(
                context: context,
                copy: (_, arabic) => arabic,
                mealLabel: 'الإفطار',
                onSave: (_) async {},
              ),
              child: const Text('فتح'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    final wordmark = find.byKey(const Key('quick-macro-wordmark'));
    expect(wordmark, findsOneWidget);
    expect(tester.getSemantics(wordmark).label, 'Body Intelligence Log');
    expect(find.byKey(const Key('quick-macro-field-0')), findsOneWidget);
    expect(find.byKey(const Key('quick-macro-field-3')), findsOneWidget);
    expect(find.text('إضافة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
