import 'package:body_intelligence_log/features/community/data/community_post_cloud_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'first and older public pages select only published rows; own history retains moderation states',
    () async {
      const me = '11111111-1111-4111-8111-111111111111';
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://community-query.invalid',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final store = CommunityPostCloudStore(
        client,
        User(
          id: me,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-09-09T00:00:00Z',
        ),
      );
      await store.loadFeedPage();
      await store.loadFeedPage(before: DateTime.utc(2026, 9, 9), beforeId: me);
      await store.loadMyPostsPage();
      expect(requests, hasLength(3));
      for (final request in requests.take(2)) {
        expect(request.path, '/rest/v1/bil_community_posts');
        expect(request.queryParameters['moderation_status'], 'eq.approved');
        expect(request.queryParameters['deleted_at'], 'is.null');
        expect(
          request.queryParameters['order'],
          'created_at.desc.nullslast,id.desc.nullslast',
        );
        expect(request.queryParameters.containsKey('author_id'), isFalse);
      }
      expect(requests[1].queryParameters['or'], contains('id.lt.$me'));
      expect(requests.last.queryParameters['author_id'], 'eq.$me');
      expect(requests.last.queryParameters['deleted_at'], 'is.null');
      expect(
        requests.last.queryParameters.containsKey('moderation_status'),
        isFalse,
      );
    },
  );
}
