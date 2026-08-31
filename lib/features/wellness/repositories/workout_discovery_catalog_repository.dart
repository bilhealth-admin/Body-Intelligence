import 'dart:convert';

import '../domain/wellness_content_pack.dart';
import '../domain/workout_release_catalog_item.dart';

/// Strict decoder for the bundled, instruction-redacted workout discovery UI.
///
/// This catalog is metadata only. It never downloads media and it never grants
/// access to a paid workout pack. Every card must resolve to one exact item
/// emitted by [WorkoutReleaseCatalogRepository].
final class WorkoutDiscoveryCatalogRepository {
  const WorkoutDiscoveryCatalogRepository();

  static const assetPath =
      'artifacts/workout_media/workout_discovery_catalog_v1.json';
  static const schema = 'bil.workout-media.discovery.v1';
  static const version = 1;
  static const itemCount = 302;
  static const releasePackVersions = <String, int>{
    'bil-workouts-home-v1': 1,
    'bil-workouts-gym-six-month-v1': 1,
  };
  static const releasePackItemCounts = <String, int>{
    'bil-workouts-home-v1': 200,
    'bil-workouts-gym-six-month-v1': 102,
  };
  static const releaseBundleIds = <String, String>{
    'bil-workouts-home-v1': 'home-training',
    'bil-workouts-gym-six-month-v1': 'gym-six-month',
  };

  static const registrySha256 =
      '90bd7cd4ce7d9c1a2652720b79b67e0ede885da1cf979d86632a3f8f3c345a3f';
  static const _manifestDigests = <String, String>{
    'home-training':
        '2f84af763d78b727f562981a0d9835412db8c2bd7422dccd908e8099e9efbf51',
    'gym-six-month':
        '4e531ad6cd31c3ed096257b3db4a3aa4f99b1fa74d2eef3655884de78fdd48cd',
  };
  static const _packDigests = <String, String>{
    'home-training':
        'bc3ca8b55a28e94bc9faeee5f220f2966a0cd9f1776e297d00e1f8137fe17567',
    'gym-six-month':
        '6c21ef8df8c6303fef7c03b283caa8ff098e3a85ac6efc6860d48ffe50ce39b5',
  };
  static const _contentPackIds = <String, String>{
    'home-training': 'bil-workouts-home-v1',
    'gym-six-month': 'bil-workouts-gym-six-month-v1',
  };

  static const _rootKeys = {
    'itemCount',
    'items',
    'schema',
    'source',
    'version',
  };
  static const _itemKeys = {
    '_pack_minimum_access',
    '_pack_schema_version',
    '_plan_group_ids',
    '_primary_plan_group_id',
    '_release_bundle_id',
    '_release_key',
    'attribution',
    'audience',
    'author',
    'category',
    'category_description',
    'category_order',
    'description',
    'duration_seconds',
    'equipment',
    'human_safety_reviewed',
    'id',
    'license_name',
    'license_url',
    'locale',
    'media',
    'presenter',
    'publisher',
    'reviewed_at',
    'rights',
    'safety_reviewed',
    'source_url',
    'synthetic_performer',
    'title',
    'type',
    'verified',
  };
  static const _forbiddenPremiumKeys = {'instructions', 'segments', 'steps'};

  List<WellnessContentItem> parse(
    String source,
    List<WorkoutReleaseCatalogItem> approvedRelease,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    }
    final root = _object(decoded, 'workout discovery catalog');
    _exactKeys(root, _rootKeys, 'workout discovery catalog');
    if (root['schema'] != schema ||
        root['version'] is! int ||
        root['version'] != version ||
        root['itemCount'] is! int ||
        root['itemCount'] != itemCount) {
      throw const FormatException('Workout discovery schema is invalid.');
    }
    _validateSourcePins(root['source']);

    final approved = _validateApprovedRelease(approvedRelease);
    final rawItems = _list(root['items'], 'workout discovery items');
    if (rawItems.length != itemCount) {
      throw const FormatException('Workout discovery count is invalid.');
    }

    final result = <WellnessContentItem>[];
    final seenReleaseKeys = <String>{};
    final categoryOrders = <String, int>{};
    final categoryDescriptions = <String, String>{};
    for (final raw in rawItems) {
      final json = _object(raw, 'workout discovery item');
      if (json.keys.any(_forbiddenPremiumKeys.contains)) {
        throw const FormatException(
          'Premium workout instructions cannot appear in discovery.',
        );
      }
      _exactKeys(json, _itemKeys, 'workout discovery item');

      final releaseKey = _text(json['_release_key'], '_release_key');
      final approval = approved[releaseKey];
      if (approval == null || !seenReleaseKeys.add(releaseKey)) {
        throw const FormatException(
          'Workout discovery release identity is invalid.',
        );
      }
      _validateItemPins(json, approval, categoryOrders, categoryDescriptions);
      final item = WellnessContentItem.fromJson(
        json,
        expectedType: WellnessContentType.workouts,
        schemaVersion: 2,
      );
      if (item.stableId != approval.releaseKey ||
          item.minimumAccess != WellnessContentAccess.pro ||
          item.instructions.isNotEmpty ||
          item.steps.isNotEmpty ||
          item.segments.isNotEmpty) {
        throw const FormatException(
          'Workout discovery item exposes non-discovery content.',
        );
      }
      result.add(item);
    }

    if (!_sameSet(seenReleaseKeys, approved.keys.toSet())) {
      throw const FormatException('Workout discovery release is incomplete.');
    }
    return List.unmodifiable(result);
  }

  static void _validateSourcePins(Object? value) {
    final source = _object(value, 'workout discovery source');
    _exactKeys(source, const {
      'bundles',
      'registrySha256',
    }, 'workout discovery source');
    if (source['registrySha256'] != registrySha256) {
      throw const FormatException('Workout discovery registry pin changed.');
    }
    final bundles = _list(source['bundles'], 'workout discovery bundles');
    if (bundles.length != 2) {
      throw const FormatException('Workout discovery bundles are incomplete.');
    }
    final seen = <String>{};
    for (final raw in bundles) {
      final bundle = _object(raw, 'workout discovery bundle');
      _exactKeys(bundle, const {
        'bundleId',
        'manifestSha256',
        'packSha256',
      }, 'workout discovery bundle');
      final id = _safeId(bundle['bundleId'], 'bundleId');
      if (!seen.add(id) ||
          bundle['manifestSha256'] != _manifestDigests[id] ||
          bundle['packSha256'] != _packDigests[id]) {
        throw const FormatException('Workout discovery source pin is invalid.');
      }
    }
    if (!_sameSet(seen, _manifestDigests.keys.toSet())) {
      throw const FormatException(
        'Workout discovery source pin is incomplete.',
      );
    }
  }

  static Map<String, WorkoutReleaseCatalogItem> _validateApprovedRelease(
    List<WorkoutReleaseCatalogItem> release,
  ) {
    if (release.length != itemCount) {
      throw const FormatException('Approved workout release is incomplete.');
    }
    final result = <String, WorkoutReleaseCatalogItem>{};
    final bundleCounts = <String, int>{};
    for (final item in release) {
      final bundleId = _safeId(item.bundleId, 'release.bundleId');
      final assetId = _safeId(item.assetId, 'release.assetId');
      _safeId(item.exerciseId, 'release.exerciseId');
      final primaryGroup = _safeId(
        item.primaryGroupId,
        'release.primaryGroupId',
      );
      final groups = _safeIdList(item.planGroupIds, 'release.planGroupIds');
      if (!item.canPlay ||
          item.releaseKey != '$bundleId:$assetId' ||
          item.contentPackId != _contentPackIds[bundleId] ||
          item.objectPath == null ||
          item.objectPath !=
              WorkoutReleaseMediaContract.videoObjectPath(bundleId, assetId) ||
          item.expectedSha256 == null ||
          !_isDigest(item.expectedSha256) ||
          item.expectedBytes == null ||
          item.expectedBytes! <= 0 ||
          item.durationMilliseconds == null ||
          item.durationMilliseconds! <= 0 ||
          item.durationMilliseconds! % 1000 != 0 ||
          groups.isEmpty ||
          !groups.contains(primaryGroup) ||
          result[item.releaseKey] != null) {
        throw const FormatException('Approved workout release is invalid.');
      }
      result[item.releaseKey] = item;
      bundleCounts.update(bundleId, (count) => count + 1, ifAbsent: () => 1);
    }
    if (bundleCounts['home-training'] != 200 ||
        bundleCounts['gym-six-month'] != 102 ||
        bundleCounts.length != 2) {
      throw const FormatException(
        'Approved workout release distribution is invalid.',
      );
    }
    return Map.unmodifiable(result);
  }

  static void _validateItemPins(
    Map<String, dynamic> json,
    WorkoutReleaseCatalogItem approval,
    Map<String, int> categoryOrders,
    Map<String, String> categoryDescriptions,
  ) {
    final id = _safeId(json['id'], 'id');
    final bundleId = _safeId(json['_release_bundle_id'], '_release_bundle_id');
    final primaryGroup = _safeId(
      json['_primary_plan_group_id'],
      '_primary_plan_group_id',
    );
    final groups = _safeIdList(json['_plan_group_ids'], '_plan_group_ids');
    final category = _safeId(json['category'], 'category');
    final categoryDescription = _text(
      json['category_description'],
      'category_description',
    );
    final categoryOrder = json['category_order'];
    if (json['_pack_schema_version'] is! int ||
        json['_pack_schema_version'] != 2 ||
        json['_pack_minimum_access'] != 'pro' ||
        id != approval.assetId ||
        bundleId != approval.bundleId ||
        json['_release_key'] != approval.releaseKey ||
        primaryGroup != approval.primaryGroupId ||
        !_sameList(groups, approval.planGroupIds) ||
        category != primaryGroup ||
        categoryOrder is! int ||
        categoryOrder < 0 ||
        json['duration_seconds'] != approval.durationMilliseconds! ~/ 1000 ||
        json['type'] != 'workouts' ||
        json['verified'] != true ||
        json['safety_reviewed'] != true ||
        json['human_safety_reviewed'] != true ||
        json['synthetic_performer'] != true) {
      throw const FormatException('Workout discovery metadata is invalid.');
    }

    final previousOrder = categoryOrders[category];
    final previousDescription = categoryDescriptions[category];
    if ((previousOrder != null && previousOrder != categoryOrder) ||
        (previousDescription != null &&
            previousDescription != categoryDescription)) {
      throw const FormatException(
        'Workout discovery category metadata is inconsistent.',
      );
    }
    categoryOrders[category] = categoryOrder;
    categoryDescriptions[category] = categoryDescription;

    final media = _object(json['media'], 'media');
    _exactKeys(media, const {'image', 'video'}, 'media');
    final video = _object(media['video'], 'media.video');
    _exactKeys(video, const {
      'media_role',
      'mime_type',
      'sha256',
      'size_bytes',
      'url',
    }, 'media.video');
    final videoUri = _https(video['url'], 'media.video.url');
    if (video['media_role'] != 'preview' ||
        video['mime_type'] != 'video/mp4' ||
        video['sha256'] != approval.expectedSha256 ||
        video['size_bytes'] != approval.expectedBytes ||
        videoUri.host != 'workouts.bilhealth.com' ||
        !videoUri.path.endsWith('/${approval.objectPath}')) {
      throw const FormatException('Workout discovery video pin is invalid.');
    }

    final image = _object(media['image'], 'media.image');
    _exactKeys(image, const {
      'derivation',
      'media_role',
      'mime_type',
      'rights',
      'sha256',
      'size_bytes',
      'source_frame_milliseconds',
      'source_video_sha256',
      'url',
    }, 'media.image');
    final imageDigest = _digest(image['sha256'], 'media.image.sha256');
    final imageSize = image['size_bytes'];
    final sourceFrame = image['source_frame_milliseconds'];
    final imageUri = _https(image['url'], 'media.image.url');
    final posterBundle = bundleId == 'home-training' ? 'home' : bundleId;
    final posterSuffix =
        '/workouts/v2/$posterBundle/posters/'
        '$id-$imageDigest.webp';
    if (image['derivation'] != 'ffmpeg-middle-frame-webp-360x640-q78-v1' ||
        image['media_role'] != 'preview' ||
        image['mime_type'] != 'image/webp' ||
        imageSize is! int ||
        imageSize <= 0 ||
        sourceFrame is! int ||
        sourceFrame != approval.durationMilliseconds! ~/ 2 ||
        image['source_video_sha256'] != approval.expectedSha256 ||
        imageUri.host != 'workouts.bilhealth.com' ||
        !imageUri.path.endsWith(posterSuffix)) {
      throw const FormatException('Workout discovery poster pin is invalid.');
    }
    _allRights(json['rights'], 'rights');
    _allRights(image['rights'], 'media.image.rights');
    if (json['source_url'] != videoUri.toString()) {
      throw const FormatException('Workout discovery source URL is invalid.');
    }
  }

  static void _allRights(Object? value, String field) {
    final rights = _object(value, field);
    _exactKeys(rights, const {'mobile', 'offline', 'paid'}, field);
    if (rights['mobile'] != true ||
        rights['offline'] != true ||
        rights['paid'] != true) {
      throw FormatException('$field is incomplete.');
    }
  }

  static Map<String, dynamic> _object(Object? value, String field) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$field must be an object.');
    }
    return value;
  }

  static List<dynamic> _list(Object? value, String field) {
    if (value is! List<dynamic>) {
      throw FormatException('$field must be a list.');
    }
    return value;
  }

  static List<String> _safeIdList(Object? value, String field) {
    final raw = value is List<String> ? value : _list(value, field);
    final result = <String>[];
    final seen = <String>{};
    for (final entry in raw) {
      final id = _safeId(entry, field);
      if (!seen.add(id)) throw FormatException('$field contains duplicates.');
      result.add(id);
    }
    return result;
  }

  static String _safeId(Object? value, String field) {
    final id = _text(value, field);
    if (!WorkoutReleaseMediaContract.canonicalMovementId.hasMatch(id)) {
      throw FormatException('$field is not a safe ID.');
    }
    return id;
  }

  static String _text(Object? value, String field) {
    if (value is! String || value.isEmpty || value != value.trim()) {
      throw FormatException('$field must contain trimmed text.');
    }
    return value;
  }

  static String _digest(Object? value, String field) {
    final digest = _text(value, field);
    if (!_isDigest(digest)) throw FormatException('$field is invalid.');
    return digest;
  }

  static bool _isDigest(Object? value) =>
      value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  static Uri _https(Object? value, String field) {
    final uri = Uri.tryParse(_text(value, field));
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('$field must be an HTTPS URL.');
    }
    return uri;
  }

  static void _exactKeys(
    Map<String, dynamic> value,
    Set<String> expected,
    String field,
  ) {
    final keys = value.keys.toSet();
    if (!_sameSet(keys, expected)) {
      throw FormatException('$field contains unknown or missing fields.');
    }
  }

  static bool _sameSet<T>(Set<T> left, Set<T> right) =>
      left.length == right.length && left.containsAll(right);

  static bool _sameList<T>(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
