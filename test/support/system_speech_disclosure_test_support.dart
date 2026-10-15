import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const systemSpeechDisclosureAllowKey = Key('system-speech-disclosure-allow');
const systemSpeechDisclosureBodyKey = Key('system-speech-disclosure-body');

/// Accept the actual Android disclosure route before continuing an existing
/// controlled-recognizer test. Missing/disabled disclosure remains a failure;
/// this never changes platform, consent state, or microphone authorization.
Future<void> acceptSystemSpeechDisclosure(
  WidgetTester tester, {
  bool settleAfterAccept = true,
}) async {
  final allow = find.byKey(systemSpeechDisclosureAllowKey);
  final body = find.byKey(systemSpeechDisclosureBodyKey);
  var dialogReady = false;
  // Wait only for this real route, not a Coach listening animation that is
  // deliberately continuous. Missing or unfinished disclosure still fails.
  for (var frame = 0; frame < 50 && !dialogReady; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (body.evaluate().length == 1) {
      dialogReady =
          ModalRoute.of(tester.element(body))?.animation?.status ==
          AnimationStatus.completed;
    }
  }
  expect(dialogReady, isTrue);
  expect(body, findsOneWidget);
  expect(allow, findsOneWidget);
  expect(tester.widget<FilledButton>(allow).onPressed, isNotNull);
  await tester.ensureVisible(allow);
  await tester.tap(allow);
  for (var frame = 0; frame < 50 && body.evaluate().isNotEmpty; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(body, findsNothing);
  if (settleAfterAccept) await tester.pumpAndSettle();
}
