import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../domain/workout_release_catalog_item.dart';

class WorkoutReleaseCatalogRepository {
  const WorkoutReleaseCatalogRepository();

  static const registryAssetPath =
      'artifacts/workout_media/workout_release_bundle_registry_v1.json';
  static const releaseRecordCount = 302;
  static const approvedPlaybackCount = 302;
  static const uniquePayloadCount = 301;
  static const homeRecordCount = 200;
  static const gymRecordCount = 102;
  static Future<List<WorkoutReleaseCatalogItem>>? _cached;

  Future<List<WorkoutReleaseCatalogItem>> load() {
    final current = _cached;
    if (current != null) return current;
    final future = _loadBundledRegistry();
    _cached = future;
    future.catchError((Object _) {
      if (identical(_cached, future)) _cached = null;
      return <WorkoutReleaseCatalogItem>[];
    });
    return future;
  }

  static Future<List<WorkoutReleaseCatalogItem>> _loadBundledRegistry() async {
    final registrySource = await rootBundle.loadString(registryAssetPath);
    final bundles = parseRegistry(registrySource);
    final result = <WorkoutReleaseCatalogItem>[];
    for (final bundle in bundles) {
      final manifestSource = await rootBundle.loadString(bundle.manifestAsset);
      if (_sha256Text(manifestSource) != bundle.manifestSha256) {
        throw const FormatException('Workout bundle manifest hash mismatch.');
      }
      final approvalSource = await rootBundle.loadString(
        bundle.ownerApprovalAsset,
      );
      if (_sha256Text(approvalSource) != bundle.ownerApprovalSha256) {
        throw const FormatException('Workout owner approval hash mismatch.');
      }
      final items = parseBundleManifest(
        manifestSource,
        expectedBundleId: bundle.bundleId,
        expectedContentPackId: bundle.contentPackId,
        expectedRecordCount: bundle.playableCount,
      );
      validateOwnerApproval(
        approvalSource,
        bundleId: bundle.bundleId,
        items: items,
      );
      result.addAll(items);
    }
    _validateCombinedRelease(result);
    return List.unmodifiable(result);
  }

  static List<WorkoutBundleDescriptor> parseRegistry(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Workout registry must be an object.');
    }
    _keys(decoded, const {
      'schema',
      'bundleCount',
      'totalRecordCount',
      'playableCount',
      'uniquePayloadCount',
      'bundles',
    });
    final rawBundles = decoded['bundles'];
    if (decoded['schema'] != 'bil.workout-media.bundle-registry.v1' ||
        decoded['bundleCount'] != 2 ||
        decoded['totalRecordCount'] != releaseRecordCount ||
        decoded['playableCount'] != approvedPlaybackCount ||
        decoded['uniquePayloadCount'] != uniquePayloadCount ||
        rawBundles is! List ||
        rawBundles.length != 2) {
      throw const FormatException('Workout registry contract is invalid.');
    }
    final result = <WorkoutBundleDescriptor>[];
    final bundleIds = <String>{};
    for (final raw in rawBundles) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Workout bundle entry is invalid.');
      }
      _keys(raw, const {
        'bundleId',
        'contentPackId',
        'manifestAsset',
        'manifestSha256',
        'ownerApprovalAsset',
        'ownerApprovalSha256',
        'playableCount',
      });
      final bundleId = _safeId(raw['bundleId'], 'bundleId');
      final count = _positiveInt(raw['playableCount'], 'playableCount');
      if (!bundleIds.add(bundleId) ||
          (bundleId == 'home-training' && count != homeRecordCount) ||
          (bundleId == 'gym-six-month' && count != gymRecordCount) ||
          !const {'home-training', 'gym-six-month'}.contains(bundleId)) {
        throw const FormatException('Workout bundle distribution is invalid.');
      }
      result.add(
        WorkoutBundleDescriptor(
          bundleId: bundleId,
          contentPackId: _safeId(raw['contentPackId'], 'contentPackId'),
          manifestAsset: _assetPath(
            raw['manifestAsset'],
            'workout_release_bundle_',
          ),
          manifestSha256: _digest(raw['manifestSha256'], 'manifestSha256'),
          ownerApprovalAsset: _assetPath(
            raw['ownerApprovalAsset'],
            'workout_owner_approval_',
          ),
          ownerApprovalSha256: _digest(
            raw['ownerApprovalSha256'],
            'ownerApprovalSha256',
          ),
          playableCount: count,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static List<WorkoutReleaseCatalogItem> parseBundleManifest(
    String source, {
    required String expectedBundleId,
    required String expectedContentPackId,
    required int expectedRecordCount,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Workout bundle must be an object.');
    }
    _allowedKeys(decoded, const {
      'schema',
      'bundleId',
      'contentPackId',
      'title',
      'ownerApproval',
      'planGroups',
      'recordCount',
      'records',
      'recordsSha256',
      'summary',
      'sourcePlan',
    });
    final rawRecords = decoded['records'];
    final summary = decoded['summary'];
    final rawGroups = decoded['planGroups'];
    if (decoded['schema'] != 'bil.workout-media.bundle-release-manifest.v1' ||
        decoded['bundleId'] != expectedBundleId ||
        decoded['contentPackId'] != expectedContentPackId ||
        decoded['recordCount'] != expectedRecordCount ||
        rawRecords is! List ||
        rawRecords.length != expectedRecordCount ||
        summary is! Map<String, dynamic> ||
        summary['playable'] != expectedRecordCount ||
        summary['blocked'] != 0 ||
        summary['totalMediaBytes'] is! int ||
        rawGroups is! List ||
        rawGroups.isEmpty) {
      throw const FormatException('Workout bundle contract is invalid.');
    }
    final expectedDigest = _digest(decoded['recordsSha256'], 'recordsSha256');
    if (sha256.convert(utf8.encode(_canonical(rawRecords))).toString() !=
        expectedDigest) {
      throw const FormatException('Workout bundle records digest is invalid.');
    }
    final embeddedApproval = decoded['ownerApproval'];
    if (embeddedApproval is! Map<String, dynamic> ||
        embeddedApproval['approvedBy'] != 'BIL owner' ||
        embeddedApproval['decision'] != 'accept_all_without_exception' ||
        embeddedApproval['playableCount'] != expectedRecordCount) {
      throw const FormatException('Workout bundle owner decision is invalid.');
    }
    final groupIds = <String>{};
    for (final rawGroup in rawGroups) {
      if (rawGroup is! Map<String, dynamic> ||
          !_safeGroup(rawGroup, groupIds)) {
        throw const FormatException('Workout plan group is invalid.');
      }
    }

    final assetIds = <String>{};
    final releaseKeys = <String>{};
    final objectPaths = <String>{};
    final result = <WorkoutReleaseCatalogItem>[];
    var totalBytes = 0;
    for (final raw in rawRecords) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Workout bundle record is invalid.');
      }
      final item = _parseApprovedRecord(
        raw,
        bundleId: expectedBundleId,
        contentPackId: expectedContentPackId,
        groupIds: groupIds,
      );
      if (!assetIds.add(item.assetId) ||
          !releaseKeys.add(item.releaseKey) ||
          !objectPaths.add(item.objectPath!)) {
        throw const FormatException('Workout bundle identity is duplicated.');
      }
      totalBytes += item.expectedBytes!;
      result.add(item);
    }
    if (totalBytes != summary['totalMediaBytes']) {
      throw const FormatException('Workout bundle byte total is invalid.');
    }
    return List.unmodifiable(result);
  }

  static WorkoutReleaseCatalogItem _parseApprovedRecord(
    Map<String, dynamic> raw, {
    required String bundleId,
    required String contentPackId,
    required Set<String> groupIds,
  }) {
    final required = <String>{
      'assetId',
      'bundleId',
      'byteLength',
      'candidateAvailable',
      'codecName',
      'durationMilliseconds',
      'exerciseId',
      'fpsDenominator',
      'fpsNumerator',
      'frameCount',
      'height',
      'mimeType',
      'objectPath',
      'planGroupIds',
      'playable',
      'primaryGroupId',
      'releaseKey',
      'reviewStatus',
      'sha256',
      'sourceGroup',
      'width',
    };
    _requiredAndAllowedKeys(raw, required, {...required, 'lineage'});
    final assetId = _safeId(raw['assetId'], 'assetId');
    final exerciseId = _safeId(raw['exerciseId'], 'exerciseId');
    final releaseKey = _text(raw['releaseKey'], 'releaseKey');
    final objectPath = _text(raw['objectPath'], 'objectPath');
    final primaryGroupId = _safeId(raw['primaryGroupId'], 'primaryGroupId');
    final rawPlanGroups = raw['planGroupIds'];
    if (raw['bundleId'] != bundleId ||
        raw['candidateAvailable'] != true ||
        raw['playable'] != true ||
        raw['reviewStatus'] != 'human_approved' ||
        raw['mimeType'] != 'video/mp4' ||
        releaseKey != '$bundleId:$assetId' ||
        objectPath != _expectedObjectPath(bundleId, assetId) ||
        rawPlanGroups is! List ||
        rawPlanGroups.isEmpty) {
      throw const FormatException('Workout approval/identity is invalid.');
    }
    final planGroups = rawPlanGroups
        .map((value) => _safeId(value, 'planGroupIds'))
        .toList(growable: false);
    if (planGroups.toSet().length != planGroups.length ||
        !planGroups.contains(primaryGroupId) ||
        !groupIds.containsAll(planGroups)) {
      throw const FormatException('Workout plan membership is invalid.');
    }
    final bytes = _positiveInt(raw['byteLength'], 'byteLength');
    final duration = _positiveInt(
      raw['durationMilliseconds'],
      'durationMilliseconds',
    );
    final frames = _positiveInt(raw['frameCount'], 'frameCount');
    final fpsNumerator = _positiveInt(raw['fpsNumerator'], 'fpsNumerator');
    final fpsDenominator = _positiveInt(
      raw['fpsDenominator'],
      'fpsDenominator',
    );
    final width = _positiveInt(raw['width'], 'width');
    final height = _positiveInt(raw['height'], 'height');
    final codec = _text(raw['codecName'], 'codecName');
    final technical =
        fpsNumerator == 30 &&
        fpsDenominator == 1 &&
        width == 720 &&
        height == 1280 &&
        codec == 'h264' &&
        ((duration == 7000 && frames == 210) ||
            (duration == 10000 && frames == 300));
    if (!technical ||
        (bundleId == 'gym-six-month' && (duration != 10000 || frames != 300))) {
      throw const FormatException('Workout delivery media is incompatible.');
    }
    final lineage = raw['lineage'];
    if (lineage != null &&
        (lineage is! Map<String, dynamic> ||
            lineage['operation'] != 'non_destructive_h264_delivery_transcode' ||
            lineage['sourceCodecName'] != 'mpeg4' ||
            lineage['sourcePreserved'] != true ||
            !_isDigest(lineage['sourceSha256']))) {
      throw const FormatException('Workout delivery lineage is invalid.');
    }
    return WorkoutReleaseCatalogItem(
      bundleId: bundleId,
      contentPackId: contentPackId,
      assetId: assetId,
      exerciseId: exerciseId,
      releaseKey: releaseKey,
      slot: primaryGroupId,
      objectPath: objectPath,
      primaryGroupId: primaryGroupId,
      planGroupIds: List.unmodifiable(planGroups),
      expectedSha256: _digest(raw['sha256'], 'sha256'),
      expectedBytes: bytes,
      durationMilliseconds: duration,
      frameCount: frames,
      fpsNumerator: fpsNumerator,
      fpsDenominator: fpsDenominator,
      width: width,
      height: height,
      codecName: codec,
      availability: WorkoutReleaseAvailability.approved,
    );
  }

  static void validateOwnerApproval(
    String source, {
    required String bundleId,
    required List<WorkoutReleaseCatalogItem> items,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Workout owner approval is invalid.');
    }
    _keys(decoded, const {
      'schema',
      'bundleId',
      'approvedBy',
      'decision',
      'ownerApprovedCount',
      'approvedReleaseKeysSha256',
      'qualifiedBiomechanicsCertification',
    });
    final keys = items.map((item) => item.releaseKey).toList(growable: false);
    if (decoded['schema'] != 'bil.workout-media.bundle-owner-approval.v1' ||
        decoded['bundleId'] != bundleId ||
        decoded['approvedBy'] != 'BIL owner' ||
        decoded['decision'] != 'accept_all_without_exception' ||
        decoded['ownerApprovedCount'] != items.length ||
        decoded['qualifiedBiomechanicsCertification'] != false ||
        decoded['approvedReleaseKeysSha256'] !=
            sha256.convert(utf8.encode(_canonical(keys))).toString()) {
      throw const FormatException('Workout owner approval does not match.');
    }
  }

  static void _validateCombinedRelease(List<WorkoutReleaseCatalogItem> items) {
    final releaseKeys = items.map((item) => item.releaseKey).toSet();
    final payloads = items.map((item) => item.expectedSha256).toSet();
    final home = items.where((item) => item.bundleId == 'home-training');
    final gym = items.where((item) => item.bundleId == 'gym-six-month');
    if (items.length != releaseRecordCount ||
        releaseKeys.length != releaseRecordCount ||
        payloads.length != uniquePayloadCount ||
        home.length != homeRecordCount ||
        gym.length != gymRecordCount ||
        items.any((item) => !item.canPlay)) {
      throw const FormatException('Combined workout release is invalid.');
    }
  }

  static bool _safeGroup(Map<String, dynamic> raw, Set<String> ids) {
    try {
      _keys(raw, const {'id', 'order', 'title'});
      final id = _safeId(raw['id'], 'planGroup.id');
      return ids.add(id) &&
          raw['order'] is int &&
          (raw['order'] as int) >= 0 &&
          _text(raw['title'], 'planGroup.title').isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  static String _expectedObjectPath(String bundleId, String assetId) =>
      bundleId == 'home-training'
      ? 'workouts/v1/home/movements/$assetId.mp4'
      : 'workouts/v1/gym-six-month/movements/$assetId.mp4';

  static String _assetPath(Object? value, String requiredFilenamePrefix) {
    final path = _text(value, 'assetPath');
    if (!RegExp(
      '^artifacts/workout_media/$requiredFilenamePrefix[a-z0-9_-]+\\.json\$',
    ).hasMatch(path)) {
      throw const FormatException('Workout registry asset path is invalid.');
    }
    return path;
  }

  static String _safeId(Object? value, String field) {
    final text = _text(value, field);
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(text)) {
      throw FormatException('$field is invalid.');
    }
    return text;
  }

  static String _digest(Object? value, String field) {
    final text = _text(value, field);
    if (!_isDigest(text)) throw FormatException('$field is invalid.');
    return text;
  }

  static bool _isDigest(Object? value) =>
      value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  static String _sha256Text(String source) =>
      sha256.convert(utf8.encode(source)).toString();

  static void _keys(Map<String, dynamic> value, Set<String> expected) {
    if (value.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('Workout manifest fields are invalid.');
    }
  }

  static void _allowedKeys(Map<String, dynamic> value, Set<String> allowed) {
    if (value.keys.toSet().difference(allowed).isNotEmpty) {
      throw const FormatException('Workout manifest fields are invalid.');
    }
  }

  static void _requiredAndAllowedKeys(
    Map<String, dynamic> value,
    Set<String> required,
    Set<String> allowed,
  ) {
    if (required.difference(value.keys.toSet()).isNotEmpty ||
        value.keys.toSet().difference(allowed).isNotEmpty) {
      throw const FormatException('Workout record fields are invalid.');
    }
  }

  static String _text(Object? value, String field) {
    if (value is! String || value.isEmpty || value != value.trim()) {
      throw FormatException('$field is invalid.');
    }
    return value;
  }

  static int _positiveInt(Object? value, String field) {
    if (value is! int || value <= 0) {
      throw FormatException('$field is invalid.');
    }
    return value;
  }

  static String _canonical(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is int) return value.toString();
    if (value is String) return jsonEncode(value);
    if (value is List) return '[${value.map(_canonical).join(',')}]';
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
    }
    throw const FormatException('Unsupported workout manifest value.');
  }
}

class WorkoutBundleDescriptor {
  const WorkoutBundleDescriptor({
    required this.bundleId,
    required this.contentPackId,
    required this.manifestAsset,
    required this.manifestSha256,
    required this.ownerApprovalAsset,
    required this.ownerApprovalSha256,
    required this.playableCount,
  });

  final String bundleId;
  final String contentPackId;
  final String manifestAsset;
  final String manifestSha256;
  final String ownerApprovalAsset;
  final String ownerApprovalSha256;
  final int playableCount;
}
