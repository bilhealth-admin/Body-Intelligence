import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory packsDirectory;
  late Directory cacheDirectory;
  late HttpClient managerClient;
  late WellnessMediaCache mediaCache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bil-pack-remove-test-');
    packsDirectory = Directory(p.join(root.path, 'packs'))
      ..createSync(recursive: true);
    cacheDirectory = Directory(p.join(root.path, 'media'))
      ..createSync(recursive: true);
    managerClient = HttpClient();
    mediaCache = WellnessMediaCache(directory: cacheDirectory);
  });

  tearDown(() async {
    managerClient.close(force: true);
    mediaCache.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('pack removal clears every trusted main and segment media', () async {
    final fixture = await _writeInstalledWorkoutPack(
      packsDirectory,
      cacheDirectory,
    );
    final unrelated = File(p.join(cacheDirectory.path, 'unrelated'));
    await unrelated.writeAsString('keep');
    final manager = WellnessContentPackManager(
      client: managerClient,
      mediaCache: mediaCache,
      packsDirectory: packsDirectory,
    );

    await manager.remove(fixture.packId);

    expect(await fixture.packFile.exists(), isFalse);
    expect(await fixture.mainImage.exists(), isFalse);
    expect(await fixture.mainVideo.exists(), isFalse);
    expect(await fixture.segmentImage.exists(), isFalse);
    expect(await fixture.segmentVideo.exists(), isFalse);
    expect(await unrelated.readAsString(), 'keep');
    expect(await manager.installedPacks(), isEmpty);
  });

  test(
    'tampered pack fails closed without orphaning registered cache',
    () async {
      final fixture = await _writeInstalledWorkoutPack(
        packsDirectory,
        cacheDirectory,
        tampered: true,
      );
      final manager = WellnessContentPackManager(
        client: managerClient,
        mediaCache: mediaCache,
        packsDirectory: packsDirectory,
      );

      await expectLater(manager.remove(fixture.packId), throwsFormatException);

      expect(await fixture.packFile.exists(), isTrue);
      expect(await fixture.mainImage.exists(), isTrue);
      expect(await fixture.mainVideo.exists(), isTrue);
      expect(await fixture.segmentImage.exists(), isTrue);
      expect(await fixture.segmentVideo.exists(), isTrue);
      expect(await manager.installedPacks(), hasLength(1));
    },
  );

  test('registered path outside pack directory is never deleted', () async {
    final outside = File(p.join(root.path, 'outside.json'));
    await outside.writeAsString('{"private":true}', flush: true);
    final installed = InstalledWellnessContentPack(
      id: 'unsafe-pack',
      version: 1,
      path: outside.path,
      installedAt: DateTime.utc(2026),
    );
    await File(p.join(packsDirectory.path, 'installed.json')).writeAsString(
      jsonEncode(<Map<String, dynamic>>[installed.toJson()]),
      flush: true,
    );
    final manager = WellnessContentPackManager(
      client: managerClient,
      mediaCache: mediaCache,
      packsDirectory: packsDirectory,
    );

    await expectLater(manager.remove(installed.id), throwsFormatException);

    expect(await outside.readAsString(), '{"private":true}');
    expect(await manager.installedPacks(), hasLength(1));
  });

  test('trusted installed items inherit persisted pack access', () async {
    final fixture = await _writeInstalledWorkoutPack(
      packsDirectory,
      cacheDirectory,
      minimumAccess: WellnessContentAccess.pro,
    );
    final manager = WellnessContentPackManager(
      client: managerClient,
      mediaCache: mediaCache,
      packsDirectory: packsDirectory,
    );

    final installed = await manager.installedPacks();
    final items = await manager.loadTrustedInstalledItems(
      WellnessContentType.workouts,
      locale: 'en',
    );

    expect(installed.single.minimumAccess, WellnessContentAccess.pro);
    expect(items.single.minimumAccess, WellnessContentAccess.pro);
    expect(await fixture.packFile.exists(), isTrue);
  });
}

Future<_InstalledFixture> _writeInstalledWorkoutPack(
  Directory packsDirectory,
  Directory cacheDirectory, {
  bool tampered = false,
  WellnessContentAccess minimumAccess = WellnessContentAccess.free,
}) async {
  const packId = 'strength-pack-v2';
  final mainImageBytes = utf8.encode('main licensed image');
  final mainBytes = utf8.encode('main licensed video');
  final segmentImageBytes = utf8.encode('segment licensed image');
  final segmentBytes = utf8.encode('segment licensed video');
  final mainImageDigest = sha256.convert(mainImageBytes).toString();
  final mainDigest = sha256.convert(mainBytes).toString();
  final segmentImageDigest = sha256.convert(segmentImageBytes).toString();
  final segmentDigest = sha256.convert(segmentBytes).toString();
  final mainImage = File(p.join(cacheDirectory.path, '$mainImageDigest.webp'));
  final mainVideo = File(p.join(cacheDirectory.path, '$mainDigest.mp4'));
  final segmentImage = File(
    p.join(cacheDirectory.path, '$segmentImageDigest.webp'),
  );
  final segmentVideo = File(p.join(cacheDirectory.path, '$segmentDigest.mp4'));
  await mainImage.writeAsBytes(mainImageBytes, flush: true);
  await mainVideo.writeAsBytes(mainBytes, flush: true);
  await segmentImage.writeAsBytes(segmentImageBytes, flush: true);
  await segmentVideo.writeAsBytes(segmentBytes, flush: true);

  final item = <String, dynamic>{
    'id': 'strength-routine-001',
    'type': 'workouts',
    'locale': 'en',
    'title': 'Strength routine',
    'description': 'Safety-reviewed strength routine.',
    'publisher': 'Licensed publisher',
    'source_url': 'https://example.test/workouts/strength-routine-001',
    'license_name': 'Commercial mobile license',
    'license_url': 'https://example.test/license',
    'verified': true,
    'duration_minutes': 10,
    'category': 'strength',
    'category_description': 'Foundational strength routines.',
    'category_order': 0,
    'equipment': <String>['none'],
    'author': 'Qualified exercise professional',
    'attribution': 'Licensed to BIL.',
    'reviewed_at': '2026-01-01T00:00:00Z',
    'safety_reviewed': true,
    'rights': <String, dynamic>{'mobile': true, 'paid': true, 'offline': true},
    'media': <String, dynamic>{
      'image': _media(
        'https://cdn.example.test/main.webp',
        'image/webp',
        mainImageDigest,
        mainImageBytes.length,
      ),
      'video': _media(
        'https://cdn.example.test/main.mp4',
        'video/mp4',
        mainDigest,
        mainBytes.length,
      ),
    },
    'segments': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'squat',
        'title': 'Squat',
        'instruction': 'Lower under control.',
        'reps': 8,
        'rest_seconds': 20,
        'media': <String, dynamic>{
          'image': _media(
            'https://cdn.example.test/squat.webp',
            'image/webp',
            segmentImageDigest,
            segmentImageBytes.length,
          ),
          'video': _media(
            'https://cdn.example.test/squat.mp4',
            'video/mp4',
            segmentDigest,
            segmentBytes.length,
          ),
        },
      },
    ],
  };
  if (tampered) item.remove('rights');
  final packFile = File(p.join(packsDirectory.path, '$packId-1.json'));
  await packFile.writeAsString(
    jsonEncode(<String, dynamic>{
      'schema_version': 2,
      'pack_id': packId,
      'version': 1,
      'type': 'workouts',
      'categories': <String>['strength'],
      'items': <Map<String, dynamic>>[item],
    }),
    flush: true,
  );
  final installed = InstalledWellnessContentPack(
    id: packId,
    version: 1,
    path: packFile.path,
    installedAt: DateTime.utc(2026),
    minimumAccess: minimumAccess,
  );
  await File(p.join(packsDirectory.path, 'installed.json')).writeAsString(
    jsonEncode(<Map<String, dynamic>>[installed.toJson()]),
    flush: true,
  );
  return _InstalledFixture(
    packId: packId,
    packFile: packFile,
    mainImage: mainImage,
    mainVideo: mainVideo,
    segmentImage: segmentImage,
    segmentVideo: segmentVideo,
  );
}

Map<String, dynamic> _media(
  String url,
  String mimeType,
  String digest,
  int sizeBytes,
) => <String, dynamic>{
  'url': url,
  'mime_type': mimeType,
  'sha256': digest,
  'size_bytes': sizeBytes,
};

class _InstalledFixture {
  const _InstalledFixture({
    required this.packId,
    required this.packFile,
    required this.mainImage,
    required this.mainVideo,
    required this.segmentImage,
    required this.segmentVideo,
  });

  final String packId;
  final File packFile, mainImage, mainVideo, segmentImage, segmentVideo;
}
