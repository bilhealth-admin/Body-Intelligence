part of '../features/dashboard/dashboard_discover_stability_test.dart';

// Preserve the single-subscription fixture's delivery semantics. Cleanup may
// add a terminal drain only after the body ended and only if nobody listened.
class _DiscoverOwnerStream {
  bool _everListened = false;
  bool _draining = false;
  bool completionObserved = false;
  late final StreamController<String?> _controller = StreamController<String?>(
    onListen: () {
      _everListened = true;
      debugPrint(
        'DISCOVER_OWNERS onListen mode=${_draining ? 'cleanup-drain' : 'fixture'}',
      );
    },
    onCancel: () {
      debugPrint(
        'DISCOVER_OWNERS onCancel mode=${_draining ? 'cleanup-drain' : 'fixture'}',
      );
    },
  );

  Stream<String?> get stream => _controller.stream;

  Future<void> close(WidgetTester tester) async {
    final failures = <({String stage, Object error, StackTrace stack})>[];
    debugPrint(
      'DISCOVER_OWNERS close begin ever_listened=$_everListened has_listener=${_controller.hasListener}',
    );
    if (!_everListened) {
      _draining = true;
      // A single-subscription controller's close future never completes if
      // its stream was never listened to. Consume its terminal event without
      // adding a provider, fabricating an owner, or swallowing queued errors.
      _controller.stream.listen(
        (_) {},
        onError: (Object error, StackTrace stack) {
          failures.add((
            stage: 'owner terminal drain',
            error: error,
            stack: stack,
          ));
        },
      );
    }
    var finished = false;
    _controller.close().then<void>(
      (_) => finished = true,
      onError: (Object error, StackTrace stack) {
        failures.add((stage: 'owner close', error: error, stack: stack));
        finished = true;
      },
    );
    // Do not await a fake-zone controller future inside runAsync. Its event
    // needs fake microtasks; native cancellation also gets real event turns.
    for (var frame = 0; frame < 100 && !finished; frame++) {
      await tester.pump(Duration.zero);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(Duration.zero);
    }
    if (!finished) {
      throw StateError(
        'Discover owner close did not settle after100 host/fake drains; ever_listened=$_everListened has_listener=${_controller.hasListener}',
      );
    }
    completionObserved = true;
    debugPrint('DISCOVER_OWNERS close done drain=$_draining');
    _throwDiscoverCleanupFailures(failures);
  }
}

Future<void> _attemptDiscoverCleanup(
  List<({String stage, Object error, StackTrace stack})> failures,
  String stage,
  Future<void> Function() cleanup,
) async {
  debugPrint('DISCOVER_CLEANUP phase=$stage begin');
  try {
    await cleanup();
    debugPrint('DISCOVER_CLEANUP phase=$stage done');
  } catch (error, stack) {
    failures.add((stage: stage, error: error, stack: stack));
    debugPrint('DISCOVER_CLEANUP phase=$stage failed: $error');
  }
}

void _throwDiscoverCleanupFailures(
  List<({String stage, Object error, StackTrace stack})> failures,
) {
  if (failures.length == 1) {
    Error.throwWithStackTrace(failures.single.error, failures.single.stack);
  }
  if (failures.isNotEmpty) {
    Error.throwWithStackTrace(
      _DiscoverCleanupFailures(failures),
      failures.first.stack,
    );
  }
}

class _DiscoverCleanupFailures implements Exception {
  _DiscoverCleanupFailures(this.failures);
  final List<({String stage, Object error, StackTrace stack})> failures;
  @override
  String toString() =>
      failures.map((f) => '${f.stage}: ${f.error}\n${f.stack}').join('\n');
}
