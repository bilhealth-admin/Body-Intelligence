import 'package:body_intelligence_log/features/dashboard/widgets/first_use_context_coachmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('glassy contextual guide is optional and does not cover content', (
    tester,
  ) async {
    var skipCount = 0;
    var actionCount = 0;
    var underlyingTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                FirstUseContextCoachmark(
                  key: const Key('context-glass-test'),
                  title: 'ابحث عن طعامك',
                  message: 'يمكنك تخطي هذه الخطوة في أي وقت.',
                  step: 1,
                  stepCount: 2,
                  actionLabel: 'التالي',
                  onAction: () => actionCount++,
                  onSkip: () => skipCount++,
                  skipKey: const Key('context-glass-skip'),
                  actionKey: const Key('context-glass-next'),
                ),
                TextButton(
                  onPressed: () => underlyingTapped = true,
                  child: const Text('Underlying Food Log'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ابحث عن طعامك'), findsOneWidget);
    expect(find.text('تخطي'), findsOneWidget);
    final guide = tester.getRect(find.byKey(const Key('context-glass-test')));
    final underneath = tester.getRect(find.text('Underlying Food Log'));
    expect(guide.bottom, lessThanOrEqualTo(underneath.top));

    await tester.tap(find.byKey(const Key('context-glass-next')));
    expect(actionCount, 1);
    await tester.tap(find.byKey(const Key('context-glass-skip')));
    expect(skipCount, 1);
    await tester.tap(find.text('Underlying Food Log'));
    expect(underlyingTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce-motion mode has no entrance transition', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: FirstUseContextCoachmark(
              title: 'Search',
              message: 'Select an item.',
              onSkip: _noop,
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
