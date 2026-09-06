import 'dart:async';

import 'bil_launch_deep_link.dart';
import 'bil_launch_event.dart';

/// Serializes the single operating-system URI stream in arrival order.
///
/// Authentication callbacks can contain one-time codes, so two different
/// links must never race each other and navigate out of order. A failed item
/// is reported and consumed without poisoning the remainder of the queue.
final class BilSerialUriDispatcher {
  BilSerialUriDispatcher({required this.handle, required this.onError});

  final Future<void> Function(Uri uri) handle;
  final void Function(Object error, StackTrace stackTrace) onError;

  Future<void> _tail = Future<void>.value();
  bool _accepting = true;

  void add(Uri uri) {
    if (!_accepting) return;
    _tail = _tail
        .then((_) => handle(uri))
        .catchError(
          (Object error, StackTrace stackTrace) => onError(error, stackTrace),
        );
  }

  /// Stops accepting new links and waits for every accepted link to finish.
  Future<void> dispose() async {
    _accepting = false;
    await _tail;
  }

  /// Test/evidence seam; production callers never need to block the UI.
  Future<void> get drained => _tail;
}

/// Platform-neutral incoming-link hook. Android/iOS adapters may feed initial
/// and subsequent URIs; only allow-listed routes reach navigation.
final class BilIncomingLinkController {
  BilIncomingLinkController({
    required this.analytics,
    required this.navigate,
    required this.clock,
  });

  final BilLaunchAnalyticsSink analytics;
  final void Function(String route) navigate;
  final DateTime Function() clock;
  StreamSubscription<Uri>? _subscription;
  BilSerialUriDispatcher? _boundDispatcher;

  Future<bool> handle(Uri uri) async {
    final link = BilLaunchDeepLink.parse(uri);
    if (link == null) return false;
    await analytics.record(
      BilLaunchEvent(
        name: BilLaunchEventName.deepLinkOpened,
        occurredAt: clock().toUtc(),
        properties: {'route': link.route},
      ),
    );
    if (link.attribution.isNotEmpty) {
      await analytics.record(
        BilLaunchEvent(
          name: BilLaunchEventName.campaignAttributionCaptured,
          occurredAt: clock().toUtc(),
          properties: link.attribution,
        ),
      );
    }
    navigate(link.route);
    return true;
  }

  void bind(Stream<Uri> links) {
    _subscription?.cancel();
    unawaited(_boundDispatcher?.dispose());
    final dispatcher = BilSerialUriDispatcher(
      handle: (uri) async {
        await handle(uri);
      },
      onError: Zone.current.handleUncaughtError,
    );
    _boundDispatcher = dispatcher;
    _subscription = links.listen(dispatcher.add);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _boundDispatcher?.dispose();
  }
}
