import '../domain/ad_policy.dart';
import 'contextual_ad_gateway.dart';

/// The only permitted request boundary for contextual ads.
///
/// Suppression renders nothing: callers must not reserve an empty banner,
/// display a fake ad, or claim inventory exists.
final class SafeContextualAdController {
  const SafeContextualAdController(this.gateway);
  final ContextualAdGateway gateway;

  Future<ContextualAdResult> requestIfAllowed({
    required AdPolicyDecision decision,
    required AdPlacement placement,
  }) {
    if (!decision.mayRequestAd || !gateway.isConfigured) {
      return Future.value(ContextualAdResult.unavailable);
    }
    return gateway.show(placement);
  }
}
