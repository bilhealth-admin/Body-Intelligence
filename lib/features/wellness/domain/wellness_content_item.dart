part of 'wellness_content_pack.dart';

class WellnessContentItem {
  const WellnessContentItem({
    required this.id,
    required this.type,
    required this.locale,
    required this.title,
    required this.description,
    required this.publisher,
    required this.sourceUrl,
    required this.licenseName,
    required this.verified,
    this.imageUrl,
    this.videoUrl,
    this.licenseUrl,
    this.durationMinutes,
    this.durationSeconds,
    this.difficulty,
    this.tags = const [],
    this.instructions = const [],
    this.category,
    this.categoryDescription,
    this.categoryOrder,
    this.equipment = const [],
    this.steps = const [],
    this.imageMedia,
    this.videoMedia,
    this.rights,
    this.author,
    this.attribution,
    this.reviewedAt,
    this.safetyReviewed = false,
    this.segments = const [],
    this.minimumAccess = WellnessContentAccess.free,
    this.audience = WellnessWorkoutAudience.all,
    this.presenter = WellnessWorkoutPresenter.neutral,
    this.syntheticPerformer = false,
    this.releaseBundleId,
    this.releaseKey,
    this.primaryPlanGroupId,
    this.planGroupIds = const [],
  });

  final String id, locale, title, description, publisher, licenseName;
  final WellnessContentType type;
  final Uri sourceUrl;
  final Uri? imageUrl, videoUrl, licenseUrl;
  final int? durationMinutes;
  final int? durationSeconds;
  final String? difficulty;
  final bool verified;
  final List<String> tags, instructions;
  final String? category, categoryDescription, author, attribution;
  final int? categoryOrder;
  final List<String> equipment, steps;
  final WellnessMediaAsset? imageMedia, videoMedia;
  final WellnessContentRights? rights;
  final DateTime? reviewedAt;
  final bool safetyReviewed;
  final List<WellnessWorkoutSegment> segments;
  final WellnessContentAccess minimumAccess;
  final WellnessWorkoutAudience audience;
  final WellnessWorkoutPresenter presenter;
  final bool syntheticPerformer;

  /// Bundle-scoped release identity. It prevents the 94 intentional Gym/Home
  /// name overlaps from colliding in saved state or collection grouping.
  final String? releaseBundleId, releaseKey, primaryPlanGroupId;
  final List<String> planGroupIds;

  String get stableId => releaseKey ?? id;

  factory WellnessContentItem.fromJson(
    Map<String, dynamic> json, {
    required WellnessContentType expectedType,
    int schemaVersion = 1,
  }) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing trusted content field: $key');
      }
      return value.trim();
    }

    Uri requiredHttps(String key) {
      final uri = Uri.tryParse(requiredText(key));
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw FormatException('$key must be an HTTPS URL.');
      }
      return uri;
    }

    Uri? optionalHttps(String key) {
      final value = json[key];
      if (value == null || value.toString().trim().isEmpty) return null;
      final uri = Uri.tryParse(value.toString().trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw FormatException('$key must be an HTTPS URL.');
      }
      return uri;
    }

    final declaredType = json['type'] as String?;
    if (declaredType != null && declaredType != expectedType.name) {
      throw const FormatException('Content item type does not match its pack.');
    }
    if (json['verified'] != true) {
      throw const FormatException('Unverified content is not publishable.');
    }
    final rawDuration = json['duration_minutes'];
    final duration = rawDuration is num ? rawDuration.toInt() : null;
    if (duration != null && (duration <= 0 || rawDuration != duration)) {
      throw const FormatException('Content duration must be positive.');
    }
    final rawDurationSeconds = json['duration_seconds'];
    final durationSeconds = rawDurationSeconds is num
        ? rawDurationSeconds.toInt()
        : null;
    if (durationSeconds != null &&
        (durationSeconds <= 0 || rawDurationSeconds != durationSeconds)) {
      throw const FormatException(
        'Content duration in seconds must be a positive integer.',
      );
    }
    WellnessMediaAsset? imageMedia;
    WellnessMediaAsset? videoMedia;
    WellnessContentRights? rights;
    String? category;
    String? categoryDescription;
    int? categoryOrder;
    String? author;
    String? attribution;
    DateTime? reviewedAt;
    var safetyReviewed = false;
    var audience = WellnessWorkoutAudience.all;
    var presenter = WellnessWorkoutPresenter.neutral;
    var syntheticPerformer = false;
    var equipment = const <String>[];
    var steps = const <String>[];
    var segments = const <WellnessWorkoutSegment>[];
    if (schemaVersion == 2 && expectedType == WellnessContentType.workouts) {
      if (duration == null && durationSeconds == null) {
        throw const FormatException('Workout duration is required.');
      }
      final media = json['media'];
      if (media is! Map<String, dynamic>) {
        throw const FormatException('Workout media metadata is required.');
      }
      final rawImage = media['image'];
      if (rawImage is! Map<String, dynamic>) {
        throw const FormatException('Workout image metadata is required.');
      }
      imageMedia = WellnessMediaAsset.fromJson(rawImage, kind: 'image');
      final rawVideo = media['video'];
      if (rawVideo is! Map<String, dynamic>) {
        throw const FormatException('Workout video metadata is required.');
      }
      videoMedia = WellnessMediaAsset.fromJson(rawVideo, kind: 'video');
      final rawRights = json['rights'];
      if (rawRights is! Map<String, dynamic>) {
        throw const FormatException(
          'Workout distribution rights are required.',
        );
      }
      rights = WellnessContentRights.fromJson(rawRights);
      category = requiredText('category');
      categoryDescription = requiredText('category_description');
      final rawCategoryOrder = json['category_order'];
      if (rawCategoryOrder is! num ||
          rawCategoryOrder.toInt() != rawCategoryOrder ||
          rawCategoryOrder < 0) {
        throw const FormatException('Workout category order is invalid.');
      }
      categoryOrder = rawCategoryOrder.toInt();
      author = requiredText('author');
      attribution = requiredText('attribution');
      equipment = _requiredTextList(json, 'equipment');
      final rawSegments = json['segments'];
      if (rawSegments != null && rawSegments is! List) {
        throw const FormatException('Workout segments must be a list.');
      }
      segments = (rawSegments as List? ?? const [])
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Workout segment is invalid.');
            }
            return WellnessWorkoutSegment.fromJson(raw);
          })
          .toList(growable: false);
      final segmentIds = <String>{};
      final segmentMediaUrls = <Uri>{imageMedia.url, videoMedia.url};
      final segmentMediaDigests = <String>{
        imageMedia.sha256,
        videoMedia.sha256,
      };
      for (final segment in segments) {
        if (!segmentIds.add(segment.id) ||
            !segmentMediaUrls.add(segment.imageMedia.url) ||
            !segmentMediaUrls.add(segment.videoMedia.url) ||
            !segmentMediaDigests.add(segment.imageMedia.sha256) ||
            !segmentMediaDigests.add(segment.videoMedia.sha256)) {
          throw const FormatException('Duplicate workout segment media.');
        }
      }
      final legacySteps = json['steps'];
      steps = legacySteps == null
          ? segments
                .map((segment) => segment.instruction)
                .toList(growable: false)
          : _requiredTextList(json, 'steps');
      final rawReviewedAt = requiredText('reviewed_at');
      if (!RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(rawReviewedAt)) {
        throw const FormatException('Workout review timestamp must be zoned.');
      }
      reviewedAt = DateTime.tryParse(rawReviewedAt)?.toUtc();
      safetyReviewed = json['safety_reviewed'] == true;
      audience = _wellnessWorkoutAudience(json['audience']);
      presenter = _wellnessWorkoutPresenter(json['presenter']);
      final rawSyntheticPerformer = json['synthetic_performer'];
      if (rawSyntheticPerformer != null && rawSyntheticPerformer is! bool) {
        throw const FormatException(
          'Workout synthetic_performer must be boolean.',
        );
      }
      syntheticPerformer = rawSyntheticPerformer as bool? ?? false;
      if (reviewedAt == null || reviewedAt.isAfter(DateTime.now().toUtc())) {
        throw const FormatException('Workout review timestamp is invalid.');
      }
      if (!safetyReviewed) {
        throw const FormatException('Workout safety review is required.');
      }
    } else if (schemaVersion != 1 && schemaVersion != 2) {
      throw const FormatException('Unsupported wellness item schema.');
    }

    return WellnessContentItem(
      id: requiredText('id'),
      type: expectedType,
      locale: (json['locale'] as String? ?? 'en').trim(),
      title: requiredText('title'),
      description: requiredText('description'),
      publisher: requiredText('publisher'),
      sourceUrl: requiredHttps('source_url'),
      licenseName: requiredText('license_name'),
      licenseUrl: optionalHttps('license_url'),
      imageUrl: imageMedia?.url ?? optionalHttps('image_url'),
      videoUrl: videoMedia?.url ?? optionalHttps('video_url'),
      durationMinutes: duration,
      durationSeconds: durationSeconds,
      difficulty: (json['difficulty'] as String?)?.trim(),
      verified: true,
      tags: (json['tags'] as List? ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      instructions: (json['instructions'] as List? ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      category: category,
      categoryDescription: categoryDescription,
      categoryOrder: categoryOrder,
      equipment: equipment,
      steps: steps,
      imageMedia: imageMedia,
      videoMedia: videoMedia,
      rights: rights,
      author: author,
      attribution: attribution,
      reviewedAt: reviewedAt,
      safetyReviewed: safetyReviewed,
      segments: segments,
      minimumAccess: _wellnessContentAccess(
        json['_pack_minimum_access'],
        '_pack_minimum_access',
      ),
      audience: audience,
      presenter: presenter,
      syntheticPerformer: syntheticPerformer,
      releaseBundleId: (json['_release_bundle_id'] as String?)?.trim(),
      releaseKey: (json['_release_key'] as String?)?.trim(),
      primaryPlanGroupId: (json['_primary_plan_group_id'] as String?)?.trim(),
      planGroupIds: (json['_plan_group_ids'] as List? ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }

  static List<String> _requiredTextList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) {
      throw FormatException('Missing workout field: $key');
    }
    final result = value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (result.isEmpty ||
        result.length != value.length ||
        result.toSet().length != result.length) {
      throw FormatException('Workout field $key must contain text values.');
    }
    return result;
  }
}

class InstalledWellnessContentPack {
  const InstalledWellnessContentPack({
    required this.id,
    required this.version,
    required this.path,
    required this.installedAt,
    this.minimumAccess = WellnessContentAccess.free,
  });
  final String id, path;
  final int version;
  final DateTime installedAt;
  final WellnessContentAccess minimumAccess;
  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'path': path,
    'installed_at': installedAt.toUtc().toIso8601String(),
    'minimum_access': minimumAccess.name,
  };
  factory InstalledWellnessContentPack.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final rawVersion = json['version'];
    final path = json['path'];
    final rawInstalledAt = json['installed_at'];
    if (id is! String ||
        !RegExp(r'^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$').hasMatch(id) ||
        rawVersion is! num ||
        rawVersion.toInt() != rawVersion ||
        rawVersion <= 0 ||
        path is! String ||
        path.trim().isEmpty ||
        rawInstalledAt is! String) {
      throw const FormatException('Invalid installed wellness pack record.');
    }
    final installedAt = DateTime.tryParse(rawInstalledAt);
    if (installedAt == null) {
      throw const FormatException('Invalid installed wellness pack date.');
    }
    return InstalledWellnessContentPack(
      id: id,
      version: rawVersion.toInt(),
      path: path,
      installedAt: installedAt,
      minimumAccess: _wellnessContentAccess(
        json['minimum_access'],
        'minimum_access',
      ),
    );
  }
}
