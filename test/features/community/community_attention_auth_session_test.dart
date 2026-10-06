import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_attention_scope.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';

String _session(String owner) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return jsonEncode({
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-06T00:00:00Z',
    },
  });
}

http.Response _snapshot(int count, {int requests = 0, int activity = 0}) =>
    http.Response(
      jsonEncode({
        'unread_messages': count,
        'incoming_requests': requests,
        'community_updates': activity,
        'unread_by_sender': count == 0 ? {} : {_ownerB: count},
        'activity_unseen_by_kind': <String, int>{},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

class _Fixture {
  final reads = <String>[];
  Future<http.Response> Function(int index)? response;
  late final client = SupabaseClient(
    'https://attention-auth.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    realtimeClientOptions: RealtimeClientOptions(
      // No network socket: real channels still retain their actual callbacks.
      transport: (_, _) => throw StateError('Synthetic offline realtime'),
    ),
    httpClient: CommunityOwnerHttpClient(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/logout') {
          return http.Response('{}', 200);
        }
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            _session(_ownerA),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        expectSync(request.url.path, '/rest/v1/rpc/bil_community_attention_v2');
        final token = request.headers['authorization']!.split(' ').last;
        final claims =
            jsonDecode(
                  utf8.decode(
                    base64Url.decode(base64Url.normalize(token.split('.')[1])),
                  ),
                )
                as Map<String, dynamic>;
        reads.add(claims['sub'] as String);
        final result =
            await (response?.call(reads.length - 1) ??
                Future.value(_snapshot(7)));
        return http.Response(
          result.body,
          result.statusCode,
          headers: result.headers,
          request: request,
        );
      }),
    ),
  );

  Future<void> roundTrip() async {
    final second = client.auth.recoverSession(_session(_ownerB));
    final first = client.auth.recoverSession(_session(_ownerA));
    await Future.wait([second, first]);
  }
}

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.pump();
  }
  await tester.pump();
}

void _change(RealtimeChannel channel) {
  channel.trigger('postgres_changes', {
    'event': 'INSERT',
    'eventType': 'INSERT',
    'schema': 'public',
    'table': 'bil_messages',
    'new': {'recipient_id': _ownerA},
    'old': <String, dynamic>{},
    'commit_timestamp': '2026-10-06T12:00:00Z',
  });
}

void main() {
  late _Fixture fixture;
  late _Fixture replacement;
  late CommunityAttentionController controller;
  final nativeBadges = <int>[];

  // Client construction, JSON isolate disposal and root-zone subscriptions
  // live outside widget fake time, as in the existing real-auth regressions.
  setUp(() async {
    fixture = _Fixture();
    replacement = _Fixture();
    await fixture.client.auth.recoverSession(_session(_ownerA));
    await replacement.client.auth.recoverSession(_session(_ownerA));
    nativeBadges.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('bil/push'), (
          call,
        ) async {
          if (call.method == 'setBadgeCount') {
            nativeBadges.add(call.arguments as int);
          }
          return null;
        });
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('bil/push'), null);
    await fixture.client.dispose();
    await replacement.client.dispose();
  });

  test(
    'actual attention RPC fixture preserves its authoritative JSON counts',
    () async {
      final value = await fixture.client.rpc('bil_community_attention_v2');
      expect(value, isA<Map>());
      final parsed = CommunityAttention.fromJson(
        Map<String, dynamic>.from(value as Map),
      );
      expect(parsed.unreadMessages, 7);
    },
  );

  Future<void> mount(WidgetTester tester, {SupabaseClient? client}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityAttentionScope(
          client: client ?? fixture.client,
          child: Builder(
            builder: (context) {
              controller = CommunityAttentionScope.controllerOf(context)!;
              return const Scaffold(body: CommunityUnreadBadge());
            },
          ),
        ),
      ),
    );
    await _pump(tester);
  }

  void authTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  authTest('queued A B A retires pending attention before its old readback', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    fixture.response = (index) async =>
        index == 0 ? pending.future : _snapshot(2);
    await mount(tester);
    expect(fixture.reads, [_ownerA]);
    final observed = <int>[];
    controller.addListener(() => observed.add(controller.value.total));
    await fixture.roundTrip();
    await _pump(tester);
    expect(fixture.reads.length, greaterThan(1));
    expect(fixture.reads.every((owner) => owner == _ownerA), isTrue);
    expect(controller.value.unreadMessages, 2);
    pending.complete(_snapshot(77));
    await _pump(tester);
    expect(controller.owner, _ownerA);
    expect(controller.value.unreadMessages, 2);
    expect(observed, isNot(contains(77)));
  });

  authTest('an actual B transition cannot accept pending A counts or errors', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    fixture.response = (index) async =>
        index == 0 ? pending.future : _snapshot(3);
    await mount(tester);
    await fixture.client.auth.recoverSession(_session(_ownerB));
    await _pump(tester);
    expect(controller.owner, _ownerB);
    expect(controller.value.unreadMessages, 3);
    pending.complete(http.Response('{"message":"offline"}', 503));
    await _pump(tester);
    expect(controller.value.unreadMessages, 3);
    expect(controller.stale, isFalse);
    expect(fixture.reads, [_ownerA, _ownerB]);
  });

  authTest('logout clears private counts and retires pending readback', (
    tester,
  ) async {
    await mount(tester);
    expect(controller.value.unreadMessages, 7);
    final pending = Completer<http.Response>();
    fixture.response = (_) => pending.future;
    unawaited(controller.refresh());
    await _pump(tester);
    await tester.runAsync(() => fixture.client.auth.signOut());
    await _pump(tester);
    expect(controller.owner, isNull);
    expect(controller.value.total, 0);
    pending.complete(_snapshot(99));
    await _pump(tester);
    expect(controller.value.total, 0);
    expect(find.byType(Badge), findsNothing);
  });

  authTest(
    'same-owner refresh preserves known snapshot and private message count',
    (tester) async {
      fixture.response = (_) async => _snapshot(7, requests: 2, activity: 3);
      await mount(tester);
      final pending = Completer<http.Response>();
      fixture.response = (_) => pending.future;
      await fixture.client.auth.refreshSession();
      await _pump(tester);
      expect(controller.value.total, 12);
      expect(controller.hasSnapshot, isTrue);
      pending.complete(_snapshot(8, requests: 2, activity: 1));
      await _pump(tester);
      expect(controller.value.unreadMessages, 8);
      expect(controller.value.incomingRequests, 2);
      expect(controller.value.communityUpdates, 1);
    },
  );

  authTest(
    'failed current refresh retains authoritative counts then can retry',
    (tester) async {
      await mount(tester);
      fixture.response = (_) async =>
          http.Response('{"message":"offline"}', 503);
      unawaited(controller.refresh());
      await _pump(tester);
      expect(controller.value.unreadMessages, 7);
      expect(controller.stale, isTrue);
      fixture.response = (_) async => _snapshot(4);
      unawaited(controller.refresh());
      await _pump(tester);
      expect(controller.value.unreadMessages, 4);
      expect(controller.stale, isFalse);
    },
  );

  authTest('removed A channel cannot schedule a new A refresh after A B A', (
    tester,
  ) async {
    await mount(tester);
    final previous = fixture.client.getChannels().single;
    await fixture.roundTrip();
    await _pump(tester);
    final count = fixture.reads.length;
    _change(previous);
    await tester.pump(const Duration(milliseconds: 200));
    await _pump(tester);
    expect(fixture.reads, hasLength(count));
    expect(fixture.client.getChannels().single, isNot(same(previous)));
  });

  authTest('current realtime refresh debounces and background does not load', (
    tester,
  ) async {
    await mount(tester);
    final current = fixture.client.getChannels().single;
    final count = fixture.reads.length;
    _change(current);
    _change(current);
    await tester.pump(const Duration(milliseconds: 179));
    expect(fixture.reads, hasLength(count));
    await tester.pump(const Duration(milliseconds: 2));
    await _pump(tester);
    expect(fixture.reads, hasLength(count + 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    _change(current);
    await tester.pump(const Duration(seconds: 46));
    await _pump(tester);
    expect(fixture.reads, hasLength(count + 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pump(tester);
    expect(fixture.reads, hasLength(count + 2));
  });

  authTest('background cancels an already scheduled foreground refresh', (
    tester,
  ) async {
    await mount(tester);
    final count = fixture.reads.length;
    _change(fixture.client.getChannels().single);
    await tester.pump(const Duration(milliseconds: 100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 100));
    await _pump(tester);
    expect(fixture.reads, hasLength(count));
  });

  authTest(
    'an injected attention controller remains caller-owned across client changes',
    (tester) async {
      var loads = 0;
      final external = CommunityAttentionController(() async {
        loads++;
        return const CommunityAttention(unreadMessages: 6);
      });
      external.setOwner('injected-owner');
      await _pump(tester);
      for (final client in [fixture.client, replacement.client]) {
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityAttentionScope(
              client: client,
              controller: external,
              child: const Scaffold(body: CommunityUnreadBadge()),
            ),
          ),
        );
        await _pump(tester);
        expect(external.owner, 'injected-owner');
        expect(find.text('6'), findsOneWidget);
      }
      expect(fixture.reads, isEmpty);
      expect(replacement.reads, isEmpty);
      expect(loads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await external.refresh();
      expect(loads, 2);
      external.dispose();
    },
  );

  authTest(
    'same-owner replacement client retires old request and subscription',
    (tester) async {
      final pending = Completer<http.Response>();
      fixture.response = (_) => pending.future;
      replacement.response = (_) async => _snapshot(5);
      await mount(tester);
      final previous = fixture.client.getChannels().single;
      await mount(tester, client: replacement.client);
      expect(controller.value.unreadMessages, 5);
      expect(replacement.reads, isNotEmpty);
      pending.complete(_snapshot(71));
      await _pump(tester);
      expect(controller.value.unreadMessages, 5);
      final count = replacement.reads.length;
      _change(previous);
      await tester.pump(const Duration(milliseconds: 200));
      await _pump(tester);
      expect(replacement.reads, hasLength(count));
      expect(fixture.client.getChannels(), isEmpty);
    },
  );

  authTest('native badge never publishes the retired A snapshot after A B A', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final pending = Completer<http.Response>();
    fixture.response = (index) async =>
        index == 0 ? pending.future : _snapshot(2);
    await mount(tester);
    await fixture.roundTrip();
    await _pump(tester);
    pending.complete(_snapshot(77));
    await _pump(tester);
    expect(nativeBadges, contains(2));
    expect(nativeBadges, isNot(contains(77)));
  });

  authTest('disposing an outstanding scope has no late badge or subscription', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final pending = Completer<http.Response>();
    fixture.response = (_) => pending.future;
    await mount(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester);
    final badges = List.of(nativeBadges);
    pending.complete(_snapshot(91));
    await _pump(tester);
    expect(nativeBadges, badges);
    expect(fixture.client.getChannels(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
