import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart'
    as native_qa;

void main() {
  testWidgets(
    'native keyboard dismissal uses platform IME without a test stub',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(focusNode: focus)),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Preserve this test draft',
      );
      expect(focus.hasFocus, isTrue);
      tester.testTextInput.unregister();
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      try {
        expect(tester.testTextInput.isRegistered, isFalse);
        await native_qa.nativeQaDismissKeyboard(tester);
        expect(focus.hasFocus, isFalse);
        expect(
          calls.where((call) => call.method == 'TextInput.hide'),
          isNotEmpty,
        );
        expect(tester.testTextInput.isRegistered, isFalse);
        expect(find.text('Preserve this test draft'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          null,
        );
        tester.testTextInput.register();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
