import 'dart:convert';
import 'dart:io';

import '../domain/workout_release_catalog_item.dart';
import '../domain/wellness_content_pack.dart';
import '../repositories/workout_release_catalog_repository.dart';

/// Enforces the owner-approved workout release contract at every local pack
/// trust boundary. Approval data is loaded fail-closed: an unavailable,
/// malformed, duplicate, or incomplete approval manifest rejects the pack.
class WorkoutReleaseVerifier {
  const WorkoutReleaseVerifier(this._releaseLoader);

  final Future<List<WorkoutReleaseCatalogItem>> Function() _releaseLoader;

  Future<void> validatePayload(File file, WellnessContentPack pack) async {
    final data = jsonDecode(await file.readAsString());
    final schemaVersion = data is Map<String, dynamic>
        ? (data['schema_version'] as num?)?.toInt()
        : null;
    if (data is! Map<String, dynamic> ||
        (schemaVersion != 1 && schemaVersion != 2) ||
        schemaVersion != pack.schemaVersion ||
        data['pack_id'] != pack.id ||
        data['version'] != pack.version ||
        data['type'] != pack.type.name ||
        data['items'] is! List) {
      throw const FormatException('Invalid wellness pack payload.');
    }
    final items = data['items'] as List;
    if (items.length != pack.itemCount) {
      throw const FormatException('Wellness pack item count mismatch.');
    }
    final declaredCategories = <String>{};
    Map<String, WorkoutReleaseCatalogItem>? approvedWorkouts;
    if (schemaVersion == 2 && pack.type == WellnessContentType.workouts) {
      approvedWorkouts = (await approvedRelease())[pack.id];
      if (approvedWorkouts == null) {
        throw const FormatException(
          'Workout pack is not registered in the approved bundle registry.',
        );
      }
      final rawCategories = data['categories'];
      if (rawCategories is! List) {
        throw const FormatException('Workout categories must be declared.');
      }
      declaredCategories.addAll(
        rawCategories
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
      if (declaredCategories.isEmpty ||
          declaredCategories.length != rawCategories.length) {
        throw const FormatException('Workout categories are invalid.');
      }
      final approvedCategories = approvedWorkouts.values
          .map((item) => item.primaryGroupId)
          .toSet();
      if (declaredCategories.length != approvedCategories.length ||
          !declaredCategories.containsAll(approvedCategories)) {
        throw const FormatException(
          'Workout categories do not match the approved release.',
        );
      }
      if (items.length != approvedWorkouts.length) {
        throw const FormatException(
          'The workout pack must contain its complete approved bundle.',
        );
      }
    }
    final categoryCounts = <String, int>{};
    final categoryDescriptions = <String, String>{};
    final categoryOrders = <String, int>{};
    final itemIds = <String>{};
    final videoUrls = <Uri>{};
    final videoDigests = <String>{};
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid wellness content item.');
      }
      final item = WellnessContentItem.fromJson(
        raw,
        expectedType: pack.type,
        schemaVersion: schemaVersion!,
      );
      if (schemaVersion == 2 && pack.type == WellnessContentType.workouts) {
        final approval = approvedWorkouts![item.id];
        if (approval == null || !_workoutMatchesApproval(item, approval)) {
          throw const FormatException(
            'Workout media is not in the owner-approved release.',
          );
        }
        if (!itemIds.add(item.id)) {
          throw const FormatException('Duplicate workout movement id.');
        }
        if (!WorkoutReleaseMediaContract.canonicalMovementId.hasMatch(
          item.id,
        )) {
          throw const FormatException(
            'Workout movement id, duration, or video filename violates the release contract.',
          );
        }
        final category = item.category!;
        if (!declaredCategories.contains(category)) {
          throw const FormatException('Workout uses an undeclared category.');
        }
        categoryCounts.update(
          category,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final description = item.categoryDescription!;
        final order = item.categoryOrder!;
        final existingDescription = categoryDescriptions[category];
        final existingOrder = categoryOrders[category];
        if ((existingDescription != null &&
                existingDescription != description) ||
            (existingOrder != null && existingOrder != order)) {
          throw const FormatException(
            'Workout category metadata must be consistent.',
          );
        }
        categoryDescriptions[category] = description;
        categoryOrders[category] = order;
        final video = item.videoMedia!;
        if (!videoUrls.add(video.url) || !videoDigests.add(video.sha256)) {
          throw const FormatException('Duplicate workout video media.');
        }
        for (final segment in item.segments) {
          if (!videoUrls.add(segment.videoMedia.url) ||
              !videoDigests.add(segment.videoMedia.sha256)) {
            throw const FormatException('Duplicate workout video media.');
          }
        }
        if (pack.minimumAccess != WellnessContentAccess.free &&
            item.rights?.paid != true) {
          throw const FormatException(
            'Paid workout packs require paid distribution rights.',
          );
        }
      }
    }
    if (approvedWorkouts != null) {
      final approvedCategoryCounts = <String, int>{};
      for (final approval in approvedWorkouts.values) {
        approvedCategoryCounts.update(
          approval.primaryGroupId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (itemIds.length != approvedWorkouts.length ||
          !itemIds.containsAll(approvedWorkouts.keys) ||
          declaredCategories.any(
            (category) =>
                categoryCounts[category] != approvedCategoryCounts[category],
          )) {
        throw const FormatException(
          'Workout release identities or category counts are incomplete.',
        );
      }
    }
  }

  Future<Map<String, Map<String, WorkoutReleaseCatalogItem>>>
  approvedRelease() async {
    List<WorkoutReleaseCatalogItem> release;
    try {
      release = await _releaseLoader();
    } on Object {
      throw const FormatException(
        'The bundled workout approval manifest is unavailable.',
      );
    }
    final approved = <String, Map<String, WorkoutReleaseCatalogItem>>{};
    for (final item in release.where((item) => item.canPlay)) {
      final bundle = approved.putIfAbsent(item.contentPackId, () => {});
      if (item.objectPath == null || bundle[item.assetId] != null) {
        throw const FormatException(
          'The bundled workout approval manifest is invalid.',
        );
      }
      bundle[item.assetId] = item;
    }
    if (approved.length != 2 ||
        approved.values.fold<int>(0, (sum, bundle) => sum + bundle.length) !=
            WorkoutReleaseCatalogRepository.approvedPlaybackCount ||
        approved['bil-workouts-home-v1']?.length !=
            WorkoutReleaseCatalogRepository.homeRecordCount ||
        approved['bil-workouts-gym-six-month-v1']?.length !=
            WorkoutReleaseCatalogRepository.gymRecordCount) {
      throw const FormatException(
        'The bundled workout approval count is invalid.',
      );
    }
    return {
      for (final entry in approved.entries)
        entry.key: Map.unmodifiable(entry.value),
    };
  }

  static bool rawWorkoutMatchesApproval(
    Map<String, dynamic> raw,
    WorkoutReleaseCatalogItem approval,
  ) {
    final media = raw['media'];
    final video = media is Map<String, dynamic> ? media['video'] : null;
    final segments = raw['segments'];
    if (video is! Map<String, dynamic> ||
        (segments != null && (segments is! List || segments.isNotEmpty))) {
      return false;
    }
    final url = Uri.tryParse(video['url']?.toString() ?? '');
    return raw['duration_seconds'] == approval.durationMilliseconds! ~/ 1000 &&
        video['mime_type'] == 'video/mp4' &&
        video['sha256'] == approval.expectedSha256 &&
        video['size_bytes'] == approval.expectedBytes &&
        url != null &&
        url.scheme == 'https' &&
        url.path.endsWith('/${approval.objectPath}');
  }

  static bool _workoutMatchesApproval(
    WellnessContentItem item,
    WorkoutReleaseCatalogItem approval,
  ) {
    final video = item.videoMedia;
    return video != null &&
        item.durationSeconds == approval.durationMilliseconds! ~/ 1000 &&
        item.segments.isEmpty &&
        video.mimeType == 'video/mp4' &&
        video.sha256 == approval.expectedSha256 &&
        video.sizeBytes == approval.expectedBytes &&
        video.url.path.endsWith('/${approval.objectPath}');
  }
}
