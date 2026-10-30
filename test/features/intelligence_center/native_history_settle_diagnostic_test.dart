import 'dart:io' as io;

import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_native_markdown.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart' as native;

Future<void> _mountHistory(
  WidgetTester tester,
  ScrollController controller, {
  ValueNotifier<double>? viewportHeight,
}) async {
  Widget history(double height) => SizedBox(
    height: height,
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
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: viewportHeight == null
            ? history(400)
            : ValueListenableBuilder<double>(
                valueListenable: viewportHeight,
                builder: (_, height, _) => history(height),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'real drag preparation waits for keyboard end and a later viewport resize',
    (tester) async {
      final controller = ScrollController();
      final height = ValueNotifier(400.0);
      final metadata = <String, Object?>{};
      tester.view.viewInsets = FakeViewPadding(bottom: 100);
      addTearDown(tester.view.resetViewInsets);
      var active = true;
      var dismissalRequested = false;
      void observe(Duration _) {
        if (!active) return;
        final preparations = metadata['history_drag_preparation'];
        if (preparations is List && preparations.isNotEmpty) {
          final samples = (preparations.last as Map)['samples'] as List;
          if (samples.length == 3 && !dismissalRequested) {
            dismissalRequested = true;
            tester.view.viewInsets = FakeViewPadding.zero;
            // Resize on the following frame's layout, after the native inset
            // has reached zero. Post-frame callback count is not pump count.
            WidgetsBinding.instance.scheduleFrameCallback((_) {
              if (active) height.value = 320;
            });
          }
        }
        WidgetsBinding.instance.addPostFrameCallback(observe);
        WidgetsBinding.instance.scheduleFrame();
      }

      try {
        await _mountHistory(tester, controller, viewportHeight: height);
        WidgetsBinding.instance.addPostFrameCallback(observe);
        final anchor = await native.nativeQaEnterOlderHistory(
          tester,
          language: 'en',
          metadata: metadata,
          maximumDrags: 1,
        );
        expect(anchor, findsOneWidget);
        final preparations = metadata['history_drag_preparation'] as List;
        final preparation = preparations.single as Map;
        final samples = (preparation['samples'] as List).cast<Map>();
        expect(preparation['completed'], isTrue);
        expect(preparation['maximum_pumps'], 80);
        expect(preparation['settled_comparisons_at_exit'], 2);
        expect(preparation['completed_pumps'], greaterThanOrEqualTo(6));
        expect(
          samples.any((sample) => (sample['native_keyboard_inset'] as num) > 0),
          isTrue,
        );
        expect(
          samples.any(
            (sample) => (sample['viewport_edge_deltas'] as List)
                .cast<num>()
                .any((delta) => delta.abs() >= .1),
          ),
          isTrue,
        );
        final last = samples.last;
        expect(last['native_keyboard_inset'], 0);
        expect(last['media_keyboard_inset'], 0);
        expect((last['viewport'] as Map)['viewport_height'], 320);
        final guard = metadata['history_anchor_settle'] as Map;
        final firstGuard = (guard['samples'] as List).first as Map;
        expect(guard['completed'], isTrue);
        expect(guard['stable_at_exit'], 8);
        expect(guard['wall_deadline_ms'], 3500);
        expect((firstGuard['viewport_before'] as Map)['viewport_height'], 320);
        expect(
          (firstGuard['viewport_before'] as Map)['view_insets_bottom_physical'],
          0,
        );
      } finally {
        active = false;
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        height.dispose();
      }
    },
  );

  testWidgets('a never-dismissed keyboard refuses setup before the guard', (
    tester,
  ) async {
    final controller = ScrollController();
    final metadata = <String, Object?>{};
    tester.view.viewInsets = FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetViewInsets);
    try {
      await _mountHistory(tester, controller);
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
      expect(
        caught,
        isA<StateError>().having(
          (error) => error.message,
          'explicit setup failure',
          contains('native_history_drag_setup_not_ready_after_80_frames'),
        ),
      );
      expect(controller.offset, greaterThan(72));
      expect(metadata.containsKey('history_anchor_settle'), isFalse);
      expect(metadata['history_anchor_search'], isEmpty);
      final preparation =
          (metadata['history_drag_preparation'] as List).single as Map;
      expect(preparation['completed'], isFalse);
      expect(preparation['completed_pumps'], 80);
      expect(preparation['settled_comparisons_at_exit'], 0);
      expect(preparation['error_type'], 'StateError');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('an unsettled viewport refuses setup within the same80 pumps', (
    tester,
  ) async {
    final controller = ScrollController();
    final height = ValueNotifier(400.0);
    final metadata = <String, Object?>{};
    var active = true;
    void observe(Duration _) {
      if (!active) return;
      final preparations = metadata['history_drag_preparation'];
      if (preparations is List && preparations.isNotEmpty) {
        height.value = height.value == 400 ? 320 : 400;
      }
      WidgetsBinding.instance.addPostFrameCallback(observe);
      WidgetsBinding.instance.scheduleFrame();
    }

    try {
      await _mountHistory(tester, controller, viewportHeight: height);
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
      expect(
        caught,
        isA<StateError>().having(
          (error) => error.message,
          'explicit setup failure',
          contains('native_history_drag_setup_not_ready_after_80_frames'),
        ),
      );
      expect(metadata.containsKey('history_anchor_settle'), isFalse);
      final preparation =
          (metadata['history_drag_preparation'] as List).single as Map;
      expect(preparation['completed'], isFalse);
      expect(preparation['completed_pumps'], 80);
    } finally {
      active = false;
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      height.dispose();
    }
  });

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
        // The preparation now drains idle frames. This local stall probe must
        // request its own bounded control frames rather than depend on an app
        // animation to happen to schedule the guarded callback.
        WidgetsBinding.instance.scheduleFrame();
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
