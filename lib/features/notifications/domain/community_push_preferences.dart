class CommunityPushPreferences {
  const CommunityPushPreferences({
    required this.enabled,
    required this.timeZone,
    this.sensitivePreviewAllowed = false,
    this.providerReady = true,
  });

  final bool enabled;
  final String timeZone;
  final bool sensitivePreviewAllowed;
  final bool providerReady;
}
