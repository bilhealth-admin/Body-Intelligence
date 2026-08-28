import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generated Cloudflare manifest and both schema-v2 packs parse in Flutter',
    () {
      const root = 'artifacts/workout_media/cloudflare_runtime_v2';
      final summary = _readMap(File('$root/runtime_build_summary_v2.json'));
      final catalogSha = summary['catalogSha256'] as String;
      final catalogFile = File(
        '$root/catalog/wellness-workouts-v2-$catalogSha.json',
      );
      final catalogBytes = catalogFile.readAsBytesSync();
      expect(sha256.convert(catalogBytes).toString(), catalogSha);
      final catalog =
          jsonDecode(utf8.decode(catalogBytes)) as Map<String, dynamic>;
      expect(catalog['schema_version'], 2);

      final counts = <String, int>{};
      for (final rawDescriptor in catalog['packs'] as List) {
        final descriptor = WellnessContentPack.fromJson({
          'schema_version': 2,
          ...(rawDescriptor as Map<String, dynamic>),
        });
        expect(descriptor.minimumAccess, WellnessContentAccess.pro);
        expect(descriptor.downloadUrl.host, 'workouts.bilhealth.com');
        final packFile = File(
          '$root/packs/${descriptor.id}-v${descriptor.version}.json',
        );
        final packBytes = packFile.readAsBytesSync();
        expect(packBytes.length, descriptor.sizeBytes);
        expect(sha256.convert(packBytes).toString(), descriptor.sha256);
        final pack = jsonDecode(utf8.decode(packBytes)) as Map<String, dynamic>;
        final items = pack['items'] as List;
        counts[descriptor.id] = items.length;
        for (final rawItem in items) {
          final item = WellnessContentItem.fromJson(
            rawItem as Map<String, dynamic>,
            expectedType: WellnessContentType.workouts,
            schemaVersion: 2,
          );
          expect(item.imageMedia, isNotNull);
          expect(item.videoMedia, isNotNull);
          expect(item.imageMedia!.url.host, 'workouts.bilhealth.com');
          expect(item.videoMedia!.url.host, 'workouts.bilhealth.com');
          expect(item.imageMedia!.sha256, hasLength(64));
          expect(item.videoMedia!.sha256, hasLength(64));
          expect(item.rights!.mobile, isTrue);
          expect(item.rights!.paid, isTrue);
          expect(item.rights!.offline, isTrue);
        }
      }

      expect(counts, {
        'bil-workouts-home-v1': 200,
        'bil-workouts-gym-six-month-v1': 102,
      });
    },
  );
}

Map<String, dynamic> _readMap(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
