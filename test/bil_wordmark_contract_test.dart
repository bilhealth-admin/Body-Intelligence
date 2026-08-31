import 'package:body_intelligence_log/shared/widgets/bil_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'canonical full wordmark stays black on its light identity surface',
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
        const Color(0xFF050505),
      );
      final surface = tester.widget<Container>(
        find.descendant(of: mark, matching: find.byType(Container)).first,
      );
      expect((surface.decoration as BoxDecoration).color, Colors.white);
      semantics.dispose();
    },
  );
}
