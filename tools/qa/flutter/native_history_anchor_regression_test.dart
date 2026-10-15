import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart'
    as native_qa;

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets(
      'older $language anchor requires a real progressive history drag',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatHistoryViewport(
                controller: controller,
                latestMessageId: 'pending-qa-turn',
                child: ListView(
                  controller: controller,
                  reverse: true,
                  children: [
                    const SizedBox(
                      height: 1800,
                      child: Text('Newest held turn'),
                    ),
                    for (var i = 0; i < 10; i++)
                      CoachMessageText(
                        key: ValueKey('qa-old-$i'),
                        text: language == 'ar'
                            ? 'سجل محلي تركيبي $i: رسالة قديمة للقراءة.'
                            : 'Synthetic local history $i: an older readable row.',
                        createdAt: DateTime.utc(2026, 10, 15),
                        textDirection: language == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        showTime: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final metadata = <String, Object?>{};
        final anchor = await native_qa.nativeQaEnterOlderHistory(
          tester,
          language: language,
          metadata: metadata,
        );
        final attempts = metadata['history_anchor_search']! as List;
        expect(attempts.length, greaterThan(1));
        expect((attempts.first as Map)['visible_history_candidates'], 0);
        expect(anchor, findsOneWidget);
        expect(metadata['history_anchor_key'], contains('qa-old-'));
        final viewport = tester.getRect(find.byType(ChatHistoryViewport));
        expect(
          tester.getRect(anchor).intersect(viewport).height,
          greaterThanOrEqualTo(20),
        );
        expect(
          controller.offset - controller.position.minScrollExtent,
          greaterThan(72),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('missing older content stays a failed history condition', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHistoryViewport(
            controller: controller,
            latestMessageId: 'no-history-qa',
            child: ListView(
              controller: controller,
              reverse: true,
              children: const [
                SizedBox(
                  height: 2400,
                  child: Text('No historical message row'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final metadata = <String, Object?>{};
    Object? failure;
    try {
      await native_qa.nativeQaEnterOlderHistory(
        tester,
        language: 'ar',
        metadata: metadata,
        maximumDrags: 2,
      );
    } catch (error) {
      failure = error;
    }
    expect(
      failure,
      isA<StateError>().having(
        (error) => error.message,
        'reason',
        contains('native_history_anchor_unavailable'),
      ),
    );
    expect((metadata['history_anchor_search']! as List).length, 2);
    expect(metadata.containsKey('history_anchor_key'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
