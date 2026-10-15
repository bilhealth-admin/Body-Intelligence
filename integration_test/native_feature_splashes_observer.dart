part of 'native_feature_splashes_test.dart';

Finder _replyRow(String text) => find.byWidgetPredicate(
  (widget) => widget is CoachMessageText && widget.text == text,
);

// Post-frame observers run while tester.pump is guarded. Read actual render
// objects directly instead of calling guarded WidgetController geometry APIs.
Rect _nativeRect(Finder finder) {
  final render = finder.evaluate().single.findRenderObject()! as RenderBox;
  return render.localToGlobal(Offset.zero) & render.size;
}

Map<String, Object?> nativeQaReplyGeometry(
  WidgetTester tester,
  String reply,
  Stopwatch watch, {
  Finder? anchor,
}) {
  final sample = <String, Object?>{'observed_at_ms': watch.elapsedMilliseconds};
  final viewport = find.byType(ChatHistoryViewport);
  if (viewport.evaluate().length != 1) {
    return sample..['viewport_present'] = false;
  }
  final rect = _nativeRect(viewport);
  final controller =
      (viewport.evaluate().single.widget as ChatHistoryViewport).controller;
  sample.addAll({
    'viewport_present': true,
    'scroll_pixels': controller.offset,
    'viewport_top': rect.top,
    'viewport_bottom': rect.bottom,
  });
  if (anchor != null && anchor.evaluate().length == 1) {
    sample['history_anchor_top'] = _nativeRect(anchor).top;
  }
  final row = _replyRow(reply);
  sample['reply_row_present'] = row.evaluate().length == 1;
  if (row.evaluate().length != 1) return sample;
  sample['message_height'] = _nativeRect(row).height;
  final arrival = find.ancestor(
    of: row,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is FadeTransition &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'coach-reply-arrival-fade-',
          ),
    ),
  );
  sample['arrival_present'] = arrival.evaluate().length == 1;
  sample['reply_opacity'] = arrival.evaluate().length == 1
      ? (arrival.evaluate().single.widget as FadeTransition).opacity.value
      : 1.0;
  final selectable = find.descendant(
    of: row,
    matching: find.byType(SelectableText),
  );
  final editable = find.descendant(
    of: row,
    matching: find.byType(EditableText),
  );
  if (selectable.evaluate().length != 1 || editable.evaluate().length != 1) {
    return sample;
  }
  final text =
      (selectable.evaluate().single.widget as SelectableText).data ?? '';
  sample['visible_graphemes'] = text.characters.length;
  final render =
      ((editable.evaluate().single as StatefulElement).state
              as EditableTextState)
          .renderEditable;
  final length = text.characters
      .take(8)
      .join()
      .length; // selection offsets are UTF16.
  var area = 0.0;
  if (length > 0) {
    for (final box in render.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
    )) {
      final global = box.toRect().shift(render.localToGlobal(Offset.zero));
      final overlap = global.intersect(rect);
      if (overlap.width > 0 && overlap.height > 0) {
        area += overlap.width * overlap.height;
      }
    }
  }
  sample['first_glyphs_visible_area'] = area;
  return sample;
}

// Idle scroll metrics can precede the end of Android's overscroll stretch.
// Wait for painted geometry as well, before releasing the held model reply.
Future<void> _settleHistoryAnchor(WidgetTester tester, Finder anchor) async {
  final viewport = find.byType(ChatHistoryViewport);
  final controller = tester.widget<ChatHistoryViewport>(viewport).controller;
  final watch = Stopwatch()..start();
  double? previousTop, previousOffset;
  var stable = 0;
  while (watch.elapsedMilliseconds < 3500 && stable < 8) {
    await tester.pump(const Duration(milliseconds: 16));
    final top = tester.getTopLeft(anchor).dy;
    final offset = controller.offset;
    if (!controller.position.isScrollingNotifier.value &&
        previousTop != null &&
        (top - previousTop).abs() < .1 &&
        previousOffset != null &&
        (offset - previousOffset).abs() < .1) {
      stable++;
    } else {
      stable = 0;
    }
    previousTop = top;
    previousOffset = offset;
  }
  expect(
    stable,
    8,
    reason: 'History must settle before the reply is released.',
  );
}

class _NativeReplyFrameTrace {
  _NativeReplyFrameTrace(this.tester, this.reply, {this.anchor});
  final WidgetTester tester;
  final String reply;
  final Finder? anchor;
  final Stopwatch watch = Stopwatch();
  final samples = <Map<String, Object?>>[];
  final nativeTimings = <Map<String, Object?>>[];
  bool active = false;
  void _timings(List<ui.FrameTiming> values) {
    if (!active || nativeTimings.length >= 500) return;
    for (final value in values) {
      nativeTimings.add({
        'build_us': value.buildDuration.inMicroseconds,
        'raster_us': value.rasterDuration.inMicroseconds,
        'total_us': value.totalSpan.inMicroseconds,
        'raster_finish_us': value.timestampInMicroseconds(
          ui.FramePhase.rasterFinish,
        ),
      });
    }
  }

  void start() {
    active = true;
    watch.start();
    WidgetsBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback(_sample);
  }

  void _sample(Duration _) {
    if (!active) return;
    if (samples.length < 500) {
      samples.add(nativeQaReplyGeometry(tester, reply, watch, anchor: anchor));
    }
    // Observe actual native frames. This callback does not schedule extra frames.
    WidgetsBinding.instance.addPostFrameCallback(_sample);
  }

  void stop() {
    active = false;
    watch.stop();
    WidgetsBinding.instance.removeTimingsCallback(_timings);
  }
}
