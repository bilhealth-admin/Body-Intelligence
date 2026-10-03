class CommunityMentionCandidate {
  const CommunityMentionCandidate({
    required this.userId,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
  });

  static final RegExp handlePattern = RegExp(
    r'^[a-z][a-z0-9_]{2,29}$',
  );
  static final RegExp uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final String userId;
  final String handle;
  final String displayName;
  final String? avatarUrl;

  factory CommunityMentionCandidate.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final handle = json['handle'];
    final displayName = json['display_name'];
    final avatarUrl = json['avatar_url'];

    if (userId is! String ||
        !uuidPattern.hasMatch(userId) ||
        handle is! String ||
        !handlePattern.hasMatch(handle) ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        displayName.length > 60 ||
        (avatarUrl != null && avatarUrl is! String)) {
      throw const FormatException('Invalid Community mention candidate');
    }

    return CommunityMentionCandidate(
      userId: userId,
      handle: handle,
      displayName: displayName,
      avatarUrl: avatarUrl as String?,
    );
  }
}

class CommunityPostContextDraft {
  const CommunityPostContextDraft({
    this.locationLabel,
    this.mentions = const <CommunityMentionCandidate>[],
  });

  final String? locationLabel;
  final List<CommunityMentionCandidate> mentions;

  CommunityPostContextDraft normalized() {
    final location = locationLabel?.trim();
    if (location != null &&
        location.isNotEmpty &&
        (location.length > 80 || _hasControlCharacters(location))) {
      throw const FormatException('Invalid Community location label');
    }

    if (mentions.length > 10 ||
        mentions.map((value) => value.userId).toSet().length !=
            mentions.length) {
      throw const FormatException('Invalid Community mention list');
    }

    return CommunityPostContextDraft(
      locationLabel: location == null || location.isEmpty ? null : location,
      mentions: List<CommunityMentionCandidate>.unmodifiable(mentions),
    );
  }

  List<String> get mentionedUserIds =>
      mentions.map((value) => value.userId).toList(growable: false);

  static bool _hasControlCharacters(String value) => value.codeUnits.any(
    (unit) => unit < 32 || unit == 127,
  );
}
