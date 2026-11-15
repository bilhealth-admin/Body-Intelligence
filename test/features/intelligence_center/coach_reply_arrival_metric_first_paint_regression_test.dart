import 'dart:convert';

import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_reply_arrival.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic virtual frames reproduce two production scheduling conditions.
// The original native 1500ms wall-clock gate remains unchanged and mandatory.
void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'continuous IME changes cannot starve a complete ${direction.name} reply',
      (tester) async {
        final id = 'qa-continuous-ime-first-paint-${direction.name}';
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        tester.view.padding = const FakeViewPadding(bottom: 24);
        tester.view.viewInsets = FakeViewPadding.zero;
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        final reply = direction == TextDirection.rtl
            ? 'الرد الكامل موجود ولا يجوز أن تبقيه حركة لوحة المفاتيح مخفيًا.'
            : 'The complete reply must remain readable during keyboard motion.';
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: CoachReplyArrival(
                  messageId: id,
                  animate: true,
                  child: SizedBox(width: 320, height: 180, child: Text(reply)),
                ),
              ),
            ),
          ),
        );
        final fade = find.byKey(ValueKey('coach-reply-arrival-fade-$id'));
        final size = tester.getSize(find.text(reply));
        final frames = <Map<String, Object?>>[];
        for (var elapsed = 16; elapsed <= 1500; elapsed += 16) {
          // Native IMEs may alternate opening/closing notifications before they
          // settle. These are explicit synthetic metrics, not fabricated native
          // insets (the failed native trace did not record raw viewInsets).
          final inset = (elapsed ~/ 16).isOdd ? 264.0 : 80.0;
          tester.view.padding = FakeViewPadding.zero;
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pump(const Duration(milliseconds: 16));
          frames.add({
            'elapsed_ms': elapsed,
            'opacity': tester.widget<FadeTransition>(fade).opacity.value,
          });
          expect(tester.getSize(find.text(reply)), size);
        }
        final visible = frames
            .where((frame) => (frame['opacity'] as double) > 0)
            .toList();
        final lastOpacity = tester.widget<FadeTransition>(fade).opacity.value;
        final completeReplyMounted = find.text(reply).evaluate().length == 1;
        debugPrint(
          jsonEncode({
            'case': id,
            'first_visible_ms': visible.isEmpty
                ? null
                : visible.first['elapsed_ms'],
            'last_opacity': lastOpacity,
            'frames': frames.length,
          }),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(completeReplyMounted, isTrue);
        expect(
          visible,
          isNotEmpty,
          reason:
              'A complete reply must become visible within the unchanged 1500ms virtual-frame window even if IME notifications keep arriving.',
        );
        expect(lastOpacity, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('metric debounce requests its own frame after opacity is paused', (
    tester,
  ) async {
    const id = 'qa-idle-metric-debounce-frame';
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachReplyArrival(
            messageId: id,
            animate: true,
            child: Text(
              'The complete reply is present before a real viewport contraction.',
            ),
          ),
        ),
      ),
    );
    final fade = find.byKey(const ValueKey('coach-reply-arrival-fade-$id'));
    final previous = tester.view.physicalSize;
    tester.view.physicalSize = Size(previous.width - 30, previous.height);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    final idleBeforeDebounce = !tester.binding.hasScheduledFrame;
    final pausedOpacity = tester.widget<FadeTransition>(fade).opacity.value;
    // AutomatedTestWidgetsFlutterBinding.pump advances virtual timers, but
    // draws only a scheduled frame. The fixture does not schedule one here.
    await tester.pump(const Duration(milliseconds: 80));
    final scheduledByDebounce = tester.binding.hasScheduledFrame;
    await tester.pump(const Duration(milliseconds: 160));
    // The first tick establishes AnimationController start time at zero.
    // Observe the next naturally scheduled frame, still below 300ms total.
    await tester.pump(const Duration(milliseconds: 16));
    final opacityAfterOwnFrame = tester
        .widget<FadeTransition>(fade)
        .opacity
        .value;
    debugPrint(
      jsonEncode({
        'case': id,
        'idle_before_debounce': idleBeforeDebounce,
        'paused_opacity': pausedOpacity,
        'frame_requested_by_debounce': scheduledByDebounce,
        'opacity_after_own_frame': opacityAfterOwnFrame,
      }),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      idleBeforeDebounce,
      isTrue,
      reason:
          'The regression must reach the actual idle-with-no-frame condition.',
    );
    expect(pausedOpacity, 0);
    expect(
      scheduledByDebounce,
      isTrue,
      reason:
          'A delayed layout gate must schedule the frame it waits for, without depending on a tap or another animation.',
    );
    expect(opacityAfterOwnFrame, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
