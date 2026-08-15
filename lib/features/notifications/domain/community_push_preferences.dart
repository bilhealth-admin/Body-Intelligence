class CommunityPushPreferences {
  const CommunityPushPreferences({
    required this.enabled,
    required this.timeZone,
    this.sensitivePreviewAllowed = false,
  });

  final bool enabled;
  final String timeZone;
  final bool sensitivePreviewAllowed;
}
