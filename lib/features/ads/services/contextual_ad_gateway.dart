import 'package:flutter/widgets.dart';

import '../domain/ad_policy.dart';

enum ContextualAdResult { displayed, noFill, unavailable, failed }

abstract interface class ContextualAdGateway {
  bool get isConfigured;
  Future<ContextualAdResult> show(AdPlacement placement);
}

abstract interface class ContextualBannerHandle {
  Widget get widget;
  double get height;
  void dispose();
}

abstract interface class ContextualBannerGateway
    implements ContextualAdGateway {
  Future<ContextualBannerHandle?> loadBanner(AdPlacement placement);
}

/// Optional live privacy signal for an already displayed native banner.
/// Consent withdrawal removes it immediately; a new grant permits a retry.
abstract interface class ContextualAdPrivacyBoundary implements Listenable {
  bool get mayDisplayAd;
}

/// Safe production default until a reviewed store-compliant adapter is wired.
/// It performs no network call, renders no test ad, and records no user data.
final class DisabledContextualAdGateway implements ContextualAdGateway {
  const DisabledContextualAdGateway();

  @override
  bool get isConfigured => false;

  @override
  Future<ContextualAdResult> show(AdPlacement placement) async =>
      ContextualAdResult.unavailable;
}
