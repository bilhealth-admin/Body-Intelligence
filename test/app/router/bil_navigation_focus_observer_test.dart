import 'package:body_intelligence_log/app/router/bil_navigation_focus_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'navigation retires input, keeps drafts and permits destination autofocus',
    (tester) async {
      final original = FocusNode();
      final destination = FocusNode();
      final editor = TextEditingController();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [BilNavigationFocusObserver()],
          home: Scaffold(
            body: TextField(
              key: const Key('original'),
              focusNode: original,
              controller: editor,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('original')),
        'Keep this draft',
      );
      expect(tester.testTextInput.isVisible, isTrue);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: TextField(
              key: const Key('destination'),
              focusNode: destination,
              autofocus: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(original.hasFocus, isFalse);
      expect(destination.hasFocus, isTrue);
      await tester.enterText(
        find.byKey(const Key('destination')),
        'New input works',
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(original.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(editor.text, 'Keep this draft');
      await tester.tap(find.byKey(const Key('original')));
      await tester.pump();
      expect(original.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      original.dispose();
      destination.dispose();
      editor.dispose();
    },
  );
}
