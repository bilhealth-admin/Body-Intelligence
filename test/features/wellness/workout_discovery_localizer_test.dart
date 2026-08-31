import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/domain/workout_release_catalog_item.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/workout_video_group_copy.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_arabic_transliteration.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_catalog_repository.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_localizer.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_discovery_safe_copy.dart';
import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<WellnessContentItem> discovery;

  setUpAll(() {
    discovery = const WorkoutDiscoveryCatalogRepository().parse(
      File(WorkoutDiscoveryCatalogRepository.assetPath).readAsStringSync(),
      _approvedRelease(),
    );
  });

  test('authoritative parser retains provenance as internal metadata', () {
    expect(
      discovery,
      everyElement(
        isA<WellnessContentItem>()
            .having((item) => item.publisher.trim(), 'publisher', isNotEmpty)
            .having((item) => item.licenseName.trim(), 'license', isNotEmpty)
            .having((item) => item.author?.trim(), 'author', isNotEmpty)
            .having(
              (item) => item.attribution?.trim(),
              'attribution',
              isNotEmpty,
            ),
      ),
    );
  });

  test('all 302 IDs resolve under the explicit owner-approved name policy', () {
    final localizer = WorkoutDiscoveryLocalizer.fromDiscovery(discovery);
    expect(
      WorkoutDiscoveryLocalizer.localeTags.toSet(),
      BilLocalePolicy.productionTags,
    );
    expect(
      WorkoutDiscoverySafeCopy.supportedTags,
      BilLocalePolicy.productionTags.difference({'en'}),
    );

    var cardCount = 0;
    for (final tag in WorkoutDiscoveryLocalizer.localeTags) {
      final localized = discovery
          .map((item) => localizer.localize(item, tag))
          .toList(growable: false);
      expect(localized, hasLength(302), reason: tag);
      expect(
        localized.map((item) => item.stableId).toList(growable: false),
        discovery.map((item) => item.stableId).toList(growable: false),
        reason: tag,
      );

      for (var index = 0; index < localized.length; index += 1) {
        final source = discovery[index];
        final item = localized[index];
        if (tag == 'en') {
          expect(item, same(source), reason: source.stableId);
        } else {
          expect(item.locale, tag, reason: '${source.stableId}/locale');
          expect(
            item.description,
            isNot(source.description),
            reason: '${source.stableId}/description/$tag',
          );
          expect(
            item.categoryDescription,
            workoutVideoGroupTitleForTag(tag, source.category!),
            reason: '${source.stableId}/group/$tag',
          );
          expect(
            item.description,
            contains(item.categoryDescription),
            reason: '${source.stableId}/section-description/$tag',
          );
          expect(item.equipment, hasLength(1));
          expect(item.equipment.single.trim(), isNotEmpty);
          expect(item.equipment.single, isNot(source.equipment.join(', ')));
          if (tag == 'ar') {
            expect(
              item.title,
              endsWith('— ${source.title}'),
              reason: source.stableId,
            );
            expect(
              item.title,
              matches(RegExp(r'[\u0600-\u06FF]')),
              reason: source.stableId,
            );
          } else {
            expect(
              item.title,
              source.title,
              reason: '${source.stableId}/canonical-title/$tag',
            );
          }
        }

        // Display localization cannot alter release/access/media identity.
        expect(item.id, source.id);
        expect(item.releaseKey, source.releaseKey);
        expect(item.releaseBundleId, source.releaseBundleId);
        expect(item.minimumAccess, source.minimumAccess);
        expect(item.publisher, source.publisher);
        expect(item.licenseName, source.licenseName);
        expect(item.licenseUrl, source.licenseUrl);
        expect(item.author, source.author);
        expect(item.attribution, source.attribution);
        expect(item.imageMedia, same(source.imageMedia));
        expect(item.videoMedia, same(source.videoMedia));
        expect(item.instructions, same(source.instructions));
        expect(item.steps, same(source.steps));
        expect(item.segments, same(source.segments));

        final repeated = localizer.localize(source, tag);
        expect(repeated.title, item.title);
        expect(repeated.description, item.description);
        expect(repeated.categoryDescription, item.categoryDescription);
        expect(repeated.equipment, item.equipment);
        cardCount += 1;
      }
    }
    expect(cardCount, 302 * 25);
  });

  test(
    'Arabic titles are phonetic and retain searchable canonical English',
    () {
      final localizer = WorkoutDiscoveryLocalizer.fromDiscovery(discovery);
      final expected = <String, String>{
        'Bird dog': 'بيرد دوغ — Bird dog',
        'Air squat': 'إير سكوات — Air squat',
        'Adductor rock-back': 'أدَكتر روك باك — Adductor rock-back',
        'Supported child\'s pose':
            'سبورتِد تشايلدز بوز — Supported child\'s pose',
      };
      for (final entry in expected.entries) {
        final matches = discovery
            .where((item) => item.title == entry.key)
            .toList(growable: false);
        expect(matches, isNotEmpty, reason: entry.key);
        for (final source in matches) {
          final localized = localizer.localize(source, 'ar');
          expect(localized.title, entry.value);
          expect(workoutDiscoveryMatchesQuery(localized, entry.key), isTrue);
          expect(
            workoutDiscoveryMatchesQuery(
              localized,
              WorkoutDiscoveryArabicTransliteration.transliterate(entry.key),
            ),
            isTrue,
          );
        }
      }
      final birdDog = localizer.localize(
        discovery.firstWhere((item) => item.title == 'Bird dog'),
        'ar',
      );
      expect(workoutDiscoveryMatchesQuery(birdDog, 'bir'), isTrue);
      expect(workoutDiscoveryMatchesQuery(birdDog, 'بير'), isTrue);
      expect(workoutDiscoveryMatchesQuery(birdDog, 'air squat'), isFalse);

      final adductor = localizer.localize(
        discovery.firstWhere((item) => item.title == 'Adductor rock-back'),
        'ar',
      );
      expect(workoutDiscoveryMatchesQuery(adductor, 'ادكتر'), isTrue);
      expect(workoutDiscoveryMatchesQuery(adductor, 'ادكت'), isTrue);

      final supported = localizer.localize(
        discovery.firstWhere((item) => item.title == "Supported child's pose"),
        'ar',
      );
      expect(workoutDiscoveryMatchesQuery(supported, 'سبورتد'), isTrue);
      expect(workoutDiscoveryMatchesQuery(supported, 'سبور'), isTrue);
    },
  );

  test('Arabic cardio group uses reviewed fitness terminology', () {
    expect(
      workoutVideoGroupTitleForTag('ar', 'home-cardio-conditioning'),
      'تمارين اللياقة القلبية',
    );
  });

  test('unsafe literal artifact and known machine phrases are absent', () {
    expect(
      File(
        'artifacts/workout_media/workout_discovery_localizations_v1.json',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'tool/wellness_content/build_workout_discovery_localizations.py',
      ).existsSync(),
      isFalse,
    );
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('workout_discovery_localizations_v1')));
    final runtimeSources = [
      File(
        'lib/features/wellness/repositories/workout_discovery_localizer.dart',
      ).readAsStringSync(),
      File(
        'lib/features/wellness/repositories/workout_discovery_arabic_transliteration.dart',
      ).readAsStringSync(),
    ].join('\n');
    for (final unsafe in const [
      'كلب الطيور',
      'القرفصاء الهواء',
      'المقرب صخرة الظهر',
    ]) {
      expect(runtimeSources, isNot(contains(unsafe)), reason: unsafe);
    }
    expect(runtimeSources, isNot(contains('jsonDecode')));
  });

  test('source mutations and unknown runtime identities fail closed', () {
    expect(
      () => WorkoutDiscoveryLocalizer.fromDiscovery(
        discovery.take(301).toList(growable: false),
      ),
      throwsFormatException,
    );

    final duplicate = [...discovery]..[301] = discovery.first;
    expect(
      () => WorkoutDiscoveryLocalizer.fromDiscovery(duplicate),
      throwsFormatException,
    );

    final unverified = [...discovery]
      ..[0] = _copyItem(discovery.first, verified: false);
    expect(
      () => WorkoutDiscoveryLocalizer.fromDiscovery(unverified),
      throwsFormatException,
    );

    final missingPhoneticToken = [...discovery]
      ..[0] = _copyItem(discovery.first, title: 'Zzzq movement');
    expect(
      () => WorkoutDiscoveryLocalizer.fromDiscovery(missingPhoneticToken),
      throwsFormatException,
    );

    final localizer = WorkoutDiscoveryLocalizer.fromDiscovery(discovery);
    expect(
      () => localizer.localize(discovery.first, 'pt'),
      throwsFormatException,
    );
    expect(
      () => localizer.localize(
        _copyItem(discovery.first, releaseKey: 'home-training:unknown'),
        'ar',
      ),
      throwsFormatException,
    );
  });

  test('consumer details suppress internal English provenance copy', () {
    final details = File(
      'lib/features/wellness/presentation/bil_workout_routine_details.dart',
    ).readAsStringSync();

    expect(details, contains('Text(item.publisher)'));
    expect(details, isNot(contains('item.licenseName')));
    expect(details, isNot(contains('item.author')));
    expect(details, isNot(contains('item.attribution')));

    final library = File(
      'lib/features/wellness/presentation/bil_workout_routines_library.dart',
    ).readAsStringSync();
    expect(library, contains('workoutVideoGroupIds.contains(category)'));
    expect(
      library,
      contains('return workoutVideoGroupTitle(context, category);'),
    );
  });
}

WellnessContentItem _copyItem(
  WellnessContentItem item, {
  String? title,
  String? releaseKey,
  bool? verified,
}) => WellnessContentItem(
  id: item.id,
  type: item.type,
  locale: item.locale,
  title: title ?? item.title,
  description: item.description,
  publisher: item.publisher,
  sourceUrl: item.sourceUrl,
  licenseName: item.licenseName,
  verified: verified ?? item.verified,
  imageUrl: item.imageUrl,
  videoUrl: item.videoUrl,
  licenseUrl: item.licenseUrl,
  durationMinutes: item.durationMinutes,
  durationSeconds: item.durationSeconds,
  difficulty: item.difficulty,
  tags: item.tags,
  instructions: item.instructions,
  category: item.category,
  categoryDescription: item.categoryDescription,
  categoryOrder: item.categoryOrder,
  equipment: item.equipment,
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
  releaseKey: releaseKey ?? item.releaseKey,
  primaryPlanGroupId: item.primaryPlanGroupId,
  planGroupIds: item.planGroupIds,
);

List<WorkoutReleaseCatalogItem> _approvedRelease() => [
  ...WorkoutReleaseCatalogRepository.parseBundleManifest(
    File(
      'artifacts/workout_media/workout_release_bundle_home_v1.json',
    ).readAsStringSync(),
    expectedBundleId: 'home-training',
    expectedContentPackId: 'bil-workouts-home-v1',
    expectedRecordCount: WorkoutReleaseCatalogRepository.homeRecordCount,
  ),
  ...WorkoutReleaseCatalogRepository.parseBundleManifest(
    File(
      'artifacts/workout_media/workout_release_bundle_gym_six_month_v1.json',
    ).readAsStringSync(),
    expectedBundleId: 'gym-six-month',
    expectedContentPackId: 'bil-workouts-gym-six-month-v1',
    expectedRecordCount: WorkoutReleaseCatalogRepository.gymRecordCount,
  ),
];
