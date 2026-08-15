import 'bil_launch_event.dart';

/// Consent boundary in front of an optional analytics vendor adapter.
/// Events are validated even while disabled so unsafe instrumentation fails in
/// tests rather than silently becoming production debt.
final class ConsentedLaunchAnalyticsSink implements BilLaunchAnalyticsSink {
  const ConsentedLaunchAnalyticsSink({
    required this.consentGranted,
    required this.delegate,
  });

  final bool Function() consentGranted;
  final BilLaunchAnalyticsSink delegate;

  @override
  Future<void> record(BilLaunchEvent event) async {
    if (!event.privacySafe) throw StateError('unsafe_analytics_event');
    if (!consentGranted()) return;
    await delegate.record(event);
  }
}

final class CompositeLaunchAnalyticsSink implements BilLaunchAnalyticsSink {
  const CompositeLaunchAnalyticsSink(this.delegates);
  final List<BilLaunchAnalyticsSink> delegates;

  @override
  Future<void> record(BilLaunchEvent event) async {
    if (!event.privacySafe) throw StateError('unsafe_analytics_event');
    for (final delegate in delegates) {
      await delegate.record(event);
    }
  }
}
