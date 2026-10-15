import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_reply_arrival.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart'
    as native_qa;

void main() {
  for (final arabic in [true, false]) {
    testWidgets(
      'first painted reply stays readable when IME resizes before arrival AR=$arabic',
      (tester) async {
        tester.view.physicalSize = const Size(412, 890);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final anchor = GlobalKey();
        final messageId = 'qa-ime-first-paint-$arabic';
        final reply = List.generate(
          26,
          (i) => arabic
              ? 'فقرة تركيبية $i: هذه قراءة محلية واضحة لا تحفظ طعامًا ولا تغيّر حسابًا.'
              : 'Synthetic paragraph $i: this readable reply performs no food write or account change.',
        ).join('\n');
        double readingTarget(ScrollPosition position) {
          final render = anchor.currentContext?.findRenderObject();
          if (!position.hasContentDimensions ||
              !position.hasViewportDimension ||
              render is! RenderBox ||
              !render.hasSize ||
              render.size.height <= position.viewportDimension) {
            return position.minScrollExtent;
          }
          return RenderAbstractViewport.of(render)
              .getOffsetToReveal(
                render,
                1,
                rect: Rect.fromLTWH(0, 0, render.size.width, 1),
                axis: Axis.vertical,
              )
              .offset
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
        }

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Column(
                children: [
                  const SizedBox(height: 182),
                  Expanded(
                    child: ChatHistoryViewport(
                      controller: controller,
                      latestMessageId: messageId,
                      latestTargetOffset: readingTarget,
                      child: ListView(
                        controller: controller,
                        reverse: true,
                        children: [
                          KeyedSubtree(
                            key: anchor,
                            child: CoachReplyArrival(
                              messageId: messageId,
                              animate: true,
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: CoachMessageText(
                                  text: reply,
                                  createdAt: DateTime.utc(2026, 10, 15),
                                  textDirection: arabic
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  style: const TextStyle(fontSize: 12),
                                  showTime: false,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 216),
                ],
              ),
            ),
          ),
        );
        final watch = Stopwatch()..start();
        final samples = <Map<String, Object?>>[
          native_qa.nativeQaReplyGeometry(tester, reply, watch),
        ];
        var observing = true;
        void observe(Duration _) {
          if (!observing) return;
          samples.add(native_qa.nativeQaReplyGeometry(tester, reply, watch));
          WidgetsBinding.instance.addPostFrameCallback(observe);
        }

        WidgetsBinding.instance.addPostFrameCallback(observe);
        // Reproduce native AR's delayed first frame: IME removes 199.219
        // logical pixels before the first positive opacity, after the old
        // reading offset was measured. Do not settle away this vulnerable frame.
        tester.view.viewInsets = const FakeViewPadding(
          bottom: 199.21896792189682,
        );
        await tester.pump(const Duration(milliseconds: 356));
        for (var frame = 0; frame < 24; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        observing = false;
        watch.stop();
        debugPrint(
          'BIL_IME_FIRST_PAINT ${<String, Object?>{'arabic': arabic, 'scope': 'widget virtual frame regression, not native performance', 'samples': samples}}',
        );
        final painted = samples.where(
          (sample) => (sample['reply_opacity'] as num? ?? 0) > 0,
        );
        expect(painted, isNotEmpty);
        expect(
          painted.first['first_glyphs_visible_area'] as num,
          greaterThan(0),
          reason:
              'First nonempty painted glyphs must be inside the resized viewport.',
        );
        expect(painted.first['visible_graphemes'], reply.characters.length);
        expect(samples.last['reply_opacity'], 1);
        expect(
          controller.offset,
          closeTo(readingTarget(controller.position), .5),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

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
