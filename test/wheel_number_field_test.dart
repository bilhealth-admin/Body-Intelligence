import 'dart:ui' show SemanticsAction;

import 'package:body_intelligence_log/shared/widgets/wheel_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'visual_closure/closure_surface_capture.dart';

void main() {
  testWidgets(
    'SmartWeightScale hold changes draft by configured fractional steps only',
    (tester) async {
      var draft = 70.05;
      var callbacks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('scale-capture'),
              child: StatefulBuilder(
                builder: (context, setState) => SmartWeightScaleField(
                  value: draft,
                  minimum: 20,
                  maximum: 100,
                  step: .1,
                  decimalPlaces: 1,
                  unit: 'kg',
                  label: 'Weight',
                  onChanged: (next) => setState(() {
                    draft = next;
                    callbacks++;
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      final plus = find.byIcon(Icons.add_rounded);
      await tester.tap(plus);
      await tester.pump();
      expect(draft, closeTo(70.15, 1e-9));
      await captureClosureFrames(
        tester,
        find.byKey(const Key('scale-capture')),
        'weight-repeat-after',
        step: 'short-tap',
        frames: 2,
      );
      final gesture = await tester.startGesture(tester.getCenter(plus));
      await tester.pump(const Duration(milliseconds: 340));
      await tester.pump(const Duration(milliseconds: 150));
      expect(draft, closeTo(70.45, 1e-9));
      await captureClosureFrames(
        tester,
        find.byKey(const Key('scale-capture')),
        'weight-repeat-after',
        step: 'holding',
        frames: 3,
      );
      await gesture.up();
      await tester.pump();
      final released = draft;
      final count = callbacks;
      await tester.pump(const Duration(seconds: 1));
      expect(draft, released);
      expect(callbacks, count);
      await captureClosureFrames(
        tester,
        find.byKey(const Key('scale-capture')),
        'weight-repeat-after',
        step: 'released',
        frames: 3,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('screen readers can adjust by exactly one configured step', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = 60.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => WheelNumberField(
              value: value,
              minimum: 20,
              maximum: 100,
              step: 0.1,
              decimalPlaces: 1,
              unit: 'kg',
              label: 'Weight',
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(WheelNumberField));
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pumpAndSettle();
    expect(value, closeTo(60.1, 0.0001));
    node.owner!.performAction(node.id, SemanticsAction.decrease);
    await tester.pumpAndSettle();
    expect(value, closeTo(60.0, 0.0001));
    semantics.dispose();
  });
  testWidgets('typed values update the wheel field callback', (tester) async {
    double value = 70;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WheelNumberField(
            value: value,
            minimum: 30,
            maximum: 300,
            step: 0.1,
            decimalPlaces: 1,
            unit: 'kg',
            label: 'Weight',
            onChanged: (next) => value = next,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '81.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(value, 81.5);
    expect(find.text('81.5'), findsWidgets);
  });

  testWidgets('locale decimal separator is preserved as a precise value', (
    tester,
  ) async {
    double value = 70;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WheelNumberField(
            value: value,
            minimum: 20,
            maximum: 350,
            step: 0.1,
            decimalPlaces: 1,
            unit: 'kg',
            label: 'Weight',
            onChanged: (next) => value = next,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '77,2');
    await tester.pumpAndSettle();

    expect(value, closeTo(77.2, 0.000001));
  });

  testWidgets('tapping an adjacent visible wheel value selects one step', (
    tester,
  ) async {
    double value = 70;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WheelNumberField(
            value: value,
            minimum: 20,
            maximum: 350,
            step: 0.1,
            decimalPlaces: 1,
            unit: 'kg',
            label: 'Weight',
            onChanged: (next) => value = next,
          ),
        ),
      ),
    );

    await tester.tap(find.text('70.1'));
    await tester.pumpAndSettle();

    expect(value, closeTo(70.1, 0.000001));
  });
}
