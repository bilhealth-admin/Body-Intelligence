import '../../commerce/domain/subscription_state.dart';
import 'wellness_content_access_policy.dart';
import 'wellness_content_pack.dart';
import 'workout_free_preview_policy.generated.dart';

/// Bundle-scoped, generated free-preview entitlement.
///
/// UI order, search results, locale and remote pack fields cannot add preview
/// access. The Cloudflare worker consumes the matching generated object-key
/// artifact and independently enforces the same least-privilege boundary.
abstract final class WorkoutFreePreviewPolicy {
  static String? releaseKeyForGroup(String groupId) =>
      workoutFreePreviewReleaseKeyByGroup[groupId];

  static bool isPreview(WellnessContentItem item) {
    final releaseKey = item.releaseKey;
    return releaseKey != null &&
        workoutFreePreviewReleaseKeys.contains(releaseKey);
  }

  static bool accessGranted(
    WellnessContentItem item,
    SubscriptionState? subscription,
  ) =>
      isPreview(item) ||
      wellnessContentAccessGranted(item.minimumAccess, subscription);
}
