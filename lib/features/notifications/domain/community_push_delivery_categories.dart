import 'notification_delivery_preferences.dart';

/// Owner-authenticated desired state, never inferred from local UI selections.
/// Unknown state is distinct from OFF; active delivery is also verified against
/// every currently enabled token by the server's synchronized diagnostic.
class CommunityPushDeliveryCategories {
  const CommunityPushDeliveryCategories({
    required this.ownerId,
    required this.initialized,
    required this.revision,
    required this.desired,
    required this.effective,
    required this.synchronized,
  });

  final String ownerId;
  final bool initialized;
  final int revision;
  final Set<NotificationCategory>? desired;
  final Set<NotificationCategory> effective;
  final bool synchronized;

  bool get verified => initialized && synchronized && desired != null;

  factory CommunityPushDeliveryCategories.fromReceipt(
    Object? value, {
    required String expectedOwnerId,
  }) {
    if (value is! Map ||
        value['owner_id'] != expectedOwnerId ||
        value['initialized'] is! bool ||
        value['revision'] is! int ||
        value['synchronized'] is! bool) {
      throw StateError('Unverified notification category receipt');
    }
    final initialized = value['initialized'] as bool;
    final revision = value['revision'] as int;
    if (initialized ? revision < 1 : revision != 0) {
      throw StateError('Invalid notification category revision');
    }
    const flags = {
      'message_enabled': NotificationCategory.newMessage,
      'friend_request_enabled': NotificationCategory.friendRequest,
      'friend_accepted_enabled': NotificationCategory.friendAccepted,
    };
    final desired = <NotificationCategory>{};
    final effective = <NotificationCategory>{};
    for (final flag in flags.entries) {
      final selected = value[flag.key];
      final active = value['effective_${flag.key}'];
      if ((initialized ? selected is! bool : selected != null) ||
          active is! bool) {
        throw StateError('Invalid notification category flags');
      }
      if (selected == true) desired.add(flag.value);
      if (active == true) effective.add(flag.value);
    }
    if (!initialized && value['synchronized'] == true) {
      throw StateError('Unknown notification categories cannot be verified');
    }
    if (initialized &&
        value['synchronized'] == true &&
        !desired.containsAll(effective)) {
      throw StateError('Contradictory active notification category receipt');
    }
    return CommunityPushDeliveryCategories(
      ownerId: expectedOwnerId,
      initialized: initialized,
      revision: revision,
      desired: initialized ? Set.unmodifiable(desired) : null,
      effective: Set.unmodifiable(effective),
      synchronized: value['synchronized'] as bool,
    );
  }
}
