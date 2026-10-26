import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conversation scenarios enter through the same Overview button as a member.
/// This does not dismiss a paywall, grant access, inject state or send a turn.
/// Existing scenarios still assert their original receipts and safety gates.
Future<void> openCoachConversationFromOverview(WidgetTester tester) async {
  await tester.pump(bilFeatureEntryDuration);
  await tester.pumpAndSettle();
  // Native SQLite fixtures may mount their first page in a real async zone.
  // Drain both clocks without changing or bypassing the production hold.
  final welcome = find.byKey(const Key('bil-pearl-feature-canvas'));
  final watch = Stopwatch()..start();
  while (welcome.evaluate().isNotEmpty &&
      watch.elapsed < const Duration(seconds: 4)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(welcome, findsNothing, reason: 'The entry hold must finish.');
  final overview = find.byKey(const Key('coach-reference-workspace'));
  if (overview.evaluate().isEmpty) return; // Already in chat, or gated.
  final open = find.byKey(const Key('coach-workspace-open-chat'));
  expect(open, findsOneWidget);
  await tester.ensureVisible(open);
  await tester.pumpAndSettle();
  await tester.tap(open);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('ai-coach-question-field')), findsOneWidget);
}
