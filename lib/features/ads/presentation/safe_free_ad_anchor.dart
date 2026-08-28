import 'package:flutter/widgets.dart';

import '../domain/ad_policy.dart';
import 'safe_contextual_banner_slot.dart';

/// Reviewed, non-sensitive inventory where a contextual banner may appear.
///
/// [SafeFreeAdSurface] is local UI inventory only. It is never forwarded to
/// the ad provider, and this widget accepts no user, health, food, search, or
/// profile data.
enum SafeFreeAdSurface {
  dashboard,
  dailyLog,
  progress,
  more,
  wellnessDiscovery,
}

/// The single reusable anchor for Free-plan banners.
///
/// Eligibility, verified entitlement, lifecycle ownership, and zero-size
/// suppression remain centralized in [SafeContextualBannerSlot]. All approved
/// surfaces deliberately use the generic, non-sensitive discovery placement.
class SafeFreeAdAnchor extends StatelessWidget {
  const SafeFreeAdAnchor({required this.surface, super.key});

  final SafeFreeAdSurface surface;

  @override
  Widget build(BuildContext context) => SafeContextualBannerSlot(
    key: ValueKey('safe-free-ad-slot-${surface.name}'),
    placement: AdPlacement.generalDiscovery,
  );
}
