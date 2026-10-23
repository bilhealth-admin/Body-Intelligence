import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'smart_plan_contrast_review.dart';

void main() {
  testWidgets(
    'resolved contrast rejects actual low-contrast styles and opacity; gradients do not suppress checks',
    (tester) async {
      for (final pair in [
        (Colors.black, 1.0, true),
        (Colors.grey, 1.0, false),
        (Colors.black, .3, false),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: const ValueKey('capture'),
              child: Scaffold(
                body: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Color(0xfff0f5fa)],
                    ),
                  ),
                  child: SizedBox.expand(
                    child: Center(
                      child: Opacity(
                        opacity: pair.$2,
                        child: Text(
                          'A real readable label',
                          style: TextStyle(color: pair.$1, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final result = await smartPlanTextContrastFailures(
          tester,
          find.byKey(const ValueKey('capture')),
        );
        expect(result.isEmpty, pair.$3, reason: '$pair: $result');
      }
    },
  );
}
