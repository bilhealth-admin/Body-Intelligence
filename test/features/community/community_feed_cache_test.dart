import 'dart:io';
import 'package:body_intelligence_log/features/community/data/community_feed_cache.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late DateTime now;
  late CommunityFeedCache cache;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bil-feed-test');
    now = DateTime.utc(2026, 10, 11);
    cache = CommunityFeedCache(directory: root, clock: () => now)
      ..bindOwner('A');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  CommunityPost post(String id) => CommunityPost.fromJson({
    'id': id,
    'author_id': 'author',
    'body': 'TEST PRIVATE body $id',
    'created_at': now.toIso8601String(),
    'media': [
      {
        'object_path': 'author/$id/image.png',
        'media_position': 0,
        'url': 'https://secret.invalid?token=DO-NOT-PERSIST',
        'mime_type': 'image/png',
        'width': 32,
        'height': 32,
        'bytes': 200,
      },
    ],
  });
  test(
    'disk content requires fresh visible IDs; filters, locale, tombstones, and tokens remain safe',
    () async {
      await cache.save('A', 'for_you|ar', [post('p1'), post('p2')]);
      expect(await cache.readAuthorized('A', 'for_you|ar', []), isEmpty);
      expect(
        (await cache.readAuthorized('A', 'for_you|ar', [
          'p2',
        ])).map((p) => p.id),
        ['p2'],
      );
      expect(await cache.readAuthorized('A', 'for_you|en', ['p2']), isEmpty);
      expect(await cache.readAuthorized('B', 'for_you|ar', ['p2']), isEmpty);
      final files = await root
          .list()
          .where((f) => f.path.endsWith('.json'))
          .cast<File>()
          .toList();
      expect(
        await files.single.readAsString(),
        isNot(contains('DO-NOT-PERSIST')),
      );
      cache.invalidatePost('p2');
      expect(await cache.readAuthorized('A', 'for_you|ar', ['p2']), isEmpty);
      now = now.add(const Duration(hours: 2));
      expect(await cache.readAuthorized('A', 'for_you|ar', ['p1']), isEmpty);
    },
  );
  test(
    'restart keeps permitted data but A B A purges the first visit; disk is bounded',
    () async {
      await cache.save('A', 'ar', [post('p')]);
      final restarted = CommunityFeedCache(directory: root, clock: () => now)
        ..bindOwner('A');
      expect((await restarted.readAuthorized('A', 'ar', ['p'])).single.id, 'p');
      restarted.bindOwner('B');
      restarted.bindOwner('A');
      expect(await restarted.readAuthorized('A', 'ar', ['p']), isEmpty);
      for (var i = 0; i < 12; i++) {
        await restarted.save('A', '$i', [post('p')]);
      }
      expect(
        (await root.list().where((f) => f.path.endsWith('.json')).toList())
            .length,
        lessThanOrEqualTo(8),
      );
    },
  );
  test(
    'a private image is never given a fabricated unsigned storage URL',
    () async {
      await cache.save('A', 'for_you|ar', [post('p-with-image')]);
      final rows = await cache.readAuthorized(
        'A',
        'for_you|ar',
        ['p-with-image'],
      );
      expect(rows, hasLength(1));
      expect(rows.single.mediaItems, hasLength(1));
      expect(rows.single.mediaItems.single.objectPath, contains('p-with-image'));
      expect(rows.single.mediaItems.single.url, isNull);
      expect(rows.single.hasImage, isTrue);
      final disk = await (await root
              .list()
              .where((f) => f.path.endsWith('.json'))
              .cast<File>()
              .first)
          .readAsString();
      expect(disk, isNot(contains('/storage/v1/object/sign/')));
      expect(disk, isNot(contains('DO-NOT-PERSIST')));
    },
  );
  test('corrupt feed metadata fails closed', () async {
    await cache.save('A', 'ar', [post('p')]);
    final file = (await root.list().cast<File>().toList()).single;
    await file.writeAsString('{invalid');
    expect(await cache.readAuthorized('A', 'ar', ['p']), isEmpty);
  });
}
