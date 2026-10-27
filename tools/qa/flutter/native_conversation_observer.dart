import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Observes the accepted outgoing row rather than global animation idleness.
/// A focused composer may keep its caret active. It is not a pending send.
Future<void> nativeQaAwaitAcceptedConversationSend(
  WidgetTester tester, {
  required int Function() sendCount,
  required Finder composer,
  required Finder sendButton,
  required Finder acceptedRow,
  required Finder viewport,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = tester.binding.clock.fromNowBy(timeout);
  while (tester.binding.clock.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      sendCount(),
      lessThanOrEqualTo(1),
      reason: 'A send must not duplicate.',
    );
    if (sendCount() != 1 ||
        composer.evaluate().length != 1 ||
        sendButton.evaluate().length != 1 ||
        acceptedRow.evaluate().length != 1 ||
        viewport.evaluate().length != 1) {
      continue;
    }
    if (tester.widget<TextField>(composer).controller!.text.isNotEmpty ||
        tester.widget<IconButton>(sendButton).onPressed == null ||
        find
            .byKey(const ValueKey('coach-sent-message-flight'))
            .evaluate()
            .isNotEmpty) {
      continue;
    }
    final hidden = tester
        .widgetList<Opacity>(
          find.ancestor(of: acceptedRow, matching: find.byType(Opacity)),
        )
        .any((opacity) => opacity.opacity < .99);
    if (hidden) continue;
    final row = tester.getRect(acceptedRow);
    final clip = tester.getRect(viewport);
    final visible = row.intersect(clip);
    if (!visible.isEmpty &&
        visible.height >= row.height.clamp(0.0, clip.height) * .5 &&
        visible.width >= row.width.clamp(0.0, clip.width) * .5) {
      return;
    }
  }
  fail(
    'Send did not reach one acknowledged, visible row with an empty composer '
    'and an enabled send action within ${timeout.inMilliseconds}ms.',
  );
}
