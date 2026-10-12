import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final _frameCounts = <String, int>{};

/// Optional evidence recording from painted Flutter frames, never reconstructed
/// HTML or generated UI. The video time is the test's pumped frame clock, not
/// device/network latency. Each session owns a separate numbered PNG sequence.
Future<void> captureClosureFrames(
  WidgetTester tester,
  Finder surface,
  String session, {
  required String step,
  int frames = 8,
}) async {
  final directory = Platform.environment['BIL_CLOSURE_FRAME_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(surface);
  final target = Directory('$directory/$session');
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final index = _frameCounts.update(session, (n) => n + 1, ifAbsent: () => 0);
    await tester.runAsync(() async {
      if (index == 0 && await target.exists()) {
        throw StateError('A fresh Flutter frame session is required');
      }
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await target.create(recursive: true);
        await File(
          '${target.path}/${index.toString().padLeft(5, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        await File('${target.path}/frames.jsonl').writeAsString(
          '${jsonEncode({'frame': index, 'step': step, 'pumpedMs': (index + 1) * 100})}\n',
          mode: FileMode.append,
        );
      } finally {
        image.dispose();
      }
    });
  }
}

Future<void> captureClosureSurface(
  WidgetTester tester,
  Finder surface,
  String name,
) async {
  final stage = Platform.environment['BIL_CLOSURE_CAPTURE_STAGE'];
  if (stage == null) return;
  final object = tester.renderObject(surface);
  RenderObject? cursor = object;
  while (cursor != null && cursor is! RenderRepaintBoundary) {
    cursor = cursor.parent;
  }
  if (cursor is! RenderRepaintBoundary) {
    throw StateError('Capture surface has no repaint boundary');
  }
  final boundary = cursor;
  await tester.runAsync(() async {
    final rendered = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/stage1-closure/images/$stage-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      rendered.dispose();
    }
  });
}
