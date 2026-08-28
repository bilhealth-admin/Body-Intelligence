part 'wellness_content_item.dart';

enum WellnessContentType { recipes, workouts, sleep, fasting }

enum WellnessContentAccess { free, plus, pro, coach, clinic, enterprise }

/// Intended audience for a reviewed workout presentation.
///
/// Audience is deliberately separate from the on-screen performer. A workout
/// remains suitable only for the audience declared by its reviewed catalog
/// metadata, regardless of who demonstrates it in the associated media.
enum WellnessWorkoutAudience { all, men, women }

/// Adult performer presentation used by reviewed workout media.
enum WellnessWorkoutPresenter { adultMale, adultFemale, neutral }

/// Whether a media object is a promotional preview or movement instruction.
enum WellnessMediaRole { preview, instruction }

/// Workout-media boundary for the current public release.
///
/// Two separately approved remote packs contain 302 logical movements. One
/// payload is intentionally shared, so 302 records map to 301 unique videos.
abstract final class WorkoutReleaseMediaContract {
  static const homeMovementVideoCount = 200;
  static const gymMovementVideoCount = 102;
  static const catalogMovementCount = 302;
  static const approvedMovementVideoCount = 302;
  static const uniquePayloadCount = 301;
  static const acceptedDurationSeconds = {7, 10};

  static final canonicalMovementId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  static String videoFileName(String movementId) => '$movementId.mp4';

  static String videoObjectPath(String bundleId, String movementId) =>
      bundleId == 'home-training'
      ? 'workouts/v1/home/movements/${videoFileName(movementId)}'
      : 'workouts/v1/gym-six-month/movements/${videoFileName(movementId)}';

  static bool hasCanonicalVideoPath(
    Uri uri,
    String bundleId,
    String movementId,
  ) => uri.path.endsWith('/${videoObjectPath(bundleId, movementId)}');
}

WellnessWorkoutAudience _wellnessWorkoutAudience(Object? raw) {
  final value = raw ?? 'all';
  if (value is! String) {
    throw const FormatException('Workout audience must be text.');
  }
  return switch (value.trim().toLowerCase()) {
    'all' => WellnessWorkoutAudience.all,
    'men' => WellnessWorkoutAudience.men,
    'women' => WellnessWorkoutAudience.women,
    _ => throw const FormatException('Workout audience is invalid.'),
  };
}

WellnessWorkoutPresenter _wellnessWorkoutPresenter(Object? raw) {
  final value = raw ?? 'neutral';
  if (value is! String) {
    throw const FormatException('Workout presenter must be text.');
  }
  return switch (value.trim().toLowerCase()) {
    'adult_male' => WellnessWorkoutPresenter.adultMale,
    'adult_female' => WellnessWorkoutPresenter.adultFemale,
    'neutral' => WellnessWorkoutPresenter.neutral,
    _ => throw const FormatException('Workout presenter is invalid.'),
  };
}

WellnessMediaRole _wellnessMediaRole(
  Object? raw, {
  required WellnessMediaRole fallback,
}) {
  if (raw == null) return fallback;
  if (raw is! String) {
    throw const FormatException('Wellness media role must be text.');
  }
  return switch (raw.trim().toLowerCase()) {
    'preview' => WellnessMediaRole.preview,
    'instruction' => WellnessMediaRole.instruction,
    _ => throw const FormatException('Wellness media role is invalid.'),
  };
}

WellnessContentAccess _wellnessContentAccess(Object? raw, String field) {
  final name = raw ?? 'free';
  if (name is! String) {
    throw FormatException('$field must be a wellness access level.');
  }
  for (final value in WellnessContentAccess.values) {
    if (value.name == name.trim().toLowerCase()) return value;
  }
  throw FormatException('$field must be a wellness access level.');
}

class WellnessContentPack {
  const WellnessContentPack({
    required this.id,
    required this.version,
    required this.type,
    required this.title,
    required this.description,
    required this.locale,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256,
    required this.itemCount,
    required this.minimumAccess,
    this.schemaVersion = 1,
    this.publisher = '',
    this.sourceUrl,
    this.licenseName = '',
    this.licenseUrl,
  });
  final String id, title, description, locale, sha256;
  final int version, sizeBytes, itemCount;
  final int schemaVersion;
  final Uri downloadUrl;
  final WellnessContentType type;
  final WellnessContentAccess minimumAccess;
  final String publisher, licenseName;
  final Uri? sourceUrl, licenseUrl;

  factory WellnessContentPack.fromJson(Map<String, dynamic> json) {
    final schemaVersion = (json['schema_version'] as num?)?.toInt() ?? 1;
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw const FormatException('Unsupported wellness pack schema.');
    }
    final rawSize = json['size_bytes'];
    final size = rawSize is num ? rawSize.toInt() : 0;
    final digest = (json['sha256'] as String? ?? '').toLowerCase();
    if (size <= 0 ||
        rawSize != size ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('Invalid wellness pack integrity metadata.');
    }
    final downloadUrl = _httpsUri(json, 'download_url');
    final sourceUrl = _optionalHttpsUri(json['source_url']);
    final licenseUrl = _optionalHttpsUri(json['license_url']);
    final id = _safeIdentifier(json, 'id');
    final rawVersion = json['version'];
    final version = rawVersion is num ? rawVersion.toInt() : 0;
    if (version <= 0 || rawVersion != version) {
      throw const FormatException('Wellness pack version must be positive.');
    }
    return WellnessContentPack(
      id: id,
      version: version,
      type: WellnessContentType.values.byName(_text(json, 'type')),
      title: _text(json, 'title'),
      description: json['description'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en',
      downloadUrl: downloadUrl,
      sizeBytes: size,
      sha256: digest,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      minimumAccess: _wellnessContentAccess(
        json['minimum_access'],
        'minimum_access',
      ),
      schemaVersion: schemaVersion,
      publisher: _text(json, 'publisher'),
      sourceUrl: sourceUrl ?? _httpsUri(json, 'source_url'),
      licenseName: _text(json, 'license_name'),
      licenseUrl: licenseUrl ?? _httpsUri(json, 'license_url'),
    );
  }

  static String _text(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing field: $key');
    }
    return value.trim();
  }

  static String _safeIdentifier(Map<String, dynamic> json, String key) {
    final value = _text(json, key);
    if (!RegExp(r'^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$').hasMatch(value)) {
      throw FormatException('$key is not a safe identifier.');
    }
    return value;
  }

  static Uri _httpsUri(Map<String, dynamic> json, String key) {
    final uri = Uri.tryParse(_text(json, key));
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('$key must be an HTTPS URL.');
    }
    return uri;
  }

  static Uri? _optionalHttpsUri(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    final uri = Uri.tryParse(value.toString().trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Content provenance URLs must use HTTPS.');
    }
    return uri;
  }
}

/// Integrity metadata for a remotely published wellness media object.
///
/// Schema-v2 workout videos are never trusted from their URL alone. The MIME
/// type, exact byte length, and SHA-256 digest are part of the catalog contract
/// so an offline-media downloader can verify every fetched asset before use.
class WellnessMediaAsset {
  const WellnessMediaAsset({
    required this.url,
    required this.mimeType,
    required this.sha256,
    required this.sizeBytes,
    this.mediaRole = WellnessMediaRole.preview,
  });

  final Uri url;
  final String mimeType, sha256;
  final int sizeBytes;
  final WellnessMediaRole mediaRole;

  factory WellnessMediaAsset.fromJson(
    Map<String, dynamic> json, {
    required String kind,
    WellnessMediaRole defaultMediaRole = WellnessMediaRole.preview,
  }) {
    final url = Uri.tryParse(_requiredText(json, 'url'));
    final mimeType = _requiredText(json, 'mime_type').toLowerCase();
    final digest = _requiredText(json, 'sha256').toLowerCase();
    final rawSize = json['size_bytes'];
    final size = rawSize is num ? rawSize.toInt() : 0;
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw FormatException('$kind media URL must use HTTPS.');
    }
    final supportedMime = switch (kind) {
      'video' => mimeType == 'video/mp4' || mimeType == 'video/webm',
      'image' =>
        mimeType == 'image/jpeg' ||
            mimeType == 'image/png' ||
            mimeType == 'image/webp',
      _ => false,
    };
    if (!supportedMime) {
      throw FormatException('$kind media MIME type is invalid.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        size <= 0 ||
        rawSize != size) {
      throw FormatException('$kind media integrity metadata is invalid.');
    }
    return WellnessMediaAsset(
      url: url,
      mimeType: mimeType,
      sha256: digest,
      sizeBytes: size,
      mediaRole: _wellnessMediaRole(
        json['media_role'],
        fallback: defaultMediaRole,
      ),
    );
  }

  static String _requiredText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing media field: $key');
    }
    return value.trim();
  }
}

/// Explicit distribution rights for schema-v2 workout media.
class WellnessContentRights {
  const WellnessContentRights({
    required this.mobile,
    required this.paid,
    required this.offline,
  });

  final bool mobile, paid, offline;

  factory WellnessContentRights.fromJson(Map<String, dynamic> json) {
    bool requiredFlag(String key) {
      final value = json[key];
      if (value is! bool) {
        throw FormatException('Missing rights flag: $key');
      }
      return value;
    }

    final rights = WellnessContentRights(
      mobile: requiredFlag('mobile'),
      paid: requiredFlag('paid'),
      offline: requiredFlag('offline'),
    );
    if (!rights.mobile || !rights.offline) {
      throw const FormatException(
        'Workout media must be licensed for mobile and offline use.',
      );
    }
    return rights;
  }
}

/// One playable movement inside a schema-v2 workout routine.
class WellnessWorkoutSegment {
  const WellnessWorkoutSegment({
    required this.id,
    required this.title,
    required this.instruction,
    required this.imageMedia,
    required this.videoMedia,
    this.repetitions,
    this.seconds,
    this.restSeconds,
    this.isOptional = false,
  });

  final String id, title, instruction;
  final int? repetitions, seconds, restSeconds;
  final bool isOptional;
  final WellnessMediaAsset imageMedia, videoMedia;

  factory WellnessWorkoutSegment.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing workout segment field: $key');
      }
      return value.trim();
    }

    int? optionalPositiveInt(String key, {bool allowZero = false}) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num) {
        throw FormatException('Workout segment $key must be an integer.');
      }
      final parsed = value.toInt();
      if (parsed != value || (allowZero ? parsed < 0 : parsed <= 0)) {
        throw FormatException('Workout segment $key is invalid.');
      }
      return parsed;
    }

    final repetitions = optionalPositiveInt('reps');
    final seconds = optionalPositiveInt('seconds');
    if (repetitions == null && seconds == null) {
      throw const FormatException(
        'Workout segment requires repetitions or seconds.',
      );
    }
    final media = json['media'];
    if (media is! Map<String, dynamic> ||
        media['image'] is! Map<String, dynamic> ||
        media['video'] is! Map<String, dynamic>) {
      throw const FormatException(
        'Workout segment image and video metadata are required.',
      );
    }
    final optional = json['optional'];
    if (optional != null && optional is! bool) {
      throw const FormatException('Workout segment optional must be boolean.');
    }
    return WellnessWorkoutSegment(
      id: requiredText('id'),
      title: requiredText('title'),
      instruction: requiredText('instruction'),
      repetitions: repetitions,
      seconds: seconds,
      restSeconds: optionalPositiveInt('rest_seconds', allowZero: true),
      isOptional: optional as bool? ?? false,
      imageMedia: WellnessMediaAsset.fromJson(
        media['image'] as Map<String, dynamic>,
        kind: 'image',
        defaultMediaRole: WellnessMediaRole.instruction,
      ),
      videoMedia: WellnessMediaAsset.fromJson(
        media['video'] as Map<String, dynamic>,
        kind: 'video',
        defaultMediaRole: WellnessMediaRole.instruction,
      ),
    );
  }
}

/// A locally installed content item that passed the BIL trust boundary.
///
/// Nutrition values are intentionally not part of this object: recipes may
/// only expose them through a separately sourced food calculation pipeline.
