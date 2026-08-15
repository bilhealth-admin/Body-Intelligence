import 'dart:async';

import 'bil_launch_deep_link.dart';
import 'bil_launch_event.dart';

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
    _subscription = links.listen((uri) => unawaited(handle(uri)));
  }

  Future<void> dispose() async => _subscription?.cancel();
}
