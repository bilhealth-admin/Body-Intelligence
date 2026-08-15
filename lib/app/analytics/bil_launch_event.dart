enum BilLaunchEventName {
  signupCompleted,
  onboardingCompleted,
  trialStarted,
  subscriptionPurchaseStarted,
  subscriptionPurchaseVerified,
  subscriptionStatusRefreshed,
  purchasesRestored,
  aiBoostPurchaseVerified,
  paywallImpression,
  paywallConversion,
  deepLinkOpened,
  campaignAttributionCaptured,
  retainedDay1,
  retainedDay7,
  retainedDay30,
}

class BilLaunchEvent {
  const BilLaunchEvent({
    required this.name,
    required this.occurredAt,
    this.properties = const {},
  });

  final BilLaunchEventName name;
  final DateTime occurredAt;
  final Map<String, Object?> properties;

  bool get privacySafe =>
      occurredAt.isUtc &&
      !properties.keys.any(_forbiddenProperty) &&
      properties.values.every(
        (value) =>
            value == null || value is String || value is num || value is bool,
      );

  static bool _forbiddenProperty(String key) {
    final normalized = key.toLowerCase();
    return const {
      'email',
      'phone',
      'name',
      'weight',
      'waist',
      'meal',
      'diagnosis',
      'image',
      'voice',
    }.any(normalized.contains);
  }
}

abstract interface class BilLaunchAnalyticsSink {
  Future<void> record(BilLaunchEvent event);
}

final class DisabledBilLaunchAnalyticsSink implements BilLaunchAnalyticsSink {
  const DisabledBilLaunchAnalyticsSink();

  @override
  Future<void> record(BilLaunchEvent event) async {
    if (!event.privacySafe) throw StateError('unsafe_analytics_event');
  }
}
