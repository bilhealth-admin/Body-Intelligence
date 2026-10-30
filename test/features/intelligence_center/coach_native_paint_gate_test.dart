import 'dart:async';

import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_native_markdown.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_native_paint_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercises the production frame/geometry/ack gate with real Flutter layout.
// The controlled acknowledgement is a host transport fixture, not UIKit proof.
void main() {
  testWidgets('complete body is reserved before the first native ack request', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    final ack = Completer<bool?>();
    fixture.native = (_, visible) async => visible ? ack.future : true;
    fixture.schedule();
    expect(fixture.calls, isEmpty);
    expect(fixture.box.size, fixture.expected);
    await tester.pump();
    expect(fixture.calls, [(0, true)]);
    expect(fixture.gate.stage, 'native_ack');
    expect(fixture.gate.scheduled, isTrue);
    expect(fixture.ready.value, isFalse);
    expect(fixture.box.size, const Size(300, 900));
    await tester.tapAt(const Offset(30, 30));
    expect(fixture.taps, 0);
    ack.complete(true);
    await tester.pump();
    expect(fixture.ready.value, isTrue);
    expect(fixture.gate.stage, 'ready');
    expect(fixture.gate.scheduled, isFalse);
    await tester.pump(); // Paint the input/semantics readiness rebuild.
    await tester.tapAt(const Offset(30, 30));
    expect(fixture.taps, 1);
    await fixture.close(tester);
  });

  testWidgets('an unreserved height waits for actual layout, not two frames', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(
      tester,
      allocated: const Size(300, 60),
    );
    fixture.schedule();
    await tester.pump();
    await tester.pump();
    expect(fixture.calls, isEmpty);
    expect(fixture.gate.stage, 'layout_wait');
    expect(fixture.gate.scheduled, isTrue);
    fixture.allocated.value = fixture.expected;
    await tester.pump();
    expect(fixture.calls, [(0, true)]);
    expect(fixture.ready.value, isTrue);
    expect(fixture.box.size, fixture.expected);
    await fixture.close(tester);
  });

  testWidgets('width changes must also reach the real render box', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    fixture.expected = const Size(240, 900);
    fixture.schedule();
    await tester.pump();
    expect(fixture.calls, isEmpty);
    fixture.allocated.value = fixture.expected;
    await tester.pump();
    expect(fixture.calls, [(0, true)]);
    expect(fixture.ready.value, isTrue);
    await fixture.close(tester);
  });

  testWidgets('a rejected native ack never opens input or readiness', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    fixture.native = (_, _) async => false;
    fixture.schedule();
    await tester.pump();
    expect(fixture.calls, [(0, true)]);
    expect(fixture.ready.value, isFalse);
    expect(fixture.gate.stage, 'rejected');
    expect(fixture.gate.scheduled, isFalse);
    await tester.tapAt(const Offset(30, 30));
    expect(fixture.taps, 0);
    await fixture.close(tester);
  });

  testWidgets('withdrawal before layout sends no native visibility request', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    fixture.schedule();
    fixture.current = false;
    await tester.pump();
    expect(fixture.calls, isEmpty);
    expect(fixture.ready.value, isFalse);
    expect(fixture.gate.stage, 'retired');
    expect(fixture.gate.scheduled, isFalse);
    await fixture.close(tester);
  });

  testWidgets('withdrawal during native ack compensates by hiding', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    final ack = Completer<bool?>();
    fixture.native = (_, visible) async => visible ? ack.future : true;
    fixture.schedule();
    await tester.pump();
    fixture.current = false;
    ack.complete(true);
    await tester.pump();
    expect(fixture.calls, [(0, true), (0, false)]);
    expect(fixture.ready.value, isFalse);
    expect(fixture.gate.stage, 'retired');
    expect(fixture.gate.scheduled, isFalse);
    await fixture.close(tester);
  });

  testWidgets('old-generation ack hides only that request before the new one', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    final oldAck = Completer<bool?>();
    final newAck = Completer<bool?>();
    fixture.native = (generation, visible) async =>
        !visible ? true : (generation == 0 ? oldAck.future : newAck.future);
    fixture.onComplete = () {
      if (fixture.generation == 1 && fixture.current && !fixture.ready.value) {
        fixture.schedule();
      }
    };
    fixture.schedule();
    await tester.pump();
    fixture.generation = 1;
    fixture.schedule(); // One request remains in flight until its ack retires.
    expect(fixture.calls, [(0, true)]);
    oldAck.complete(true);
    await tester.pump();
    await tester.pump(); // The next generation owns its next layout callback.
    expect(fixture.calls, [(0, true), (0, false), (1, true)]);
    expect(fixture.ready.value, isFalse);
    fixture.onComplete = null;
    newAck.complete(true);
    await tester.pump();
    expect(fixture.ready.value, isTrue);
    expect(fixture.readyCount, 1);
    await fixture.close(tester);
  });

  testWidgets('geometry changed during ack is hidden and laid out again', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    final firstAck = Completer<bool?>();
    var shows = 0;
    fixture.native = (_, visible) async =>
        visible && ++shows == 1 ? firstAck.future : true;
    fixture.schedule();
    await tester.pump();
    fixture.expected = const Size(300, 1000);
    firstAck.complete(true);
    await tester.pump();
    expect(fixture.calls, [(0, true), (0, false)]);
    expect(fixture.ready.value, isFalse);
    expect(fixture.gate.stage, 'layout_wait');
    fixture.allocated.value = fixture.expected;
    await tester.pump();
    expect(fixture.calls, [(0, true), (0, false), (0, true)]);
    expect(fixture.ready.value, isTrue);
    expect(fixture.readyCount, 1);
    await fixture.close(tester);
  });

  for (final error in [
    PlatformException(code: 'qa-native-failure'),
    MissingPluginException('qa-missing-native'),
  ]) {
    testWidgets('${error.runtimeType} keeps the existing fallback signal', (
      tester,
    ) async {
      final fixture = await _PaintFixture.mount(tester);
      fixture.native = (_, _) async => throw error;
      fixture.schedule();
      await tester.pump();
      expect(fixture.failures, 1);
      expect(fixture.ready.value, isFalse);
      expect(fixture.gate.stage, 'failed');
      expect(fixture.gate.scheduled, isFalse);
      await fixture.close(tester);
    });

    testWidgets('late ${error.runtimeType} cannot fail the new generation', (
      tester,
    ) async {
      final fixture = await _PaintFixture.mount(tester);
      final oldAck = Completer<bool?>();
      fixture.native = (generation, _) async =>
          generation == 0 ? oldAck.future : true;
      fixture.onComplete = () {
        if (fixture.generation == 1 &&
            fixture.current &&
            !fixture.ready.value) {
          fixture.schedule();
        }
      };
      fixture.schedule();
      await tester.pump();
      fixture.generation = 1;
      oldAck.completeError(error);
      await tester.pump();
      fixture.onComplete = null;
      await tester.pump();
      expect(fixture.calls, [(0, true), (1, true)]);
      expect(fixture.failures, 0);
      expect(fixture.ready.value, isTrue);
      await fixture.close(tester);
    });

    testWidgets('late ${error.runtimeType} respects a withdrawn visit', (
      tester,
    ) async {
      final fixture = await _PaintFixture.mount(tester);
      final ack = Completer<bool?>();
      fixture.native = (_, _) => ack.future;
      fixture.schedule();
      await tester.pump();
      fixture.current = false;
      ack.completeError(error);
      await tester.pump();
      expect(fixture.calls, [(0, true)]);
      expect(fixture.failures, 0);
      expect(fixture.ready.value, isFalse);
      expect(fixture.gate.stage, 'retired');
      await fixture.close(tester);
    });
  }

  testWidgets('failed compensating hide cannot poison a newer generation', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    final oldAck = Completer<bool?>();
    fixture.native = (generation, visible) async {
      if (generation == 1) return true;
      if (visible) return oldAck.future;
      throw PlatformException(code: 'qa-old-hide-failure');
    };
    fixture.onComplete = () {
      if (fixture.generation == 1 && fixture.current && !fixture.ready.value) {
        fixture.schedule();
      }
    };
    fixture.schedule();
    await tester.pump();
    fixture.generation = 1;
    oldAck.complete(true);
    await tester.pump();
    fixture.onComplete = null;
    await tester.pump();
    expect(fixture.calls, [(0, true), (0, false), (1, true)]);
    expect(fixture.failures, 0);
    expect(fixture.ready.value, isTrue);
    await fixture.close(tester);
  });

  testWidgets('second generation retains the three-second fallback and idles', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(tester);
    fixture.schedule();
    await tester.pump();
    expect(fixture.ready.value, isTrue);
    fixture.generation++;
    fixture.ready.value = false;
    fixture.expected = const Size(300, 1000);
    fixture.schedule();
    await tester.pump();
    expect(fixture.gate.stage, 'layout_wait');
    expect(fixture.calls, [(0, true)]);
    await tester.pump(const Duration(seconds: 3));
    expect(fixture.failures, 1);
    expect(fixture.ready.value, isFalse);
    expect(fixture.gate.scheduled, isFalse);
    expect(fixture.gate.stage, 'failed');
    expect(tester.binding.hasScheduledFrame, isFalse);
    await fixture.close(tester);
  });

  testWidgets('geometry replay does not extend the same-generation deadline', (
    tester,
  ) async {
    final fixture = await _PaintFixture.mount(
      tester,
      allocated: const Size(300, 60),
    );
    fixture.schedule();
    await tester.pump(const Duration(seconds: 2));
    fixture.schedule();
    await tester.pump(const Duration(seconds: 1));
    expect(fixture.failures, 1);
    expect(fixture.calls, isEmpty);
    expect(fixture.gate.scheduled, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await fixture.close(tester);
  });

  testWidgets(
    'detached surface is not accepted and retirement stops deferral',
    (tester) async {
      final fixture = await _PaintFixture.mount(tester);
      final detached = fixture.box;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(detached.attached, isFalse);
      fixture.surface = () => detached;
      fixture.schedule();
      await tester.pump();
      expect(fixture.calls, isEmpty);
      fixture.current = false;
      await tester.pump();
      expect(fixture.gate.scheduled, isFalse);
      expect(fixture.gate.stage, 'retired');
      await fixture.close(tester);
    },
  );
}

class _PaintFixture {
  final gate = CoachNativePaintGate();
  final surfaceKey = GlobalKey();
  final ready = ValueNotifier(false);
  final allocated = ValueNotifier(const Size(300, 900));
  Size expected = const Size(300, 900);
  bool current = true;
  bool failed = false;
  bool _closed = false;
  int generation = 0;
  int taps = 0;
  int readyCount = 0;
  int failures = 0;
  final calls = <(int, bool)>[];
  VoidCallback? onComplete;
  RenderObject? Function()? surface;
  Future<bool?> Function(int generation, bool visible) native = (_, _) async =>
      true;

  RenderBox get box =>
      surfaceKey.currentContext!.findRenderObject()! as RenderBox;

  static Future<_PaintFixture> mount(
    WidgetTester tester, {
    Size allocated = const Size(300, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _PaintFixture()..allocated.value = allocated;
    addTearDown(() => fixture.close(tester));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<Size>(
            valueListenable: fixture.allocated,
            builder: (_, size, _) => SizedBox(
              width: size.width,
              child: ValueListenableBuilder<bool>(
                valueListenable: fixture.ready,
                builder: (_, ready, _) => CoachNativeMarkdownSurface(
                  key: fixture.surfaceKey,
                  height: size.height,
                  ready: ready,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => fixture.taps++,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return fixture;
  }

  void schedule() {
    final token = generation;
    gate.beginLayout(
      generation: token,
      isCurrent: () =>
          current && generation == token && !failed && !ready.value,
      onFailure: () {
        failures++;
        failed = true;
      },
    );
    gate.schedule(
      isCurrent: () => current && generation == token && !failed,
      measuredSize: () => expected,
      surface: () =>
          surface?.call() ?? surfaceKey.currentContext?.findRenderObject(),
      setVisible: (visible) {
        calls.add((token, visible));
        return native(token, visible);
      },
      onReady: () {
        readyCount++;
        ready.value = true;
      },
      onFailure: () {
        failures++;
        failed = true;
      },
      onComplete: () => onComplete?.call(),
    );
  }

  Future<void> close(WidgetTester tester) async {
    if (_closed) return;
    _closed = true;
    current = false;
    gate.dispose();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    ready.dispose();
    allocated.dispose();
    expect(tester.takeException(), isNull);
  }
}
