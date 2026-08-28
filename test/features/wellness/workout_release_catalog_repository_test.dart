import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/repositories/workout_release_catalog_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test(
    'registry proves two owner-approved bundles and 302 logical records',
    () {
      final registrySource = read(
        WorkoutReleaseCatalogRepository.registryAssetPath,
      );
      final descriptors = WorkoutReleaseCatalogRepository.parseRegistry(
        registrySource,
      );
      expect(descriptors, hasLength(2));

      final all = <dynamic>[];
      for (final descriptor in descriptors) {
        final manifestSource = read(descriptor.manifestAsset);
        final approvalSource = read(descriptor.ownerApprovalAsset);
        expect(
          sha256.convert(utf8.encode(manifestSource)).toString(),
          descriptor.manifestSha256,
        );
        expect(
          sha256.convert(utf8.encode(approvalSource)).toString(),
          descriptor.ownerApprovalSha256,
        );
        final items = WorkoutReleaseCatalogRepository.parseBundleManifest(
          manifestSource,
          expectedBundleId: descriptor.bundleId,
          expectedContentPackId: descriptor.contentPackId,
          expectedRecordCount: descriptor.playableCount,
        );
        WorkoutReleaseCatalogRepository.validateOwnerApproval(
          approvalSource,
          bundleId: descriptor.bundleId,
          items: items,
        );
        all.addAll(items);
      }

      expect(all, hasLength(302));
      expect(all.map((item) => item.releaseKey).toSet(), hasLength(302));
      expect(all.map((item) => item.expectedSha256).toSet(), hasLength(301));
      expect(
        all.where((item) => item.bundleId == 'home-training'),
        hasLength(200),
      );
      expect(
        all.where((item) => item.bundleId == 'gym-six-month'),
        hasLength(102),
      );
      expect(
        all.where((item) => item.durationMilliseconds == 7000),
        hasLength(61),
      );
      expect(
        all.where((item) => item.durationMilliseconds == 10000),
        hasLength(241),
      );
      expect(
        all.every((item) => item.codecName == 'h264' && item.canPlay),
        isTrue,
      );

      final homeIds = all
          .where((item) => item.bundleId == 'home-training')
          .map((item) => item.assetId)
          .toSet();
      final gymIds = all
          .where((item) => item.bundleId == 'gym-six-month')
          .map((item) => item.assetId)
          .toSet();
      expect(homeIds.intersection(gymIds), hasLength(94));
    },
  );

  test('registry and bundle parsers fail closed on tampering', () {
    final registry =
        jsonDecode(read(WorkoutReleaseCatalogRepository.registryAssetPath))
            as Map<String, dynamic>;
    registry['uniquePayloadCount'] = 302;
    expect(
      () => WorkoutReleaseCatalogRepository.parseRegistry(jsonEncode(registry)),
      throwsFormatException,
    );

    final bundle =
        jsonDecode(
              read(
                'artifacts/workout_media/workout_release_bundle_home_v1.json',
              ),
            )
            as Map<String, dynamic>;
    final records = bundle['records'] as List<dynamic>;
    (records.first as Map<String, dynamic>)['codecName'] = 'mpeg4';
    expect(
      () => WorkoutReleaseCatalogRepository.parseBundleManifest(
        jsonEncode(bundle),
        expectedBundleId: 'home-training',
        expectedContentPackId: 'bil-workouts-home-v1',
        expectedRecordCount: 200,
      ),
      throwsFormatException,
    );
  });

  test('two compatibility derivatives preserve source lineage', () {
    final bundle =
        jsonDecode(
              read(
                'artifacts/workout_media/workout_release_bundle_home_v1.json',
              ),
            )
            as Map<String, dynamic>;
    final records = (bundle['records'] as List).cast<Map<String, dynamic>>();
    final derivatives = records.where((record) => record['lineage'] != null);
    expect(derivatives, hasLength(2));
    for (final record in derivatives) {
      final lineage = record['lineage'] as Map<String, dynamic>;
      expect(lineage['operation'], 'non_destructive_h264_delivery_transcode');
      expect(lineage['sourceCodecName'], 'mpeg4');
      expect(lineage['sourcePreserved'], isTrue);
      expect(lineage['sourceSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(record['codecName'], 'h264');
    }
  });
}
