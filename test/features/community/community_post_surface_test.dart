import 'package:body_intelligence_log/features/community/presentation/community_post_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final contrast in [false, true]) {
      testWidgets('post surface stays neutral $brightness contrast=$contrast', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              colorSchemeSeed: Colors.blue,
            ),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(highContrast: contrast),
                child: CommunityPostSurface(
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('Like'),
                  ),
                ),
              ),
            ),
          ),
        );
        final root = find
            .descendant(
              of: find.byType(CommunityPostSurface),
              matching: find.byType(Container),
            )
            .first;
        final decoration =
            tester.widget<Container>(root).decoration! as BoxDecoration;
        expect(
          decoration.color,
          brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF222222),
        );
        expect(decoration.gradient, isNull);
        final border = decoration.border! as Border;
        expect(border.top.color.r, border.top.color.g);
        expect(border.top.color.g, border.top.color.b);
        if (contrast) expect(decoration.boxShadow, isEmpty);
        await tester.tap(find.text('Like'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
