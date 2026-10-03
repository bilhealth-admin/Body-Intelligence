import 'community_post_context.dart';

enum CommunityCollaborationStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined');

  const CommunityCollaborationStatus(this.wireValue);
  final String wireValue;

  static CommunityCollaborationStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Community collaboration status',
        ),
      );
}

class CommunityPostCollaborator {
  const CommunityPostCollaborator({
    required this.userId,
    required this.displayName,
    required this.status,
    this.handle,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final CommunityCollaborationStatus status;

  factory CommunityPostCollaborator.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final displayName = json['display_name'];
    final handle = json['handle'];
    final avatarUrl = json['avatar_url'];
    if (userId is! String ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        (handle != null && handle is! String) ||
        (avatarUrl != null && avatarUrl is! String)) {
      throw const FormatException('Invalid Community collaborator');
    }
    return CommunityPostCollaborator(
      userId: userId,
      displayName: displayName,
      handle: handle as String?,
      avatarUrl: avatarUrl as String?,
      status: CommunityCollaborationStatus.fromWire(json['status']),
    );
  }
}

class CommunityPostReferenceMetadata {
  const CommunityPostReferenceMetadata({
    required this.postId,
    required this.hashtags,
    required this.collaborators,
    this.title,
  });

  final String postId;
  final String? title;
  final List<String> hashtags;
  final List<CommunityPostCollaborator> collaborators;

  factory CommunityPostReferenceMetadata.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final title = json['title'];
    final rawHashtags = json['hashtags'];
    final rawCollaborators = json['collaborators'];
    if (postId is! String ||
        (title != null && title is! String) ||
        rawHashtags is! List ||
        rawCollaborators is! List) {
      throw const FormatException('Invalid Community post reference metadata');
    }
    final hashtags = rawHashtags.map((value) {
      if (value is! String ||
          value.isEmpty ||
          value.length > 40 ||
          value.contains(RegExp(r'[#\s\x00-\x1F\x7F]'))) {
        throw const FormatException('Invalid Community hashtag');
      }
      return value;
    }).toList(growable: false);
    final collaborators = rawCollaborators.map((raw) {
      if (raw is! Map) {
        throw const FormatException('Invalid Community collaborator row');
      }
      return CommunityPostCollaborator.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }).toList(growable: false);
    return CommunityPostReferenceMetadata(
      postId: postId,
      title: title as String?,
      hashtags: List<String>.unmodifiable(hashtags),
      collaborators: List<CommunityPostCollaborator>.unmodifiable(
        collaborators,
      ),
    );
  }
}

class CommunityDraftSummary {
  const CommunityDraftSummary({
    required this.draftId,
    required this.body,
    required this.updatedAt,
    required this.mediaCount,
    this.title,
  });

  final String draftId;
  final String? title;
  final String body;
  final DateTime updatedAt;
  final int mediaCount;

  factory CommunityDraftSummary.fromJson(Map<String, dynamic> json) {
    final draftId = json['draft_id'];
    final title = json['title'];
    final body = json['body'];
    final updatedAt = DateTime.tryParse(json['updated_at']?.toString() ?? '');
    final mediaCount = json['media_count'];
    if (draftId is! String ||
        (title != null && title is! String) ||
        body is! String ||
        updatedAt == null ||
        mediaCount is! num ||
        mediaCount < 0 ||
        mediaCount > 4 ||
        mediaCount % 1 != 0) {
      throw const FormatException('Invalid Community draft summary');
    }
    return CommunityDraftSummary(
      draftId: draftId,
      title: title as String?,
      body: body,
      updatedAt: updatedAt,
      mediaCount: mediaCount.toInt(),
    );
  }
}

class CommunityDraftMediaMetadata {
  const CommunityDraftMediaMetadata({
    required this.position,
    required this.objectPath,
    required this.mimeType,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final int position;
  final String objectPath;
  final String mimeType;
  final int bytes;
  final int width;
  final int height;

  String get extension => switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => throw const FormatException('Invalid draft media mime type'),
  };

  factory CommunityDraftMediaMetadata.fromJson(Map<String, dynamic> json) {
    int exactInt(String key, {required int min, required int max}) {
      final value = json[key];
      if (value is int && value >= min && value <= max) return value;
      if (value is num &&
          value % 1 == 0 &&
          value >= min &&
          value <= max) {
        return value.toInt();
      }
      throw FormatException('Invalid Community draft media field: $key');
    }

    final path = json['object_path'];
    final mime = json['mime_type'];
    if (path is! String ||
        path.isEmpty ||
        mime is! String ||
        !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
      throw const FormatException('Invalid Community draft media');
    }
    final width = exactInt('width', min: 1, max: 8192);
    final height = exactInt('height', min: 1, max: 8192);
    if (width * height > 40000000) {
      throw const FormatException('Invalid Community draft media dimensions');
    }
    return CommunityDraftMediaMetadata(
      position: exactInt('position', min: 0, max: 3),
      objectPath: path,
      mimeType: mime,
      bytes: exactInt('bytes', min: 1, max: 5 * 1024 * 1024),
      width: width,
      height: height,
    );
  }
}

class CommunityPersistentDraft {
  const CommunityPersistentDraft({
    required this.draftId,
    required this.body,
    required this.topicSlugs,
    required this.mentions,
    required this.collaborators,
    required this.hashtags,
    required this.pollOptions,
    required this.pollAllowMultiple,
    required this.createdAt,
    required this.updatedAt,
    required this.media,
    this.title,
    this.circleSlug,
    this.locationLabel,
    this.pollQuestion,
  });

  final String draftId;
  final String? title;
  final String body;
  final List<String> topicSlugs;
  final String? circleSlug;
  final String? locationLabel;
  final List<CommunityMentionCandidate> mentions;
  final List<CommunityMentionCandidate> collaborators;
  final List<String> hashtags;
  final String? pollQuestion;
  final List<String> pollOptions;
  final bool pollAllowMultiple;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CommunityDraftMediaMetadata> media;

  factory CommunityPersistentDraft.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) {
      final raw = json[key];
      if (raw is! List || raw.any((value) => value is! String)) {
        throw FormatException('Invalid Community draft field: $key');
      }
      return List<String>.unmodifiable(raw.cast<String>());
    }

    List<CommunityMentionCandidate> candidates(String key) {
      final raw = json[key];
      if (raw is! List) {
        throw FormatException('Invalid Community draft field: $key');
      }
      return List<CommunityMentionCandidate>.unmodifiable(
        raw.map((item) {
          if (item is! Map) {
            throw FormatException('Invalid Community draft field: $key');
          }
          return CommunityMentionCandidate.fromJson(
            Map<String, dynamic>.from(item),
          );
        }),
      );
    }

    final draftId = json['draft_id'];
    final title = json['title'];
    final body = json['body'];
    final circleSlug = json['circle_slug'];
    final locationLabel = json['location_label'];
    final pollQuestion = json['poll_question'];
    final pollAllowMultiple = json['poll_allow_multiple'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updated_at']?.toString() ?? '');
    final rawMedia = json['media'];
    if (draftId is! String ||
        (title != null && title is! String) ||
        body is! String ||
        (circleSlug != null && circleSlug is! String) ||
        (locationLabel != null && locationLabel is! String) ||
        (pollQuestion != null && pollQuestion is! String) ||
        pollAllowMultiple is! bool ||
        createdAt == null ||
        updatedAt == null ||
        rawMedia is! List) {
      throw const FormatException('Invalid Community persistent draft');
    }

    final media = rawMedia.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid Community draft media row');
      }
      return CommunityDraftMediaMetadata.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList(growable: false);

    return CommunityPersistentDraft(
      draftId: draftId,
      title: title as String?,
      body: body,
      topicSlugs: strings('topic_slugs'),
      circleSlug: circleSlug as String?,
      locationLabel: locationLabel as String?,
      mentions: candidates('mentions'),
      collaborators: candidates('collaborators'),
      hashtags: strings('hashtags'),
      pollQuestion: pollQuestion as String?,
      pollOptions: strings('poll_options'),
      pollAllowMultiple: pollAllowMultiple,
      createdAt: createdAt,
      updatedAt: updatedAt,
      media: List<CommunityDraftMediaMetadata>.unmodifiable(media),
    );
  }
}

class CommunityDraftSaveInput {
  const CommunityDraftSaveInput({
    required this.draftId,
    required this.body,
    this.title,
    this.topicSlugs = const <String>[],
    this.circleSlug,
    this.locationLabel,
    this.mentions = const <CommunityMentionCandidate>[],
    this.collaborators = const <CommunityMentionCandidate>[],
    this.hashtags = const <String>[],
    this.pollQuestion,
    this.pollOptions = const <String>[],
    this.pollAllowMultiple = false,
  });

  final String draftId;
  final String? title;
  final String body;
  final List<String> topicSlugs;
  final String? circleSlug;
  final String? locationLabel;
  final List<CommunityMentionCandidate> mentions;
  final List<CommunityMentionCandidate> collaborators;
  final List<String> hashtags;
  final String? pollQuestion;
  final List<String> pollOptions;
  final bool pollAllowMultiple;
}
