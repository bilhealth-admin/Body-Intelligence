import 'package:body_intelligence_log/shared/widgets/bil_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'canonical full wordmark honors color without adding a card surface',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: BilFullWordmark(
              key: Key('canonical-wordmark'),
              color: Colors.blue,
            ),
          ),
        ),
      );

      final mark = find.byKey(const Key('canonical-wordmark'));
      expect(tester.getSemantics(mark).label, 'Body Intelligence Log');
      expect(find.text('BODY INTELLIGENCE LOG'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('BODY INTELLIGENCE LOG')).style?.color,
        Colors.blue,
      );
      expect(
        find.descendant(of: mark, matching: find.byType(Container)),
        findsNothing,
      );
      semantics.dispose();
    },
  );

  testWidgets('default wordmark follows light and dark theme contrast', (
    tester,
  ) async {
    Future<Color?> render(Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: Scaffold(
            body: BilFullWordmark(key: ValueKey<Brightness>(brightness)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<Text>(find.text('BODY INTELLIGENCE LOG'))
          .style
          ?.color;
    }

    expect(await render(Brightness.light), const Color(0xFF050505));
    expect(await render(Brightness.dark), const Color(0xFFF7FAFC));
  });
}
