import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/data/community_feed_cache.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
const _c = '33333333-3333-4333-8333-333333333333';

class _Fixture {
  String owner = _a;
  int dataRequests = 0;
  bool feedEnabled = false;
  bool invalidMedia = false;
  CommunityFeedCache? cache;
  Completer<void>? holdRefreshReferences;
  int feedReferenceCalls = 0;
  final dataPaths = <String>[];
  final sessions = <String, String>{};
  List<Map<String, dynamic>> profiles = [
    {'user_id': _b, 'display_name': 'Updated alias', 'avatar_url': null},
    {'user_id': _a, 'display_name': 'Owner alias', 'avatar_url': null},
  ];
  List<Map<String, dynamic>> authors = [
    {
      'user_id': _a,
      'handle': 'owner_alias',
      'relationship': 'self',
      'can_request': false,
    },
    {
      'user_id': _b,
      'handle': 'updated_alias',
      'relationship': 'none',
      'can_request': true,
    },
  ];
  Completer<void>? hold;
  final entered = Completer<void>();
  late final client = SupabaseClient(
    'https://identity-http.invalid',
    'synthetic-only',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(MockClient(_send)),
  );
  late final repository = CommunityRepository(client, feedCache: cache);

  Future<http.Response> _send(http.Request request) async {
    if (request.url.path.startsWith('/rest/v1/')) {
      dataPaths.add(request.url.path);
    }
    Object body;
    if (request.url.path == '/auth/v1/token') {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      body = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'email': 'identity@example.invalid',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-10-19T00:00:00Z',
        },
      };
    } else if (request.url.path == '/rest/v1/bil_public_profiles' ||
        request.url.path == '/rest/v1/rpc/bil_social_post_authors_v2') {
      dataRequests++;
      final value = request.url.path.endsWith('bil_public_profiles')
          ? profiles
          : authors;
      if (!entered.isCompleted) entered.complete();
      await hold?.future;
      body = value;
    } else if (feedEnabled &&
        request.url.path == '/rest/v1/bil_community_posts') {
      body = [
        {
          'id': _c,
          'author_id': _b,
          'body': 'Original post body',
          'created_at': '2026-10-19T00:00:00Z',
          'moderation_status': 'approved',
          'moderation_visibility': 'visible',
          'reviewed_at': '2026-10-19T00:01:00Z',
          'media_object_path': null,
          'media_mime_type': null,
          'media_bytes': null,
          'media_width': null,
          'media_height': null,
          'location_label': null,
        },
      ];
    } else if (feedEnabled &&
        request.url.path == '/rest/v1/rpc/bil_community_feed_refs_v1') {
      feedReferenceCalls++;
      if (feedReferenceCalls > 1) await holdRefreshReferences?.future;
      body = [
        {
          'post_id': _c,
          'created_at': '2026-10-19T00:00:00Z',
          'priority': 0,
          'reasons': [],
        },
      ];
    } else if (feedEnabled &&
        request.url.path == '/rest/v1/rpc/bil_community_post_media_v1') {
      body = [
        for (var i = 0; i < 4; i++)
          {
            'post_id': _c,
            'media_position': invalidMedia ? 0 : i,
            'object_path': '$_b/$_c/40000000-0000-4000-8000-00000000000$i.jpg',
            'mime_type': 'image/jpeg',
            'bytes': 1024,
            'width': 640,
            'height': 480,
          },
      ];
    } else if (feedEnabled &&
        request.url.path.contains('/storage/v1/object/sign/')) {
      return http.Response(
        '{"message":"Synthetic signing outage"}',
        503,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    } else if (feedEnabled &&
        request.url.path == '/rest/v1/rpc/bil_social_stats_v2') {
      body = [
        {'post_id': _c, 'like_count': 8, 'liked': true, 'comment_count': 2},
      ];
    } else if (feedEnabled &&
        request.url.path == '/rest/v1/rpc/bil_social_saved_state_v2') {
      body = [
        {'post_id': _c, 'saved': true},
      ];
    } else if (feedEnabled &&
        request.url.path == '/rest/v1/rpc/bil_community_polls_v1') {
      body = [];
    } else {
      throw StateError('Unexpected synthetic transport: ${request.url.path}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  Future<void> signIn(String id) async {
    owner = id;
    await client.auth.signInWithPassword(
      email: 'identity@example.invalid',
      password: 'synthetic',
    );
    sessions[id] = jsonEncode(client.auth.currentSession!.toJson());
  }
}

void main() {
  late _Fixture fixture;
  setUp(() async {
    fixture = _Fixture();
    await fixture.signIn(_a);
  });
  tearDown(() => fixture.client.dispose());

  for (final returnToA in [false, true]) {
    test(
      'background cached refresh still cancels actual ${returnToA ? 'A-B-A' : 'A-B'} before subsequent HTTP',
      () async {
        await fixture.signIn(_b);
        await fixture.client.auth.recoverSession(fixture.sessions[_a]!);
        final directory = await Directory.systemTemp.createTemp(
          'bil-background-owner-',
        );
        addTearDown(() async {
          expect(
            directory.absolute.path,
            startsWith(
              '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
            ),
          );
          await directory.delete(recursive: true);
        });
        final cache = CommunityFeedCache(directory: directory)..bindOwner(_a);
        fixture.cache = cache;
        fixture.feedEnabled = true;
        fixture.holdRefreshReferences = Completer<void>();
        await cache.save(_a, 'explore|en|40', [
          CommunityPost(
            id: _c,
            authorId: _b,
            body: 'Owner A cached post',
            createdAt: DateTime.utc(2026),
          ),
        ]);
        final outcome = Completer<Object>();
        await fixture.repository.runForCommunityOwner(
          () => fixture.repository.loadCommunityFeedCachedFirst(
            mode: CommunityFeedMode.explore,
            locale: 'en',
            current: () => true,
            onRefreshing: () {},
            onRefresh: outcome.complete,
            onRefreshError: outcome.complete,
          ),
          ownerId: _a,
          isCurrentOwner: () => true,
        );
        await fixture.client.auth.recoverSession(fixture.sessions[_b]!);
        if (returnToA) {
          await fixture.client.auth.recoverSession(fixture.sessions[_a]!);
        }
        fixture.holdRefreshReferences!.complete();
        expect(
          await outcome.future.timeout(const Duration(seconds: 5)),
          isA<CommunityOwnerOperationCancelled>(),
        );
        expect(
          fixture.dataPaths.where(
            (p) => p != '/rest/v1/rpc/bil_community_feed_refs_v1',
          ),
          isEmpty,
        );
        expect(fixture.dataRequests, 0);
      },
    );
  }

  test(
    'cached HTTP background refresh outlives initial read without losing its owner fence',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-identity-refresh-',
      );
      addTearDown(() async {
        expect(
          directory.absolute.path,
          startsWith(
            '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
          ),
        );
        await directory.delete(recursive: true);
      });
      final cache = CommunityFeedCache(directory: directory)..bindOwner(_a);
      fixture.cache = cache;
      fixture.feedEnabled = true;
      fixture.profiles = [fixture.profiles.first];
      fixture.authors = [fixture.authors.last];
      fixture.holdRefreshReferences = Completer<void>();
      await cache.save(_a, 'explore|en|40', [
        CommunityPost(
          id: _c,
          authorId: _b,
          body: 'Original post body',
          createdAt: DateTime.utc(2026),
          authorName: 'Cached old alias',
        ),
      ]);
      final outcome = Completer<Object>();
      final page = await fixture.repository.runForCommunityOwner(
        () => fixture.repository.loadCommunityFeedCachedFirst(
          mode: CommunityFeedMode.explore,
          locale: 'en',
          current: () => true,
          onRefreshing: () {},
          onRefresh: outcome.complete,
          onRefreshError: outcome.complete,
        ),
        ownerId: _a,
        isCurrentOwner: () => true,
      );
      expect(page.posts.single.authorName, 'Cached old alias');
      fixture.holdRefreshReferences!.complete();
      final result = await outcome.future.timeout(const Duration(seconds: 5));
      expect(result, isA<CommunityFeedModeBatch>());
      expect(
        (result as CommunityFeedModeBatch).posts.single.authorName,
        'Updated alias',
      );
    },
  );

  test(
    'HTTP profile and social results join by author ID despite different ordering',
    () async {
      final identities = await fixture.repository.loadPostAuthorIdentities([
        _a,
        _b,
        _a,
      ]);
      expect(identities.map((v) => v.userId), [_a, _b]);
      expect(identities.last.displayName, 'Updated alias');
      expect(identities.last.social!.handle, 'updated_alias');
      expect(
        identities.first.social!.relationship,
        CommunityRelationshipStatus.self,
      );
      expect(fixture.dataRequests, 2);
    },
  );

  test(
    'missing RLS-visible profile and handle clear old cached identity',
    () async {
      fixture.profiles = [];
      fixture.authors = [
        {'user_id': _b, 'handle': null},
      ];
      final identity = (await fixture.repository.loadPostAuthorIdentities([
        _b,
      ])).single;
      final post = CommunityPost(
        id: _c,
        authorId: _b,
        body: 'Original content',
        createdAt: DateTime.utc(2026),
        authorName: 'Stale alias',
        authorHandle: 'stale_alias',
        authorAvatarUrl: 'https://media.invalid/stale.png',
        likeCount: 8,
        saved: true,
      );
      final updated = identity.applyTo(post);
      expect(updated.authorName, isNull);
      expect(updated.authorHandle, isNull);
      expect(updated.authorAvatarUrl, isNull);
      expect(updated.body, post.body);
      expect(updated.likeCount, 8);
      expect(updated.saved, isTrue);
    },
  );

  test('duplicate or unrelated profile rows fail closed', () async {
    fixture.authors = [];
    fixture.profiles = [fixture.profiles.first, fixture.profiles.first];
    await expectLater(
      fixture.repository.loadPostAuthorIdentities([_b]),
      throwsFormatException,
    );
    fixture.profiles = [
      {'user_id': _c, 'display_name': 'Unrequested', 'avatar_url': null},
    ];
    await expectLater(
      fixture.repository.loadPostAuthorIdentities([_b]),
      throwsFormatException,
    );
  });

  test('unrelated social author cannot become another post identity', () async {
    fixture.profiles = [];
    fixture.authors = [
      {
        'user_id': _c,
        'handle': 'unrequested',
        'relationship': 'none',
        'can_request': false,
      },
    ];
    await expectLater(
      fixture.repository.loadPostAuthorIdentities([_b]),
      throwsFormatException,
    );
  });

  test('empty and invalid batches do not issue data requests', () async {
    expect(await fixture.repository.loadPostAuthorIdentities([]), isEmpty);
    await expectLater(
      fixture.repository.loadPostAuthorIdentities(['bad-id']),
      throwsArgumentError,
    );
    await expectLater(
      fixture.repository.loadPostAuthorIdentities(List.filled(101, _a)),
      throwsArgumentError,
    );
    expect(fixture.dataRequests, 0);
  });

  test(
    'complete HTTP feed pipeline keeps latest identity and post when four-image signing fails',
    () async {
      fixture.feedEnabled = true;
      fixture.profiles = [fixture.profiles.first];
      fixture.authors = [fixture.authors.last];
      final page = await fixture.repository.loadCommunityFeedMode(
        mode: CommunityFeedMode.explore,
      );
      final post = page.posts.single;
      expect(post.id, _c);
      expect(post.authorId, _b);
      expect(post.authorName, 'Updated alias');
      expect(post.authorHandle, 'updated_alias');
      expect(post.body, 'Original post body');
      expect(post.mediaItems, hasLength(4));
      expect(post.mediaItems.every((v) => v.url == null), isTrue);
      expect(post.likeCount, 8);
      expect(post.saved, isTrue);
      expect(post.commentCount, 2);
      expect(page.nextBeforeId, _c);
    },
  );

  test(
    'invalid media contract remains a visible load failure rather than false success',
    () async {
      fixture.feedEnabled = true;
      fixture.invalidMedia = true;
      fixture.profiles = [fixture.profiles.first];
      fixture.authors = [fixture.authors.last];
      await expectLater(
        fixture.repository.loadCommunityFeedMode(
          mode: CommunityFeedMode.explore,
        ),
        throwsFormatException,
      );
    },
  );

  for (final roundTrip in [false, true]) {
    test(
      'late HTTP identity result is cancelled after ${roundTrip ? 'A-B-A' : 'A-B'} session change',
      () async {
        await fixture.signIn(_b);
        await fixture.client.auth.recoverSession(fixture.sessions[_a]!);
        fixture.hold = Completer<void>();
        final pending = fixture.repository.loadPostAuthorIdentities([_a, _b]);
        final denied = expectLater(
          pending,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        await fixture.entered.future;
        await fixture.client.auth.recoverSession(fixture.sessions[_b]!);
        if (roundTrip) {
          await fixture.client.auth.recoverSession(fixture.sessions[_a]!);
        }
        fixture.hold!.complete();
        await denied;
      },
    );
  }
}
