import 'dart:io' as io;

import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_native_markdown.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart' as native;

Future<void> _mountHistory(
  WidgetTester tester,
  ScrollController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: SizedBox(
          height: 400,
          child: ChatHistoryViewport(
            controller: controller,
            latestMessageId: '29',
            child: ListView.builder(
              controller: controller,
              reverse: true,
              itemCount: 30,
              itemExtent: 120,
              itemBuilder: (_, index) => CoachMessageText(
                key: ValueKey('diagnostic-history-$index'),
                text: 'Synthetic local history $index: local observer fixture.',
                createdAt: DateTime(2026),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final fallback in [false, true]) {
    testWidgets(
      'reply metadata distinguishes ${fallback ? 'two matching fallback elements' : 'zero matching elements'} without accepting either',
      (tester) async {
        const reply = 'Actual local fallback reply fixture.';
        final controller = ScrollController();
        final text = CoachMessageText(
          key: const ValueKey('candidate-fallback-text'),
          text: reply,
          createdAt: DateTime(2026),
          textDirection: TextDirection.ltr,
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ChatHistoryViewport(
                  controller: controller,
                  latestMessageId: 'reply-candidate-fixture',
                  child: ListView(
                    controller: controller,
                    children: [
                      if (fallback)
                        CoachNativeMarkdown(
                          key: const ValueKey('candidate-native-parent'),
                          text: reply,
                          direction: TextDirection.ltr,
                          style: const TextStyle(fontSize: 16),
                          visitIsCurrent: () => true,
                          fallback: text,
                        )
                      else
                        const Text('No reply is mounted.'),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final sample = native.nativeQaReplyGeometry(
            tester,
            reply,
            Stopwatch()..start(),
          );
          expect(sample['viewport_present'], isTrue);
          expect(
            sample['reply_row_present'],
            isFalse,
            reason: 'The existing exact-one acceptance gate stays unchanged.',
          );
          expect(sample['actual_reply_candidate_count'], fallback ? 2 : 0);
          expect(
            sample['actual_reply_candidate_types'],
            fallback ? ['CoachNativeMarkdown', 'CoachMessageText'] : <String>[],
          );
          final parents = sample['ambiguous_reply_native_parents'] as List;
          expect(parents, hasLength(fallback ? 1 : 0));
          if (fallback) {
            final parent = parents.single as Map;
            expect(parent['mounted'], isTrue);
            expect(parent['state_identity'], isA<int>());
            expect(parent['matching_fallback_child_count'], 1);
            expect(parent['matching_fallback_child_types'], [
              'CoachMessageText',
            ]);
            expect(parent.containsKey('height_ready'), isTrue);
            expect(parent.containsKey('layout_ready'), isTrue);
            expect(parent.containsKey('paint_gate_scheduled'), isTrue);
          }
          expect(sample.containsKey('reply_opacity'), isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        }
      },
    );
  }
  testWidgets(
    'real history search retains nine successful stability observations',
    (tester) async {
      final controller = ScrollController();
      final metadata = <String, Object?>{};
      try {
        await _mountHistory(tester, controller);
        final anchor = await native.nativeQaEnterOlderHistory(
          tester,
          language: 'en',
          metadata: metadata,
        );
        expect(anchor, findsOneWidget);
        final receipt = metadata['history_anchor_settle'] as Map;
        final samples = receipt['samples'] as List;
        expect(receipt['completed'], isTrue);
        expect(receipt['completed_pumps'], 9);
        expect(receipt['stable_at_exit'], 8);
        expect(receipt['wall_deadline_ms'], 3500);
        expect(samples.first['stable_after'], 0);
        expect(samples.last['stable_after'], 8);
        for (final sample in samples.cast<Map>()) {
          expect(sample['completed_pump'], isTrue);
          expect(
            sample['after_pump_us'],
            greaterThanOrEqualTo(sample['before_pump_us']),
          );
          expect(sample['pump_wall_us'], greaterThanOrEqualTo(0));
          expect(sample['before_observer_wall_us'], greaterThanOrEqualTo(0));
          expect(sample['after_observer_wall_us'], greaterThanOrEqualTo(0));
          expect(sample['native_before'], {'mounted_rows': <Object>[]});
          expect(sample['native_after'], {'mounted_rows': <Object>[]});
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'one slow completed pump is retained while the original 3500ms guard still fails',
    (tester) async {
      final controller = ScrollController();
      final metadata = <String, Object?>{};
      var active = true;
      var delayed = false;
      void observe(Duration _) {
        if (!active) return;
        if (!delayed && metadata.containsKey('history_anchor_settle')) {
          delayed = true;
          // Bounded wall-time stall, not fake pump time or an altered guard.
          io.sleep(const Duration(milliseconds: 3650));
        }
        WidgetsBinding.instance.addPostFrameCallback(observe);
      }

      try {
        await _mountHistory(tester, controller);
        WidgetsBinding.instance.addPostFrameCallback(observe);
        Object? caught;
        try {
          await native.nativeQaEnterOlderHistory(
            tester,
            language: 'en',
            metadata: metadata,
          );
        } catch (error) {
          caught = error;
        }
        expect(caught, isA<TestFailure>());
        expect(
          caught.toString(),
          contains('History must settle before the reply is released.'),
        );
        final receipt = metadata['history_anchor_settle'] as Map;
        final samples = receipt['samples'] as List;
        expect(receipt['completed'], isFalse);
        expect(receipt['error_type'], 'TestFailure');
        expect(receipt['stable_at_exit'], 0);
        expect(receipt['completed_pumps'], 1);
        expect(samples, hasLength(1));
        expect(samples.single['completed_pump'], isTrue);
        expect(samples.single['pump_wall_us'], greaterThanOrEqualTo(3650000));
        expect(samples.single['after_pump_us'], greaterThanOrEqualTo(3500000));
        expect(samples.single['top'], isA<double>());
        expect(samples.single['native_after'], {'mounted_rows': <Object>[]});
        expect(receipt['elapsed_us'], greaterThanOrEqualTo(3500000));
      } finally {
        active = false;
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );
}
