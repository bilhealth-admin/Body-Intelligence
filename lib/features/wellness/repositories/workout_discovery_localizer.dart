import '../domain/wellness_content_pack.dart';
import '../presentation/workout_video_group_copy.dart';
import 'workout_discovery_arabic_transliteration.dart';
import 'workout_discovery_safe_copy.dart';

/// Safe display adapter for the 302 workout discovery cards.
///
/// The reviewed English exercise name remains canonical. Arabic adds a
/// phonetic Arabic rendering while retaining that English name; every other
/// locale shows the canonical name unchanged. Generated literal exercise-name
/// translations are intentionally outside this runtime contract.
final class WorkoutDiscoveryLocalizer {
  WorkoutDiscoveryLocalizer._(this._identityByStableId);

  static const itemCount = 302;

  static const localeTags = <String>[
    'en',
    'ar',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt-BR',
    'pt-PT',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh-Hans',
    'zh-Hant',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  ];

  static const expectedGroupCounts = <String, int>{
    'gym-exercise-technique': 23,
    'gym-full-body': 19,
    'gym-legs': 20,
    'gym-pull': 8,
    'gym-push': 10,
    'gym-warm-up-mobility': 22,
    'home-balance-coordination': 20,
    'home-cardio-conditioning': 20,
    'home-cardio-low-impact': 21,
    'home-core-stability': 19,
    'home-home-bodyweight': 21,
    'home-mobility-flexibility': 20,
    'home-recovery-beginner': 20,
    'home-resistance-full-body': 13,
    'home-resistance-lower-body': 20,
    'home-resistance-upper-body': 26,
  };

  final Map<String, _WorkoutDiscoveryIdentity> _identityByStableId;

  factory WorkoutDiscoveryLocalizer.fromDiscovery(
    List<WellnessContentItem> discovery,
  ) {
    if (discovery.length != itemCount) {
      throw const FormatException(
        'Workout discovery localization source must contain 302 items.',
      );
    }
    final groupCounts = <String, int>{};
    final identities = <String, _WorkoutDiscoveryIdentity>{};
    for (final item in discovery) {
      final category = item.category;
      if (item.type != WellnessContentType.workouts ||
          !item.verified ||
          item.locale != 'en' ||
          item.releaseKey == null ||
          item.releaseBundleId == null ||
          category == null ||
          !expectedGroupCounts.containsKey(category) ||
          item.categoryDescription?.trim().isEmpty != false ||
          item.title.trim().isEmpty ||
          item.description.trim().isEmpty ||
          item.equipment.isEmpty ||
          identities.containsKey(item.stableId)) {
        throw const FormatException(
          'Workout discovery localization identity is invalid.',
        );
      }
      // Validates the complete Arabic phonetic dictionary at construction,
      // even before an Arabic screen is opened.
      WorkoutDiscoveryArabicTransliteration.transliterate(item.title);
      groupCounts[category] = (groupCounts[category] ?? 0) + 1;
      identities[item.stableId] = _WorkoutDiscoveryIdentity(
        category: category,
        canonicalTitle: item.title,
        releaseBundleId: item.releaseBundleId!,
        equipmentCount: item.equipment.length,
        noEquipment:
            item.equipment.length == 1 && item.equipment.single == 'none',
      );
    }
    if (!_sameMap(groupCounts, expectedGroupCounts)) {
      throw const FormatException(
        'Workout discovery localization group coverage is invalid.',
      );
    }
    return WorkoutDiscoveryLocalizer._(Map.unmodifiable(identities));
  }

  WellnessContentItem localize(WellnessContentItem item, String localeTag) {
    if (!localeTags.contains(localeTag)) {
      throw FormatException(
        'Unsupported workout discovery locale: $localeTag.',
      );
    }
    final identity = _identityByStableId[item.stableId];
    if (identity == null ||
        item.type != WellnessContentType.workouts ||
        item.releaseKey != item.stableId ||
        item.releaseBundleId != identity.releaseBundleId) {
      throw const FormatException(
        'Workout discovery localization identity is unknown.',
      );
    }
    if (localeTag == 'en') return item;

    final copy = WorkoutDiscoverySafeCopy.forTag(localeTag);
    final groupTitle = workoutVideoGroupTitleForTag(
      localeTag,
      identity.category,
    );
    final visibleTitle = localeTag == 'ar'
        ? '${WorkoutDiscoveryArabicTransliteration.transliterate(identity.canonicalTitle)} '
              '— ${identity.canonicalTitle}'
        : identity.canonicalTitle;
    return WellnessContentItem(
      id: item.id,
      type: item.type,
      locale: localeTag,
      title: visibleTitle,
      description: copy.description(groupTitle),
      publisher: item.publisher,
      sourceUrl: item.sourceUrl,
      licenseName: item.licenseName,
      verified: item.verified,
      imageUrl: item.imageUrl,
      videoUrl: item.videoUrl,
      licenseUrl: item.licenseUrl,
      durationMinutes: item.durationMinutes,
      durationSeconds: item.durationSeconds,
      difficulty: item.difficulty,
      tags: item.tags,
      instructions: item.instructions,
      category: identity.category,
      categoryDescription: groupTitle,
      categoryOrder: item.categoryOrder,
      equipment: [
        identity.noEquipment
            ? copy.noEquipment
            : copy.equipmentCount(identity.equipmentCount),
      ],
      steps: item.steps,
      imageMedia: item.imageMedia,
      videoMedia: item.videoMedia,
      rights: item.rights,
      author: item.author,
      attribution: item.attribution,
      reviewedAt: item.reviewedAt,
      safetyReviewed: item.safetyReviewed,
      segments: item.segments,
      minimumAccess: item.minimumAccess,
      audience: item.audience,
      presenter: item.presenter,
      syntheticPerformer: item.syntheticPerformer,
      releaseBundleId: item.releaseBundleId,
      releaseKey: item.releaseKey,
      primaryPlanGroupId: item.primaryPlanGroupId,
      planGroupIds: item.planGroupIds,
    );
  }

  static bool _sameMap(Map<String, int> actual, Map<String, int> expected) {
    if (actual.length != expected.length) return false;
    for (final entry in expected.entries) {
      if (actual[entry.key] != entry.value) return false;
    }
    return true;
  }
}

final class _WorkoutDiscoveryIdentity {
  const _WorkoutDiscoveryIdentity({
    required this.category,
    required this.canonicalTitle,
    required this.releaseBundleId,
    required this.equipmentCount,
    required this.noEquipment,
  });

  final String category;
  final String canonicalTitle;
  final String releaseBundleId;
  final int equipmentCount;
  final bool noEquipment;
}
