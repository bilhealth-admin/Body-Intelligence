part of 'native_feature_splashes_test.dart';

Finder _replyRow(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is CoachMessageText && widget.text == text ||
      widget is CoachNativeMarkdown && widget.text == text,
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
  final draftFlight = find.byKey(const ValueKey('coach-sent-message-flight'));
  if (draftFlight.evaluate().length == 1) {
    final draftClip = find.byKey(
      const ValueKey('coach-sent-message-flight-clip'),
    );
    expect(draftClip, findsOneWidget);
    final clip = _nativeRect(draftClip);
    expect(
      clip.top,
      greaterThanOrEqualTo(rect.top - .5),
      reason: 'The draft flight must never paint over the conversation header.',
    );
    sample['draft_flight_clip_top'] = clip.top;
    sample['draft_flight_clip_bottom'] = clip.bottom;
  }
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
  final rowElement = row.evaluate().single;
  if (rowElement.widget is CoachNativeMarkdown) {
    final native =
        (rowElement as StatefulElement).state as CoachNativeMarkdownState;
    sample['renderer'] = 'native_swiftui';
    sample['native_layout_ready'] = native.nativeLayoutReady;
    sample['native_height_ready'] = native.nativeHeightReady;
    sample['native_paint_gate_scheduled'] = native.nativePaintGateScheduled;
    sample['native_measured_height'] = native.nativeMeasuredHeight;
    sample['arrival_opacity'] = sample['reply_opacity'];
    final firstBlock = native.nativeFirstContentBounds;
    sample['native_first_block'] = firstBlock == null
        ? null
        : [
            firstBlock.left,
            firstBlock.top,
            firstBlock.width,
            firstBlock.height,
          ];
    if (!native.nativeLayoutReady || native.nativeFirstContentBounds == null) {
      sample['reply_opacity'] = 0.0;
      sample['visible_graphemes'] = 0;
      sample['first_content_visible_area'] = 0.0;
      return sample;
    }
    sample['visible_graphemes'] = reply.characters.length;
    final bounds = native.nativeFirstContentBounds!.shift(
      _nativeRect(row).topLeft,
    );
    final overlap = bounds.intersect(rect);
    sample['first_content_visible_area'] =
        overlap.width > 0 && overlap.height > 0
        ? overlap.width * overlap.height
        : 0.0;
    sample['content_geometry_basis'] =
        'actual SwiftUI first block layout, not a glyph-pixel claim';
    return sample;
  }
  sample['renderer'] = 'flutter_selectable_text';
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
Map<String, Object?> _historyNativeStateSummary() {
  // Read existing state only: no layout, visibility ack, update or frame request.
  try {
    final rows = <Map<String, Object?>>[];
    for (final element in find.byType(CoachNativeMarkdown).evaluate()) {
      final widget = element.widget as CoachNativeMarkdown;
      final state =
          (element as StatefulElement).state as CoachNativeMarkdownState;
      final render = element.findRenderObject();
      rows.add({
        'key': widget.key.toString(),
        'state_identity': identityHashCode(state),
        'mounted': state.mounted,
        'height_ready': state.nativeHeightReady,
        'layout_ready': state.nativeLayoutReady,
        'paint_gate_scheduled': state.nativePaintGateScheduled,
        'measured_height': state.nativeMeasuredHeight,
        'first_content_bounds_present': state.nativeFirstContentBounds != null,
        'render_attached': render?.attached,
        if (render is RenderBox && render.attached && render.hasSize)
          'render_height': render.size.height,
      });
    }
    return {'mounted_rows': rows};
  } catch (error) {
    // Diagnostic inspection must not replace the original test error.
    return {'observer_error_type': error.runtimeType.toString()};
  }
}

Map<String, Object?> _historyViewportStateSummary(
  WidgetTester tester,
  Finder viewport,
) {
  try {
    final element = viewport.evaluate().single;
    final rectangle = _nativeRect(viewport);
    final media = element.getInheritedWidgetOfExactType<MediaQuery>()?.data;
    return {
      'viewport_top': rectangle.top,
      'viewport_bottom': rectangle.bottom,
      'viewport_height': rectangle.height,
      'view_insets_bottom_physical': tester.view.viewInsets.bottom,
      'view_padding_bottom_physical': tester.view.viewPadding.bottom,
      'physical_height': tester.view.physicalSize.height,
      'device_pixel_ratio': tester.view.devicePixelRatio,
      'media_query_insets_bottom': media?.viewInsets.bottom,
      'media_query_padding_bottom': media?.viewPadding.bottom,
      'primary_focus_has_focus': FocusManager.instance.primaryFocus?.hasFocus,
      'scheduled_frame': tester.binding.hasScheduledFrame,
      'transient_callbacks': tester.binding.transientCallbackCount,
    };
  } catch (error) {
    return {'observer_error_type': error.runtimeType.toString()};
  }
}

Future<void> _settleHistoryAnchor(
  WidgetTester tester,
  Finder anchor,
  Map<String, Object?> metadata,
) async {
  final viewport = find.byType(ChatHistoryViewport);
  final controller = tester.widget<ChatHistoryViewport>(viewport).controller;
  final watch = Stopwatch()..start();
  final samples = <Map<String, Object?>>[];
  final diagnostic = <String, Object?>{
    'scope': 'read-only completed-pump observations, not native frame counts',
    'wall_deadline_ms': 3500,
    'required_consecutive_samples': 8,
    'maximum_delta_exclusive': .1,
    'anchor': anchor.toString(),
    'samples': samples,
    'completed': false,
  };
  metadata['history_anchor_settle'] = diagnostic;
  double? previousTop, previousOffset;
  var stable = 0;
  try {
    while (watch.elapsedMilliseconds < 3500 && stable < 8) {
      final sample = <String, Object?>{
        'index': samples.length,
        'iteration_start_us': watch.elapsedMicroseconds,
        'stable_before': stable,
        'scrolling_before': controller.position.isScrollingNotifier.value,
        'completed_pump': false,
      };
      samples.add(sample);
      final beforeObserver = watch.elapsedMicroseconds;
      sample['native_before'] = _historyNativeStateSummary();
      sample['viewport_before'] = _historyViewportStateSummary(
        tester,
        viewport,
      );
      sample['before_observer_wall_us'] =
          watch.elapsedMicroseconds - beforeObserver;
      sample['before_pump_us'] = watch.elapsedMicroseconds;
      try {
        await tester.pump(const Duration(milliseconds: 16));
        sample['completed_pump'] = true;
      } catch (error) {
        sample['pump_error_type'] = error.runtimeType.toString();
        rethrow;
      } finally {
        sample['after_pump_us'] = watch.elapsedMicroseconds;
        sample['pump_wall_us'] =
            watch.elapsedMicroseconds - (sample['before_pump_us'] as int);
      }
      final top = tester.getTopLeft(anchor).dy;
      final offset = controller.offset;
      final scrolling = controller.position.isScrollingNotifier.value;
      if (!scrolling &&
          previousTop != null &&
          (top - previousTop).abs() < .1 &&
          previousOffset != null &&
          (offset - previousOffset).abs() < .1) {
        stable++;
      } else {
        stable = 0;
      }
      sample.addAll({
        'top': top,
        'top_delta': previousTop == null ? null : top - previousTop,
        'offset': offset,
        'offset_delta': previousOffset == null ? null : offset - previousOffset,
        'scrolling_after': scrolling,
        'stable_after': stable,
        'scroll_activity': controller.position.toString(),
        'after_measure_us': watch.elapsedMicroseconds,
      });
      previousTop = top;
      previousOffset = offset;
      final afterObserver = watch.elapsedMicroseconds;
      sample['native_after'] = _historyNativeStateSummary();
      sample['viewport_after'] = _historyViewportStateSummary(tester, viewport);
      sample['after_observer_wall_us'] =
          watch.elapsedMicroseconds - afterObserver;
      sample['iteration_end_us'] = watch.elapsedMicroseconds;
    }
    expect(
      stable,
      8,
      reason: 'History must settle before the reply is released.',
    );
    diagnostic['completed'] = true;
  } catch (error) {
    diagnostic['error_type'] = error.runtimeType.toString();
    rethrow;
  } finally {
    diagnostic['elapsed_us'] = watch.elapsedMicroseconds;
    diagnostic['stable_at_exit'] = stable;
    diagnostic['completed_pumps'] = samples
        .where((sample) => sample['completed_pump'] == true)
        .length;
  }
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
