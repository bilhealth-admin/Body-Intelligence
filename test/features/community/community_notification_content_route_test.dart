import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_post_cloud_store.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/data/community_notification_content_loader.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notification_destination.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
const _author = '33333333-3333-4333-8333-333333333333';
const _post = '44444444-4444-4444-8444-444444444444';
const _activity = '55555555-5555-4555-8555-555555555555';
String _id(int value) =>
    'aaaaaaaa-aaaa-4aaa-8aaa-${value.toRadixString(16).padLeft(12, '0')}';

/// Real SDK request/response fixture, not a deployed server or RLS proof.
class _Transport {
  String signingOwner = _a;
  final sessions = <String, String>{};
  final calls = <({String owner, String rpc, Map<String, dynamic> params})>[];
  bool missingThreads = false;
  bool denied = false;
  bool revokeDuringStats = false;
  bool removedRoot = false;
  bool failComments = false;
  bool nonProgressing = false;
  Completer<void>? pendingScan;
  final rows = <Map<String, dynamic>>[];
  late final store = _Store(this);
  late final client = SupabaseClient(
    'https://content-notification-fixture.invalid',
    'synthetic-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(MockClient(_respond)),
  );
  late final repository = _Repository(client, store, this);

  _Transport() {
    for (var index = 1; index <= 105; index++) {
      rows.add(
        _row(
          index,
          body: index == 105
              ? 'Thread root from notification'
              : 'Earlier root $index',
        ),
      );
    }
    for (var index = 106; index <= 110; index++) {
      rows.add(
        _row(
          index,
          parentId: _id(105),
          body: index == 110
              ? 'Target reply beyond preview'
              : 'Earlier reply $index',
        ),
      );
    }
  }
  Map<String, dynamic> _row(
    int index, {
    required String body,
    String? parentId,
  }) => {
    'id': _id(index),
    'author_id': _author,
    'parent_id': parentId,
    'body': body,
    'created_at': DateTime.utc(
      2026,
      10,
      13,
    ).add(Duration(seconds: index)).toIso8601String(),
    'author_name': 'Other Member',
    'like_count': index == 110 ? 7 : 2,
    'liked': false,
  };
  bool _after(Map<String, dynamic> row, Map<String, dynamic> params) {
    final time = params['p_after'];
    if (time == null) return true;
    final compared = DateTime.parse(
      row['created_at'] as String,
    ).compareTo(DateTime.parse(time as String));
    return compared > 0 ||
        (compared == 0 &&
            (row['id'] as String).compareTo(params['p_after_id'] as String) >
                0);
  }

  Future<http.Response> _respond(http.Request request) async {
    Object body;
    if (request.url.path == '/auth/v1/token') {
      final payload = base64Url
          .encode(
            utf8.encode(jsonEncode({'sub': signingOwner, 'exp': 4102444800})),
          )
          .replaceAll('=', '');
      body = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.synthetic',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': signingOwner,
          'email': 'qa@example.invalid',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-10-13T00:00:00Z',
        },
      };
    } else if (request.url.path == '/auth/v1/logout') {
      body = {};
    } else if (request.url.path.startsWith('/rest/v1/rpc/')) {
      final rpc = request.url.pathSegments.last;
      final params = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      final authorization = request.headers['authorization'] ?? '';
      final token = authorization.split(' ').last.split('.');
      final owner =
          (jsonDecode(
                    utf8.decode(
                      base64Url.decode(base64Url.normalize(token[1])),
                    ),
                  )
                  as Map)['sub']
              as String;
      calls.add((owner: owner, rpc: rpc, params: params));
      if (rpc == 'bil_social_stats_v2') {
        body = denied
            ? []
            : [
                {
                  'post_id': _post,
                  'like_count': 9,
                  'liked': false,
                  'comment_count': rows.length,
                },
              ];
        if (revokeDuringStats) {
          store.visible = false;
          revokeDuringStats = false;
        }
      } else if (rpc == 'bil_social_comments_v2') {
        final pending = pendingScan;
        if (pending != null) {
          pendingScan = null;
          await pending.future;
        }
        if (failComments) return _error(request, '42501');
        final visible = denied ? <Map<String, dynamic>>[] : rows;
        body = visible
            .where((row) => nonProgressing || _after(row, params))
            .take(params['p_limit'] as int)
            .toList();
      } else if (rpc == 'bil_social_comment_threads_v3') {
        if (missingThreads) return _error(request, 'PGRST202');
        final roots = denied
            ? <Map<String, dynamic>>[]
            : rows
                  .where(
                    (row) =>
                        row['parent_id'] == null &&
                        !(removedRoot && row['id'] == _id(105)) &&
                        _after(row, params),
                  )
                  .take(params['p_limit'] as int);
        body = [for (final root in roots) _thread(root)];
      } else if (rpc == 'bil_social_comment_replies_v3') {
        if (missingThreads) return _error(request, 'PGRST202');
        body = denied || removedRoot
            ? []
            : rows
                  .where(
                    (row) =>
                        row['parent_id'] == params['p_root_id'] &&
                        _after(row, params),
                  )
                  .take(params['p_limit'] as int)
                  .toList();
      } else {
        throw StateError('Unexpected RPC: $rpc');
      }
    } else {
      throw StateError('Unexpected external request: ${request.url.path}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  Map<String, dynamic> _thread(Map<String, dynamic> root) {
    final replies = rows
        .where((row) => row['parent_id'] == root['id'])
        .toList();
    return {
      'root_id': root['id'],
      'root_created_at': root['created_at'],
      'reply_count': replies.length,
      'root': {...root, 'reply_count': replies.length},
      'replies': replies.take(3).toList(),
    };
  }

  http.Response _error(http.Request request, String code) => http.Response(
    jsonEncode({
      'code': code,
      'message': 'synthetic reader failure',
      'details': null,
      'hint': null,
    }),
    code == 'PGRST202' ? 404 : 403,
    headers: {'content-type': 'application/json'},
    request: request,
  );
  Future<void> initialize() async {
    for (final owner in [_b, _a]) {
      signingOwner = owner;
      await client.auth.signInWithPassword(
        email: 'qa@example.invalid',
        password: 'synthetic-password',
      );
      sessions[owner] = jsonEncode(client.auth.currentSession!.toJson());
    }
  }

  Future<void> aba() async {
    final second = client.auth.recoverSession(sessions[_b]!);
    final first = client.auth.recoverSession(sessions[_a]!);
    await Future.wait([second, first]);
  }
}

class _Store
    implements CommunityPostStoreContract, CommunityPostLookupContract {
  _Store(this.transport);
  final _Transport transport;
  bool visible = true;
  CommunityPostModerationStatus status = CommunityPostModerationStatus.approved;
  CommunityPostModerationVisibility visibility =
      CommunityPostModerationVisibility.visible;
  int reads = 0;
  int feedReads = 0;
  @override
  Future<List<CommunityPost>> loadPostsByIds(List<String> ids) async {
    reads++;
    if (!visible) return [];
    return [
      CommunityPost(
        id: _post,
        authorId: _author,
        body: 'Notification post body',
        createdAt: DateTime.utc(2026, 10, 13),
        moderationStatus: status,
        moderationVisibility: visibility,
      ),
    ];
  }

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async {
    feedReads++;
    throw StateError('Notification cannot open generic feed');
  }

  @override
  Future<List<CommunityPost>> loadModerationQueue({int limit = 100}) async =>
      throw UnimplementedError();
  @override
  Future<void> delete(String postId) async => throw UnimplementedError();
  @override
  Future<void> publishText(String body) async => throw UnimplementedError();
  @override
  Future<void> publishWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async => throw UnimplementedError();
}

class _Repository extends CommunityRepository {
  _Repository(super.client, _Store store, this.transport)
    : super(postStore: store);
  final _Transport transport;
  final marks = <List<String>>[];
  @override
  bool get useServerCommunityReferenceParity => false;
  @override
  Future<CommunityAttention> loadAttention() async =>
      const CommunityAttention(communityUpdates: 1);
  @override
  Future<List<CommunityNotification>> loadCommunityNotifications({
    DateTime? before,
    String? beforeId,
    List<CommunityNotificationKind>? kinds,
    int limit = 30,
  }) async => [_notification(CommunityNotificationKind.reply, _id(110))];
  @override
  Future<int> markCommunityNotificationsSeen(List<String> ids) async {
    marks.add(List.of(ids));
    return 1;
  }
}

CommunityNotification _notification(
  CommunityNotificationKind kind,
  String? commentId,
) => CommunityNotification(
  id: _activity,
  kind: kind,
  actorId: _author,
  actorDisplayName: 'Other Member',
  createdAt: DateTime.utc(2026, 10, 13),
  entityKind: commentId == null ? 'post' : 'comment',
  entityId: commentId ?? _post,
  copyKey: 'synthetic_activity_v1',
  deepLinkPath: '/community',
  metadata: {'post_id': _post, 'comment_id': ?commentId},
);

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  // SDK responses above 10 KB use its real JSON worker isolate. Yield the real
  // runner while pumping frames; advancing only a fake clock cannot deliver it.
  var readyFrames = 0;
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    readyFrames = ready() ? readyFrames + 1 : 0;
    if (readyFrames >= 2) return;
  }
  throw StateError(
    'Fixture UI did not complete within the bounded read window',
  );
}

Future<void> _settle(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    () =>
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(LinearProgressIndicator).evaluate().isEmpty,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Transport transport;
  setUp(() async {
    transport = _Transport();
    await transport.initialize();
  });
  tearDown(() async {
    await transport.client.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    String? commentId,
    bool notifications = false,
    String? location,
  }) async {
    final router = GoRouter(
      initialLocation:
          location ??
          (notifications
              ? '/community/notifications'
              : CommunityDeepLink.contentRoute(
                  postId: _post,
                  commentId: commentId,
                )!),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Dashboard')),
        ),
        GoRoute(
          path: '/community/notifications',
          builder: (_, _) =>
              CommunityNotificationsPage(repository: transport.repository),
        ),
        GoRoute(
          path: '/community/content/:postId',
          builder: (_, state) => CommunityNotificationContentPage(
            postId: state.pathParameters['postId']!,
            commentId: state.uri.queryParameters['comment'],
            validQuery:
                state.uri.fragment.isEmpty &&
                state.uri.queryParametersAll.keys.every(
                  (key) => key == 'comment',
                ) &&
                (state.uri.queryParametersAll['comment']?.length ?? 1) == 1,
            repository: transport.repository,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  test(
    'content link allows only UUID destinations and one safe comment query',
    () {
      final expected = '/community/content/$_post?comment=${_id(110)}';
      expect(
        CommunityDeepLink.routeFor(
          Uri.parse('bil://community/content/$_post?comment=${_id(110)}'),
        ),
        expected,
      );
      expect(
        CommunityNotificationDestination.contentRoute(
          _notification(CommunityNotificationKind.reply, _id(110)),
        ),
        expected,
      );
      expect(
        CommunityNotificationDestination.contentRoute(
          _notification(CommunityNotificationKind.postLike, null),
        ),
        '/community/content/$_post',
      );
      for (final suffix in [
        '?comment=',
        '?comment=bad',
        '?comment=${_id(110)}&comment=${_id(105)}',
        '?comment=${_id(110)}&owner=$_a',
        '#secret',
      ]) {
        expect(
          CommunityDeepLink.routeFor(
            Uri.parse('bil://community/content/$_post$suffix'),
          ),
          isNull,
        );
      }
      expect(
        CommunityDeepLink.routeFor(Uri.parse('bil://community/post/$_post')),
        isNull,
        reason:
            'A public comment link must not expose the private receipt route',
      );
    },
  );

  test(
    'actual SDK focus reader finds the root and requested reply after page one',
    () async {
      final focus = await CommunityNotificationContentLoader(
        transport.repository,
      ).loadFocus(_post, _id(110));
      expect(focus, isNotNull);
      expect(focus!.commentId, _id(110));
      expect(focus.thread.root.id, _id(105));
      expect(focus.thread.replies.map((row) => row.id), contains(_id(110)));
      expect(focus.thread.replyCount, 5);
    },
  );
  testWidgets(
    'actual notification tap opens and focuses its real reply beyond the first page',
    (tester) async {
      await mount(tester, notifications: true);
      await _settle(tester);
      await tester.tap(find.textContaining('Other Member'));
      await _settle(tester);
      final target = find.byKey(ValueKey('community-comment-body-${_id(110)}'));
      expect(
        target,
        findsOneWidget,
        reason:
            'Rendered text: ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(' | ')}\nRPCs: ${transport.calls.map((c) => '${c.rpc}:${c.params}').join(' | ')}',
      );
      expect(target.hitTestable(), findsOneWidget);
      final viewport = tester.getRect(
        find.byKey(const Key('community-post-detail-list')),
      );
      expect(viewport.overlaps(tester.getRect(target)), isTrue);
      expect(transport.store.feedReads, 0);
      expect(transport.repository.marks, isNotEmpty);
      final pages = transport.calls
          .where((call) => call.rpc == 'bil_social_comments_v2')
          .toList();
      expect(pages, hasLength(2));
      expect(pages.last.params['p_after_id'], _id(100));
      expect(
        transport.calls.any(
          (call) => call.rpc == 'bil_social_comment_replies_v3',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('community-safe-return')));
      await _settle(tester);
      expect(
        find.byKey(const Key('community-activity-filter-updates')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a root outside initial threads is readable and focused without duplicate row',
    (tester) async {
      await mount(tester, commentId: _id(105));
      await _settle(tester);
      final target = find.byKey(ValueKey('community-comment-body-${_id(105)}'));
      expect(target, findsOneWidget);
      expect(target.hitTestable(), findsOneWidget);
      expect(
        transport.calls.where((call) => call.rpc == 'bil_social_comments_v2'),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing v3 falls back to real v2 rows and preserves unknown total counts',
    (tester) async {
      transport.missingThreads = true;
      await mount(tester, commentId: _id(110));
      await _settle(tester);
      final target = find.byKey(ValueKey('community-comment-body-${_id(110)}'));
      expect(target.hitTestable(), findsOneWidget);
      expect(find.text('View 1 replies'), findsNothing);
      expect(
        transport.calls.every((call) => call.rpc.startsWith('bil_social_')),
        isTrue,
      );
      final more = find.byKey(const Key('community-comments-load-more'));
      await tester.scrollUntilVisible(
        more,
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('community-post-detail-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(more);
      await _settle(tester);
      expect(
        transport.calls.any(
          (call) =>
              call.rpc == 'bil_social_comments_v2' &&
              call.params['p_after_id'] == _id(30),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removed comment parent is unavailable and is never reconstructed from older scan',
    (tester) async {
      transport.removedRoot = true;
      await mount(tester, commentId: _id(110));
      await _settle(tester);
      expect(
        find.byKey(ValueKey('community-comment-body-${_id(110)}')),
        findsNothing,
      );
      expect(find.text('This comment is no longer available.'), findsOneWidget);
      expect(find.text('Notification post body'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [
    CommunityPostModerationStatus.pending,
    CommunityPostModerationStatus.rejected,
  ]) {
    testWidgets(
      'public content refuses $status even when owner lookup can read it',
      (tester) async {
        transport.store.status = status;
        await mount(tester, commentId: _id(110));
        await _settle(tester);
        expect(find.text('Notification post body'), findsNothing);
        expect(
          find.text('This post is no longer available to this account.'),
          findsOneWidget,
        );
        expect(transport.calls, isEmpty);
      },
    );
  }
  testWidgets(
    'a moderator-hidden post cannot leak through a public content notification',
    (tester) async {
      transport.store.visibility =
          CommunityPostModerationVisibility.hiddenByModerator;
      await mount(tester);
      await _settle(tester);
      expect(find.text('Notification post body'), findsNothing);
      expect(transport.calls, isEmpty);
    },
  );
  testWidgets(
    'access removed between lookup and statistics never paints former content',
    (tester) async {
      transport.revokeDuringStats = true;
      await mount(tester);
      await _settle(tester);
      expect(find.text('Notification post body'), findsNothing);
      expect(
        find.text('This post is no longer available to this account.'),
        findsOneWidget,
      );
      expect(transport.store.reads, greaterThanOrEqualTo(2));
    },
  );
  testWidgets(
    'social block denies content even if base post lookup remains visible',
    (tester) async {
      transport.denied = true;
      await mount(tester);
      await _settle(tester);
      expect(find.text('Notification post body'), findsNothing);
      expect(
        find.text('This post is no longer available to this account.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'long-running focus scan leaves post usable and cancel retires its late result',
    (tester) async {
      final pending = Completer<void>();
      transport.pendingScan = pending;
      await mount(tester, commentId: _id(110));
      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('community-notification-focus-cancel'))
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Notification post body'), findsOneWidget);
      final cancel = find.byKey(
        const Key('community-notification-focus-cancel'),
      );
      expect(cancel.hitTestable(), findsOneWidget);
      await tester.tap(cancel);
      await tester.pump();
      pending.complete();
      await _settle(tester);
      expect(
        find.byKey(ValueKey('community-comment-body-${_id(110)}')),
        findsNothing,
      );
      final retry = find.byKey(const Key('community-notification-focus-retry'));
      await tester.tap(retry);
      await _settle(tester);
      expect(
        find
            .byKey(ValueKey('community-comment-body-${_id(110)}'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'delivered A B A prevents the former scan repainting the fresh visit',
    (tester) async {
      final pending = Completer<void>();
      transport.pendingScan = pending;
      await mount(tester, commentId: _id(110));
      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('community-notification-focus-cancel'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.runAsync(transport.aba);
      await _settle(tester);
      final before = transport.calls.length;
      pending.complete();
      await _settle(tester);
      expect(
        transport.calls.length,
        before,
        reason: 'The retired scan cannot send another page',
      );
      expect(
        find.byKey(ValueKey('community-comment-body-${_id(110)}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'read failure keeps the post usable and explicit retry opens the same comment',
    (tester) async {
      transport.failComments = true;
      await mount(tester, commentId: _id(110));
      await _settle(tester);
      expect(find.text('Notification post body'), findsOneWidget);
      expect(
        find.text('Could not open this comment. Try again.'),
        findsOneWidget,
      );
      transport.failComments = false;
      await tester.tap(
        find.byKey(const Key('community-notification-focus-retry')),
      );
      await _settle(tester);
      expect(
        find
            .byKey(ValueKey('community-comment-body-${_id(110)}'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'resuming rechecks social access and clears former visible content',
    (tester) async {
      await mount(tester);
      await _settle(tester);
      expect(find.text('Notification post body'), findsOneWidget);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      transport.denied = true;
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await _settle(tester);
      expect(find.text('Notification post body'), findsNothing);
      expect(
        find.text('This post is no longer available to this account.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('unknown or repeated query cannot send any content request', (
    tester,
  ) async {
    await mount(
      tester,
      location: '/community/content/$_post?comment=${_id(110)}&owner=$_b',
    );
    await _settle(tester);
    expect(transport.store.reads, 0);
    expect(transport.calls, isEmpty);
    expect(find.text('Notification post body'), findsNothing);
    await mount(
      tester,
      location:
          '/community/content/$_post?comment=${_id(110)}&comment=${_id(105)}',
    );
    await _settle(tester);
    expect(transport.store.reads, 0);
    expect(transport.calls, isEmpty);
  });
  testWidgets(
    'UUID predecessor boundary and tied timestamps remain reachable across pages',
    (tester) async {
      const targetId = 'aaaaaaaa-aaaa-4aaa-8000-000000000000';
      final tied = DateTime.utc(2026, 10, 13, 1);
      for (var index = 0; index < 105; index++) {
        transport.rows[index]['created_at'] = tied.toIso8601String();
        transport.rows[index]['id'] = index == 104
            ? targetId
            : '99999999-9999-4999-8999-${(index + 1).toRadixString(16).padLeft(12, '0')}';
      }
      for (var index = 105; index < transport.rows.length; index++) {
        transport.rows[index]['created_at'] = tied
            .add(Duration(seconds: index))
            .toIso8601String();
        transport.rows[index]['parent_id'] = targetId;
      }
      await mount(tester, commentId: targetId);
      await _settle(tester);
      expect(
        find
            .byKey(
              const ValueKey(
                'community-comment-body-aaaaaaaa-aaaa-4aaa-8000-000000000000',
              ),
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        transport.calls.where(
          (call) => call.rpc == 'bil_social_comment_threads_v3',
        ),
        hasLength(4),
        reason:
            'Initial page plus three actual pages across the tied timestamp',
      );
      for (final call in transport.calls) {
        final cursor = call.params['p_after_id'];
        if (cursor != null) {
          expect(CommunityDeepLink.isContentId(cursor as String), isTrue);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'non-progressing scan cursor fails explicitly instead of looping forever',
    () async {
      transport.nonProgressing = true;
      await expectLater(
        CommunityNotificationContentLoader(
          transport.repository,
        ).loadFocus(_post, _id(110)),
        throwsA(isA<FormatException>()),
      );
      expect(
        transport.calls.where((call) => call.rpc == 'bil_social_comments_v2'),
        hasLength(2),
      );
    },
  );
}
