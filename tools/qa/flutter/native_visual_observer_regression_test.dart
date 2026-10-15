import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_reply_arrival.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart'
    as native_qa;

void main() {
  testWidgets('native geometry observer is safe during a guarded tester pump', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const reply = 'A synthetic native observer reply with visible glyphs.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHistoryViewport(
            controller: controller,
            latestMessageId: 'observer-only',
            child: ListView(
              controller: controller,
              reverse: true,
              children: [
                CoachMessageText(
                  key: const Key('observer-reply'),
                  text: reply,
                  createdAt: DateTime.utc(2026, 10, 15),
                  textDirection: TextDirection.ltr,
                  showTime: false,
                  animateReveal: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final samples = <Map<String, Object?>>[];
    final watch = Stopwatch()..start();
    var observing = true;
    void observe(Duration _) {
      if (!observing) return;
      samples.add(native_qa.nativeQaReplyGeometry(tester, reply, watch));
      WidgetsBinding.instance.addPostFrameCallback(observe);
    }

    WidgetsBinding.instance.addPostFrameCallback(observe);
    for (var i = 0; i < 80; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 32));
    }
    observing = false;
    expect(tester.takeException(), isNull);
    expect(samples.length, greaterThanOrEqualTo(70));
    expect(
      samples.every((sample) => sample['viewport_present'] == true),
      isTrue,
    );
    expect(
      samples.every((sample) => sample['reply_row_present'] == true),
      isTrue,
    );
    expect(samples.last['visible_graphemes'], reply.length);
    expect(samples.last['first_glyphs_visible_area'] as num, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('native observer measures the current complete-reply entrance', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const reply = 'Complete synthetic reply, without a typewriter prefix.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHistoryViewport(
            controller: controller,
            latestMessageId: 'current-arrival-observer',
            child: ListView(
              controller: controller,
              reverse: true,
              children: [
                CoachReplyArrival(
                  messageId: 'current-arrival-observer',
                  animate: true,
                  child: CoachMessageText(
                    key: const Key('current-arrival-text'),
                    text: reply,
                    createdAt: DateTime.utc(2026, 10, 15),
                    textDirection: TextDirection.ltr,
                    showTime: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final watch = Stopwatch()..start();
    final first = native_qa.nativeQaReplyGeometry(tester, reply, watch);
    expect(first['visible_graphemes'], reply.length);
    expect(first['arrival_present'], isTrue);
    expect(first['reply_opacity'], 0.0);
    await tester.pump(const Duration(milliseconds: 160));
    final middle = native_qa.nativeQaReplyGeometry(tester, reply, watch);
    expect(middle['visible_graphemes'], reply.length);
    expect(middle['reply_opacity'] as num, allOf(greaterThan(0), lessThan(1)));
    expect(middle['first_glyphs_visible_area'] as num, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 200));
    final end = native_qa.nativeQaReplyGeometry(tester, reply, watch);
    expect(end['reply_opacity'], 1.0);
    expect(end['message_height'], first['message_height']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
