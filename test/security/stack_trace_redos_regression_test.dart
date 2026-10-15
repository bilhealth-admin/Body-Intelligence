import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_trace/stack_trace.dart';

void _parseTraceInIsolate(List<Object?> arguments) {
  final sendPort = arguments.first as SendPort;
  try {
    final parsed = Trace.parse(arguments[1]! as String);
    sendPort.send(parsed.frames.length);
  } catch (_) {
    sendPort.send('completed-with-parser-error');
  }
}

void main() {
  test('ordinary Firefox and Safari stack frames still parse', () {
    final trace = Trace.parse(
      'member(arg)@https://example.invalid/app.js:560\n'
      'https://example.invalid/app.js:561',
    );

    expect(trace.frames, hasLength(2));
    expect(trace.frames.first.line, 560);
    expect(trace.frames.last.line, 561);
  });

  test('malformed JavaScript trace input stays bounded', () async {
    final repeatedClosers = List.filled(300, ")(").join();
    final maliciousShape =
        '($repeatedClosers'
        'x';
    final port = ReceivePort();
    final isolate = await Isolate.spawn(_parseTraceInIsolate, [
      port.sendPort,
      maliciousShape,
    ]);
    addTearDown(() {
      isolate.kill(priority: Isolate.immediate);
      port.close();
    });

    final result = await port.first.timeout(const Duration(seconds: 2));
    expect(result, anyOf(isA<int>(), 'completed-with-parser-error'));
  });
}
