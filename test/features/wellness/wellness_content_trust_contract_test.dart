import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> trustedItem() => <String, dynamic>{
    'id': 'recipe-1',
    'type': 'recipes',
    'locale': 'ar',
    'title': 'وصفة موثقة',
    'description': 'وصفة منشورة من مصدر معروف.',
    'publisher': 'Verified Publisher',
    'source_url': 'https://example.org/recipes/1',
    'license_name': 'Licensed content',
    'license_url': 'https://example.org/license',
    'image_url': 'https://example.org/images/1.jpg',
    'verified': true,
    'duration_minutes': 20,
    'instructions': <String>['Step one'],
  };

  Map<String, dynamic> trustedWorkout() => <String, dynamic>{
    'id': 'strength-001',
    'type': 'workouts',
    'locale': 'en',
    'title': 'Supported squat',
    'description': 'A safety-reviewed movement demonstration.',
    'publisher': 'Verified Publisher',
    'source_url': 'https://example.org/workouts/strength-001',
    'license_name': 'Commercial mobile license',
    'license_url': 'https://example.org/license',
    'verified': true,
    'duration_minutes': 5,
    'category': 'strength',
    'category_description': 'Foundational strength routines.',
    'category_order': 0,
    'equipment': <String>['chair'],
    'steps': <String>['Stand tall.', 'Lower under control.'],
    'author': 'Qualified exercise professional',
    'attribution': 'Licensed to BIL.',
    'reviewed_at': '2026-01-01T00:00:00Z',
    'safety_reviewed': true,
    'rights': <String, dynamic>{'mobile': true, 'paid': true, 'offline': true},
    'media': <String, dynamic>{
      'image': <String, dynamic>{
        'url': 'https://cdn.example.org/strength-001.webp',
        'mime_type': 'image/webp',
        'sha256': List<String>.filled(64, 'a').join(),
        'size_bytes': 12000,
      },
      'video': <String, dynamic>{
        'url': 'https://cdn.example.org/strength-001.mp4',
        'mime_type': 'video/mp4',
        'sha256': List<String>.filled(64, 'b').join(),
        'size_bytes': 900000,
      },
    },
    'segments': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'supported-squat',
        'title': 'Supported squat',
        'instruction': 'Lower under control through a comfortable range.',
        'reps': 8,
        'rest_seconds': 20,
        'optional': false,
        'media': <String, dynamic>{
          'image': <String, dynamic>{
            'url': 'https://cdn.example.org/segments/squat.webp',
            'mime_type': 'image/webp',
            'sha256': List<String>.filled(64, 'c').join(),
            'size_bytes': 8000,
          },
          'video': <String, dynamic>{
            'url': 'https://cdn.example.org/segments/squat.mp4',
            'mime_type': 'video/mp4',
            'sha256': List<String>.filled(64, 'd').join(),
            'size_bytes': 400000,
          },
        },
      },
    ],
  };

  test('trusted wellness content requires attribution and HTTPS media', () {
    final item = WellnessContentItem.fromJson(
      trustedItem(),
      expectedType: WellnessContentType.recipes,
    );

    expect(item.verified, isTrue);
    expect(item.publisher, 'Verified Publisher');
    expect(item.sourceUrl.scheme, 'https');
    expect(item.licenseName, isNotEmpty);
  });

  test('unverified or unattributed content fails closed', () {
    final unverified = trustedItem()..['verified'] = false;
    final unattributed = trustedItem()..remove('publisher');
    final insecure = trustedItem()
      ..['image_url'] = 'http://example.org/image.jpg';

    for (final payload in <Map<String, dynamic>>[
      unverified,
      unattributed,
      insecure,
    ]) {
      expect(
        () => WellnessContentItem.fromJson(
          payload,
          expectedType: WellnessContentType.recipes,
        ),
        throwsFormatException,
      );
    }
  });

  test('content pack manifest requires integrity and provenance', () {
    final pack = <String, dynamic>{
      'id': 'recipes-ar',
      'version': 1,
      'type': 'recipes',
      'title': 'Arabic recipes',
      'download_url': 'https://example.org/recipes.json',
      'size_bytes': 42,
      'sha256': List<String>.filled(64, 'a').join(),
      'item_count': 1,
      'publisher': 'Verified Publisher',
      'source_url': 'https://example.org/catalog',
      'license_name': 'Licensed content',
      'license_url': 'https://example.org/license',
    };

    expect(WellnessContentPack.fromJson(pack).publisher, isNotEmpty);
    expect(WellnessContentPack.fromJson(pack).schemaVersion, 1);
    expect(
      () => WellnessContentPack.fromJson(
        Map<String, dynamic>.from(pack)..remove('license_name'),
      ),
      throwsFormatException,
    );
    expect(
      () => WellnessContentPack.fromJson(
        Map<String, dynamic>.from(pack)..['id'] = '../outside',
      ),
      throwsFormatException,
    );
    expect(
      () => WellnessContentPack.fromJson(
        Map<String, dynamic>.from(pack)..['version'] = 1.5,
      ),
      throwsFormatException,
    );
  });

  test('schema v2 workout exposes reviewed licensed media metadata', () {
    final item = WellnessContentItem.fromJson(
      trustedWorkout(),
      expectedType: WellnessContentType.workouts,
      schemaVersion: 2,
    );

    expect(item.category, 'strength');
    expect(item.categoryDescription, 'Foundational strength routines.');
    expect(item.categoryOrder, 0);
    expect(item.equipment, <String>['chair']);
    expect(item.steps, hasLength(2));
    expect(item.segments, hasLength(1));
    expect(item.segments.single.repetitions, 8);
    expect(item.segments.single.videoMedia.mimeType, 'video/mp4');
    expect(
      item.segments.single.videoMedia.mediaRole,
      WellnessMediaRole.instruction,
    );
    expect(item.videoMedia?.mimeType, 'video/mp4');
    expect(item.videoMedia?.mediaRole, WellnessMediaRole.preview);
    expect(item.videoMedia?.sizeBytes, 900000);
    expect(item.rights?.mobile, isTrue);
    expect(item.rights?.paid, isTrue);
    expect(item.rights?.offline, isTrue);
    expect(item.safetyReviewed, isTrue);
    expect(item.reviewedAt, DateTime.utc(2026));
    expect(item.audience, WellnessWorkoutAudience.all);
    expect(item.presenter, WellnessWorkoutPresenter.neutral);
    expect(item.syntheticPerformer, isFalse);
  });

  test('workout presentation metadata is typed when explicitly declared', () {
    final payload = trustedWorkout()
      ..['audience'] = 'women'
      ..['presenter'] = 'adult_female'
      ..['synthetic_performer'] = true;
    ((payload['media'] as Map<String, dynamic>)['video']
            as Map<String, dynamic>)['media_role'] =
        'preview';
    final segment = (payload['segments'] as List<Map<String, dynamic>>).single;
    ((segment['media'] as Map<String, dynamic>)['video']
            as Map<String, dynamic>)['media_role'] =
        'instruction';

    final item = WellnessContentItem.fromJson(
      payload,
      expectedType: WellnessContentType.workouts,
      schemaVersion: 2,
    );

    expect(item.audience, WellnessWorkoutAudience.women);
    expect(item.presenter, WellnessWorkoutPresenter.adultFemale);
    expect(item.syntheticPerformer, isTrue);
    expect(item.videoMedia?.mediaRole, WellnessMediaRole.preview);
    expect(
      item.segments.single.videoMedia.mediaRole,
      WellnessMediaRole.instruction,
    );

    final maleItem = WellnessContentItem.fromJson(
      trustedWorkout()
        ..['audience'] = 'men'
        ..['presenter'] = 'adult_male',
      expectedType: WellnessContentType.workouts,
      schemaVersion: 2,
    );
    expect(maleItem.audience, WellnessWorkoutAudience.men);
    expect(maleItem.presenter, WellnessWorkoutPresenter.adultMale);
    expect(maleItem.syntheticPerformer, isFalse);
  });

  test('invalid workout presentation metadata fails closed', () {
    final invalidAudience = trustedWorkout()..['audience'] = 'children';
    final invalidPresenter = trustedWorkout()..['presenter'] = 'model';
    final invalidSynthetic = trustedWorkout()..['synthetic_performer'] = 'yes';
    final invalidMediaRole = trustedWorkout();
    ((invalidMediaRole['media'] as Map<String, dynamic>)['video']
            as Map<String, dynamic>)['media_role'] =
        'demo';

    for (final payload in <Map<String, dynamic>>[
      invalidAudience,
      invalidPresenter,
      invalidSynthetic,
      invalidMediaRole,
    ]) {
      expect(
        () => WellnessContentItem.fromJson(
          payload,
          expectedType: WellnessContentType.workouts,
          schemaVersion: 2,
        ),
        throwsFormatException,
      );
    }
  });

  test('pack access metadata is typed and backward compatible', () {
    final premiumItem = WellnessContentItem.fromJson(
      trustedWorkout()..['_pack_minimum_access'] = 'pro',
      expectedType: WellnessContentType.workouts,
      schemaVersion: 2,
    );
    final legacyItem = WellnessContentItem.fromJson(
      trustedWorkout(),
      expectedType: WellnessContentType.workouts,
      schemaVersion: 2,
    );
    final installed = InstalledWellnessContentPack(
      id: 'strength-pack',
      version: 1,
      path: 'strength-pack-1.json',
      installedAt: DateTime.utc(2026),
      minimumAccess: WellnessContentAccess.plus,
    );
    final legacyInstalled =
        InstalledWellnessContentPack.fromJson(<String, dynamic>{
          'id': 'legacy-pack',
          'version': 1,
          'path': 'legacy-pack-1.json',
          'installed_at': '2026-01-01T00:00:00Z',
        });

    expect(premiumItem.minimumAccess, WellnessContentAccess.pro);
    expect(legacyItem.minimumAccess, WellnessContentAccess.free);
    expect(
      InstalledWellnessContentPack.fromJson(installed.toJson()).minimumAccess,
      WellnessContentAccess.plus,
    );
    expect(legacyInstalled.minimumAccess, WellnessContentAccess.free);
    expect(
      () => WellnessContentItem.fromJson(
        trustedWorkout()..['_pack_minimum_access'] = 'unknown',
        expectedType: WellnessContentType.workouts,
        schemaVersion: 2,
      ),
      throwsFormatException,
    );
  });

  test('schema v2 workout fails closed on unsafe media or rights', () {
    final insecure = trustedWorkout();
    (insecure['media']
        as Map<String, dynamic>)['video'] = Map<String, dynamic>.from(
      (insecure['media'] as Map<String, dynamic>)['video']
          as Map<String, dynamic>,
    )..['url'] = 'http://example.org/video.mp4';
    final unlicensed = trustedWorkout();
    (unlicensed['rights'] as Map<String, dynamic>)['offline'] = false;
    final unsupportedImage = trustedWorkout();
    ((unsupportedImage['media'] as Map<String, dynamic>)['image']
            as Map<String, dynamic>)['mime_type'] =
        'image/gif';
    final unreviewed = trustedWorkout()..['safety_reviewed'] = false;
    final duplicateSegmentMedia = trustedWorkout();
    final duplicateSegments =
        duplicateSegmentMedia['segments'] as List<Map<String, dynamic>>;
    duplicateSegments.add(
      Map<String, dynamic>.from(duplicateSegments.single)
        ..['id'] = 'duplicate-segment',
    );

    for (final payload in <Map<String, dynamic>>[
      insecure,
      unlicensed,
      unsupportedImage,
      unreviewed,
      duplicateSegmentMedia,
    ]) {
      expect(
        () => WellnessContentItem.fromJson(
          payload,
          expectedType: WellnessContentType.workouts,
          schemaVersion: 2,
        ),
        throwsFormatException,
      );
    }
  });

  test('schema v1 recipe remains backward compatible', () {
    final recipe = WellnessContentItem.fromJson(
      trustedItem(),
      expectedType: WellnessContentType.recipes,
      schemaVersion: 1,
    );

    expect(recipe.title, isNotEmpty);
    expect(recipe.videoMedia, isNull);
    expect(recipe.rights, isNull);
  });

  test(
    'production library consumes release-approved items and exposes activity log',
    () {
      final pageSource = File(
        'lib/features/wellness/presentation/bil_workout_routines_page.dart',
      ).readAsStringSync();
      final managerSource = File(
        'lib/features/wellness/services/wellness_content_pack_manager.dart',
      ).readAsStringSync();

      expect(
        pageSource,
        contains('_manager.loadWorkoutLibraryItems(locale: locale)'),
      );
      expect(pageSource, isNot(contains('_manager.loadInstalledItems(')));
      expect(pageSource, contains('dailyLogRepositoryProvider'));
      expect(pageSource, contains("'kind': 'trusted_workout_routine'"));
      expect(pageSource, isNot(contains("'calories'")));

      // Discovery is not a trust bypass: the complete catalog is parsed
      // against the approved release, and an installed override is accepted
      // only when its exact pack version, count, bundle and stable IDs match.
      expect(managerSource, contains('await _workoutReleaseLoader()'));
      expect(
        managerSource,
        contains('WorkoutDiscoveryCatalogRepository.itemCount'),
      );
      expect(
        managerSource,
        contains(
          'WorkoutDiscoveryCatalogRepository.releasePackVersions[packId]',
        ),
      );
      expect(managerSource, contains('entry.value.length != expectedCount'));
      expect(managerSource, contains('item.releaseBundleId != expectedBundle'));
      expect(
        managerSource,
        contains('!installedItems.keys.toSet().containsAll(expectedStableIds)'),
      );
    },
  );
}
