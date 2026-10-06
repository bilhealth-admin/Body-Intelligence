import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reveal the actual control before tapping it. Content may be lazily built or
/// below the fixed, reference bottom navigation. Never invoke callbacks or
/// suppress a missed hit to make a behavior assertion pass.
Future<void> revealCommunityControl(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      target,
      220,
      scrollable: scrollable,
      maxScrolls: 100,
    );
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pump();
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: 'The intended Community control must receive the pointer.',
  );
}

Future<void> tapCommunityControl(WidgetTester tester, Finder target) async {
  await revealCommunityControl(tester, target);
  await tester.tap(target.hitTestable());
}
