import '../../commerce/domain/subscription_state.dart';
import '../domain/wellness_content_access_policy.dart';
import '../domain/wellness_content_pack.dart';
import '../domain/workout_free_preview_policy.dart';

/// Fail-closed access policy for installed workout packs.
///
/// The installed catalog is presentation data only. Paid content is revealed
/// exclusively when the current plan came from the verified server boundary;
/// a local flag, cached selection, or merely installed pack never unlocks it.
bool workoutAccessGranted(
  WellnessContentAccess minimumAccess,
  SubscriptionState? subscription,
) => wellnessContentAccessGranted(minimumAccess, subscription);

/// Item-aware boundary used by every workout open/log/play surface. Only the
/// generated bundle-scoped preview allowlist can bypass pack-level Pro access.
bool workoutItemAccessGranted(
  WellnessContentItem item,
  SubscriptionState? subscription,
) => WorkoutFreePreviewPolicy.accessGranted(item, subscription);
