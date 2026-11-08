import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_anchored_history.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_reply_arrival.dart';
import 'package:body_intelligence_log/shared/widgets/chat_history_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _top = 151.36190476190475;
const _largeHeight = 738.6857142857143 - _top;
const _smallHeight = 673.5237298266586 - _top;
var _visit = 0;

void main() {
  setUpAll(() async {
    await (FontLoader(
          'BILArabic',
        )..addFont(rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf')))
        .load();
    await (FontLoader(
      'BILDisplay',
    )..addFont(rootBundle.load('assets/fonts/Montserrat-Bold.ttf'))).load();
  });

  testWidgets(
    'AR 2x first painted reply stays inside the viewport on IME close/nav restoration',
    (tester) async {
      final harness = await _mount(tester, reducedMotion: false);
      try {
        harness.appendReply();
        await tester.pump();
        await tester.pump();
        final oldPixels = harness.controller.offset;
        expect(
          oldPixels,
          closeTo(harness.latestTarget(harness.controller.position), .5),
        );
        expect(harness.replyHeight, greaterThan(_largeHeight));
        tester.view.viewInsets = FakeViewPadding.zero;
        harness.restoreNavigation();
        await tester.pump(const Duration(milliseconds: 320));
        final painted = harness.frames
            .where((frame) => frame['phase'] == 'restore-nav')
            .toList();
        expect(painted, isNotEmpty);
        await _saveEvidence(tester, harness, 'ar-normal-first-restored-frame');
        expect(painted.first['reply_opacity'], 1.0);
        expect(
          painted.first['first_glyphs_visible_area'] as double,
          greaterThan(0),
          reason:
              'The first actually painted glyphs must be in the SAME contracted frame, before any post-frame pin.',
        );
        expect(
          painted.first['viewport_bottom'],
          closeTo(673.5237298266586, .01),
        );
        expect(find.byKey(const ValueKey('chat-jump-to-latest')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.controller.dispose();
      }
    },
  );

  for (final (direction, reducedMotion) in [
    (TextDirection.ltr, false),
    (TextDirection.rtl, true),
    (TextDirection.ltr, true),
  ]) {
    testWidgets(
      'first painted shrink and grow stays readable $direction reduced=$reducedMotion 2x',
      (tester) async {
        final harness = await _mount(
          tester,
          reducedMotion: reducedMotion,
          direction: direction,
        );
        try {
          await _settleReply(tester, harness);
          for (final (height, phase) in [
            (_smallHeight, 'shrink'),
            (_largeHeight, 'grow'),
          ]) {
            harness.resize(height, phase);
            await tester.pump();
            final painted = harness.frames
                .where((frame) => frame['phase'] == phase)
                .first;
            expect(painted['reply_opacity'], 1.0);
            expect(
              painted['first_glyphs_visible_area'] as double,
              greaterThan(0),
            );
            expect(painted['jump_button_count'], 0);
            expect((painted['scroll_pixels'] as double).isFinite, isTrue);
            expect(harness.controller.position.outOfRange, isFalse);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          harness.controller.dispose();
        }
      },
    );
  }

  testWidgets(
    'grow-to-fit is already at min on the first paint, then short/long turns keep their reading start',
    (tester) async {
      final harness = await _mount(
        tester,
        reducedMotion: true,
        paragraphs: 2,
        initialHeight: 100,
      );
      try {
        await _settleReply(tester, harness);
        expect(harness.replyHeight, greaterThan(100));
        expect(harness.replyHeight, lessThan(_largeHeight));
        harness.resize(_largeHeight, 'grow-to-fit');
        await tester.pump();
        final fitted = harness.frames
            .where((frame) => frame['phase'] == 'grow-to-fit')
            .first;
        expect(fitted['reply_opacity'], 1.0);
        expect(
          fitted['scroll_pixels'] as double,
          closeTo(fitted['min_scroll_extent'] as double, .5),
        );
        expect(fitted['first_glyphs_visible_area'] as double, greaterThan(0));
        expect(fitted['jump_button_count'], 0);
        expect(harness.controller.position.outOfRange, isFalse);
        for (final count in [18, 1]) {
          harness.replaceReply(count);
          await tester.pump();
          await tester.pumpAndSettle();
          expect(
            harness.controller.offset,
            closeTo(harness.latestTarget(harness.controller.position), .5),
          );
          expect(
            harness.frames.last['first_glyphs_visible_area'] as double,
            greaterThan(0),
          );
          expect(harness.controller.position.outOfRange, isFalse);
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.controller.dispose();
      }
    },
  );

  testWidgets(
    'active near-threshold drag and older-history reading are not repinned on resize',
    (tester) async {
      final harness = await _mount(tester, reducedMotion: false);
      try {
        await _settleReply(tester, harness);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(harness.viewportKey)),
        );
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump(const Duration(milliseconds: 16));
        }
        final dragged = harness.controller.offset;
        expect(
          (dragged - harness.latestTarget(harness.controller.position)).abs(),
          inExclusiveRange(0, 72),
        );
        harness.resize(_smallHeight, 'active-drag');
        await tester.pump();
        expect(harness.controller.offset, closeTo(dragged, .5));
        expect(harness.controller.position.isScrollingNotifier.value, isTrue);
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(0, 12));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        final older = harness.controller.offset;
        expect(
          (older - harness.latestTarget(harness.controller.position)).abs(),
          greaterThan(72),
        );
        harness.resize(_largeHeight, 'older-history');
        await tester.pump();
        expect(harness.controller.offset, closeTo(older, .5));
        expect(
          find.byKey(const ValueKey('chat-jump-to-latest')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.controller.dispose();
      }
    },
  );

  for (final customLatestRequest in [false, true]) {
    testWidgets(
      'resize cannot cancel latest-request animateTo custom=$customLatestRequest',
      (tester) async {
        final harness = await _mount(
          tester,
          reducedMotion: false,
          customLatestRequest: customLatestRequest,
        );
        try {
          await _settleReply(tester, harness);
          await tester.drag(
            find.byKey(harness.viewportKey),
            const Offset(0, 240),
          );
          await tester.pumpAndSettle();
          final jump = find.byKey(const ValueKey('chat-jump-to-latest'));
          expect(jump, findsOneWidget);
          await tester.tap(jump);
          await tester.pump(const Duration(milliseconds: 16));
          harness.resize(_smallHeight, 'programmatic-jump');
          await tester.pump(const Duration(milliseconds: 16));
          expect(harness.controller.position.isScrollingNotifier.value, isTrue);
          await tester.pumpAndSettle();
          expect(harness.controller.offset.isFinite, isTrue);
          expect(harness.controller.position.outOfRange, isFalse);
          if (customLatestRequest) {
            expect(harness.latestRequests, 1);
            expect(harness.latestAnimationFinished, isTrue);
            expect(
              harness.controller.offset,
              closeTo(harness.latestTarget(harness.controller.position), .5),
            );
          } else {
            expect(
              harness.controller.offset,
              closeTo(harness.latestTarget(harness.controller.position), .5),
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          harness.controller.dispose();
        }
      },
    );
  }

  testWidgets(
    'a replacement controller cannot inherit the previous viewport correction',
    (tester) async {
      final harness = await _mount(tester, reducedMotion: true);
      ScrollController? retired;
      try {
        await _settleReply(tester, harness);
        retired = harness.replaceControllerAndResize();
        await tester.pump();
        await tester.pumpAndSettle();
        expect(harness.controller.offset.isFinite, isTrue);
        expect(harness.controller.position.outOfRange, isFalse);
        expect(
          harness.controller.offset,
          closeTo(harness.latestTarget(harness.controller.position), .5),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.controller.dispose();
        retired?.dispose();
      }
    },
  );
}

Future<_HarnessState> _mount(
  WidgetTester tester, {
  required bool reducedMotion,
  TextDirection direction = TextDirection.rtl,
  int paragraphs = 18,
  double initialHeight = _largeHeight,
  bool customLatestRequest = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2337);
  tester.view.devicePixelRatio = 2.625;
  tester.view.viewInsets = const FakeViewPadding(bottom: 100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(2),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Directionality(
          textDirection: direction,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: _top),
              child: SizedBox(
                width: 1080 / 2.625,
                height: _largeHeight,
                child: _Harness(
                  key: key,
                  visit: ++_visit,
                  direction: direction,
                  paragraphs: paragraphs,
                  initialHeight: initialHeight,
                  customLatestRequest: customLatestRequest,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

Future<void> _settleReply(WidgetTester tester, _HarnessState harness) async {
  harness.appendReply();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 360));
  await tester.pumpAndSettle();
  harness.controller.jumpTo(harness.latestTarget(harness.controller.position));
  await tester.pumpAndSettle();
}

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.visit,
    required this.direction,
    required this.paragraphs,
    required this.initialHeight,
    required this.customLatestRequest,
  });
  final int visit;
  final TextDirection direction;
  final int paragraphs;
  final double initialHeight;
  final bool customLatestRequest;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  var controller = ScrollController();
  final viewportKey = GlobalKey();
  final readingKey = GlobalKey();
  final replyKey = GlobalKey();
  final repaintKey = GlobalKey();
  final frames = <Map<String, Object?>>[];
  var hasReply = false;
  late var bottomExtent = _largeHeight - widget.initialHeight;
  late var paragraphCount = widget.paragraphs;
  var replyRevision = 0;
  var latestRequests = 0;
  var latestAnimationFinished = false;
  var phase = 'initial';
  String get messageId =>
      'first-frame-regression-${widget.visit}-$replyRevision';
  String get reply => List.generate(
    paragraphCount,
    (index) => widget.direction == TextDirection.rtl
        ? 'فقرة تركيبية $index: هذه قراءة محلية واضحة لا تحفظ طعامًا ولا تغيّر حسابًا.'
        : 'Synthetic paragraph $index: local reading does not log food or change an account.',
  ).join('\n');
  double get replyHeight =>
      (replyKey.currentContext!.findRenderObject()! as RenderBox).size.height;

  void appendReply() => setState(() => hasReply = true);
  void restoreNavigation() => resize(_smallHeight, 'restore-nav');
  void resize(double height, String label) => setState(() {
    phase = label;
    bottomExtent = _largeHeight - height;
  });
  void replaceReply(int count) => setState(() {
    paragraphCount = count;
    replyRevision++;
  });
  ScrollController replaceControllerAndResize() {
    final old = controller;
    setState(() {
      controller = ScrollController();
      bottomExtent = _largeHeight - _smallHeight;
    });
    return old;
  }

  double latestTarget(ScrollPosition position) {
    // Production places its reading anchor outside the arrival transform.
    final render = readingKey.currentContext?.findRenderObject();
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

  void _recordPaint() {
    if (!hasReply) return;
    final arrivals = find
        .byKey(ValueKey('coach-reply-arrival-fade-$messageId'))
        .evaluate();
    if (arrivals.length != 1) return;
    final arrival = arrivals.single.widget as FadeTransition;
    if (arrival.opacity.value <= 0) return;
    final viewport =
        viewportKey.currentContext!.findRenderObject()! as RenderBox;
    final viewportRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    final editable = find
        .descendant(
          of: find.byKey(replyKey),
          matching: find.byType(EditableText),
        )
        .evaluate()
        .single;
    final render = ((editable as StatefulElement).state as EditableTextState)
        .renderEditable;
    final count = reply.characters.take(8).join().length;
    var area = 0.0;
    final boxes = <List<double>>[];
    for (final box in render.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: count),
    )) {
      final global = box.toRect().shift(render.localToGlobal(Offset.zero));
      boxes.add([global.left, global.top, global.width, global.height]);
      final overlap = global.intersect(viewportRect);
      if (overlap.width > 0 && overlap.height > 0) {
        area += overlap.width * overlap.height;
      }
    }
    frames.add({
      'phase': phase,
      'observation':
          'actual viewport paint with composed glyph layer, before post-frame pin',
      'viewport_top': viewportRect.top,
      'viewport_bottom': viewportRect.bottom,
      'scroll_pixels': controller.offset,
      'min_scroll_extent': controller.position.minScrollExtent,
      'max_scroll_extent': controller.position.maxScrollExtent,
      'reply_opacity': arrival.opacity.value,
      'message_height': replyHeight,
      'first_glyph_global_rects': boxes,
      'first_glyphs_visible_area': area,
      'jump_button_count': find
          .byKey(const ValueKey('chat-jump-to-latest'))
          .evaluate()
          .length,
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: _EvidenceBoundary(
          key: repaintKey,
          child: _PaintProbe(
            onPaint: _recordPaint,
            child: ChatHistoryViewport(
              key: viewportKey,
              controller: controller,
              latestMessageId: hasReply ? messageId : 'user',
              latestTargetOffset: latestTarget,
              onLatestRequested: !widget.customLatestRequest
                  ? null
                  : () {
                      latestRequests++;
                      unawaited(
                        controller
                            .animateTo(
                              latestTarget(controller.position),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            )
                            .whenComplete(() => latestAnimationFinished = true),
                      );
                    },
              child: CoachAnchoredHistory(
                controller: controller,
                rowIds: ['user', if (hasReply) messageId],
                itemBuilder: (_, index) => index == 0
                    ? const SizedBox(
                        height: 80,
                        child: Text('رسالة مستخدم محلية'),
                      )
                    : KeyedSubtree(
                        key: readingKey,
                        child: CoachReplyArrival(
                          messageId: messageId,
                          animate: true,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(13),
                            child: CoachMessageText(
                              key: replyKey,
                              text: reply,
                              createdAt: DateTime(2026),
                              textDirection: widget.direction,
                              style: TextStyle(
                                // Same bodyMedium + 1 / 1.45 typography contract
                                // used by _coachConversationBodyStyle.
                                fontSize:
                                    (Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.fontSize ??
                                        14) +
                                    1,
                                height: 1.45,
                                fontFamily:
                                    widget.direction == TextDirection.rtl
                                    ? 'BILArabic'
                                    : 'BILDisplay',
                                color: Colors.black,
                              ),
                              showTime: false,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      if (bottomExtent > 0) SizedBox(height: bottomExtent),
    ],
  );
}

class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintObserver(onPaint);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _PaintObserver renderObject,
  ) => renderObject.onPaint = onPaint;
}

class _PaintObserver extends RenderProxyBox {
  _PaintObserver(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}

class _EvidenceBoundary extends SingleChildRenderObjectWidget {
  const _EvidenceBoundary({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _EvidenceRenderBoundary();
}

class _EvidenceRenderBoundary extends RenderRepaintBoundary {
  // Capture the already painted layer, even if the old post-frame pin has
  // marked the next layout dirty. This never pumps a replacement frame.
  Future<ui.Image> captureLastPaintedImage() =>
      (layer! as OffsetLayer).toImage(Offset.zero & size, pixelRatio: 1);
}

Future<void> _saveEvidence(
  WidgetTester tester,
  _HarnessState harness,
  String name,
) async {
  final directory = Platform.environment['BIL_CHAT_VIEWPORT_EVIDENCE_DIR'];
  if (directory == null) return;
  final tag =
      Platform.environment['BIL_CHAT_VIEWPORT_EVIDENCE_TAG'] ?? 'observed';
  final output = Directory(directory)..createSync(recursive: true);
  File('${output.path}/$tag-$name.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(harness.frames),
  );
  final boundary =
      harness.repaintKey.currentContext!.findRenderObject()!
          as _EvidenceRenderBoundary;
  await tester.runAsync(() async {
    final image = await boundary.captureLastPaintedImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${output.path}/$tag-$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
