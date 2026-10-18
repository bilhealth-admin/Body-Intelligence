import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_thinking_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final rtl in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('waiting phases retain geometry rtl=$rtl scale=$scale', (
        tester,
      ) async {
        final labels = rtl
            ? ['أجهّز ردك…', 'أعمل على سؤالك…', 'شكرًا لانتظارك…']
            : [
                'Preparing your reply…',
                'Working on your question…',
                'Thanks for waiting…',
              ];
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Scaffold(
                  body: Column(
                    children: [
                      CoachThinkingStatus(
                        key: const Key('waiting'),
                        labels: labels,
                      ),
                      const Text('stable anchor', key: Key('anchor')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final rect = tester.getRect(find.byKey(const Key('anchor')));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pump(const Duration(milliseconds: 4500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(labels[1]), findsOneWidget);
        expect(tester.getRect(find.byKey(const Key('anchor'))), rect);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(labels[2]), findsOneWidget);
        expect(tester.getRect(find.byKey(const Key('anchor'))), rect);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }

  testWidgets('reduced motion stays readable without repeated animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: CoachThinkingStatus(labels: ['Preparing…', 'Please wait…']),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Preparing…'), findsOneWidget);
    expect(find.text('Please wait…'), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
