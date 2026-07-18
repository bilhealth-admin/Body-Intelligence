import 'package:body_intelligence_log/shared/widgets/wheel_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
