import 'dart:async';
import 'dart:io';
import 'package:body_intelligence_log/features/community/data/community_feed_cache.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_feed_refresh_notice.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _HeldFeed extends CommunityRepository {
  _HeldFeed(super.client, CommunityFeedCache cache) : super(feedCache: cache);
  final response = Completer<CommunityFeedModeBatch>();
  List<String> visible = ['p1'];
  @override
  String get currentUserId => 'A';
  @override
  bool get useServerRankedCommunityFeed => true;
  @override
  Future<List<CommunityFeedReference>> loadCommunityFeedReferences({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async => [
    for (final id in visible)
      CommunityFeedReference(
        postId: id,
        createdAt: DateTime.utc(2026),
        priority: 0,
        reasons: const [],
      ),
  ];
  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedMode({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) => response.future;
}

void main() {
  for (final retired in [false, true]) {
    test(
      'cached authorized content precedes held refresh; failure is visible unless retired $retired',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'bil-cache-refresh-',
        );
        addTearDown(() async {
          expect(
            root.absolute.path,
            startsWith(
              '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
            ),
          );
          await root.delete(recursive: true);
        });
        final cache = CommunityFeedCache(directory: root)..bindOwner('A');
        final post = CommunityPost.fromJson({
          'id': 'p1',
          'author_id': 'author',
          'body': 'TEST authorized fixture',
          'created_at': DateTime.now().toIso8601String(),
        });
        await cache.save('A', 'for_you|ar|40', [post]);
        final client = SupabaseClient('https://isolated.invalid', 'test-only');
        addTearDown(client.dispose);
        final repository = _HeldFeed(client, cache);
        var active = true, started = false;
        final failureSeen = Completer<Object>();
        var success = 0;
        final page = await repository.loadCommunityFeedCachedFirst(
          mode: CommunityFeedMode.forYou,
          locale: 'ar',
          current: () => active,
          onRefreshing: () => started = true,
          onRefresh: (_) => success++,
          onRefreshError: failureSeen.complete,
        );
        expect(page.posts.single.body, 'TEST authorized fixture');
        expect(started, isTrue);
        expect(repository.response.isCompleted, isFalse);
        if (retired) active = false;
        repository.response.completeError(
          StateError('controlled offline refresh'),
        );
        if (retired) {
          await Future<void>.delayed(Duration.zero);
          expect(failureSeen.isCompleted, isFalse);
        } else {
          expect(await failureSeen.future, isA<StateError>());
        }
        expect(success, 0);
        expect(
          (await cache.readAuthorized('A', 'for_you|ar|40', ['p1'])).single.id,
          'p1',
        );
        expect(await cache.readAuthorized('A', 'for_you|ar|40', []), isEmpty);
      },
    );
  }
  test('refresh failure copy covers every released locale', () {
    expect(
      CommunityFeedRefreshNotice.messages.keys.toSet(),
      BilLocalePolicy.productionTags.toSet(),
    );
    expect(
      CommunityFeedRefreshNotice.messages.values.every(
        (text) => text.trim().isNotEmpty,
      ),
      isTrue,
    );
  });
}
