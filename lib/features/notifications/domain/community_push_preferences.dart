import 'community_push_delivery_categories.dart';

class CommunityPushPreferences {
  const CommunityPushPreferences({
    required this.enabled,
    required this.timeZone,
    this.sensitivePreviewAllowed = false,
    this.providerReady = true,
    this.deliveryCategories,
  });

  final bool enabled;
  final String timeZone;
  final bool sensitivePreviewAllowed;
  final bool providerReady;
  final CommunityPushDeliveryCategories? deliveryCategories;

  CommunityPushPreferences withDeliveryCategories(
    CommunityPushDeliveryCategories value,
  ) => CommunityPushPreferences(
    enabled: enabled,
    timeZone: timeZone,
    sensitivePreviewAllowed: sensitivePreviewAllowed,
    providerReady: providerReady,
    deliveryCategories: value,
  );
}
