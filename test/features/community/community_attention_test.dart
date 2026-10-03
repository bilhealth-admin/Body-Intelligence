import 'dart:async';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_attention_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact counts are not capped by an inbox preview or badge label', () {
    final value = CommunityAttention.fromJson({
      'unread_messages': 140,
      'incoming_requests': 3,
      'community_updates': 2,
      'unread_by_sender': {'member': 140},
      'activity_unseen_by_kind': {'friend_accepted': 1, 'reward_earned': 1},
    });
    expect(value.total, 145);
    expect(value.activityUnseenByKind['reward_earned'], 1);
    expect(value.unreadMessages, 140);
    expect(CommunityAttention.badgeText(value.total), '99+');
    expect(CommunityAttention.badgeText(9), '9');
  });
  test('malformed counts are rejected, never converted to a false zero', () {
    for (final invalid in [-1, 1.5, '2', null]) {
      expect(
        () => CommunityAttention.fromJson({
          'unread_messages': invalid,
          'incoming_requests': 0,
          'unread_by_sender': <String, int>{},
        }),
        throwsFormatException,
      );
    }
  });
  test('Activity v2 parser accepts every supported event kind safely', () {
    for (final kind in CommunityNotificationKind.values) {
      final notification = CommunityNotification.fromJson({
        'id': '11111111-1111-4111-8111-111111111111',
        'kind': kind.wireValue,
        'actor_id': null,
        'actor_display_name': null,
        'actor_avatar_url': null,
        'friendship_id': kind == CommunityNotificationKind.friendAccepted
            ? '22222222-2222-4222-8222-222222222222'
            : null,
        'entity_kind': kind == CommunityNotificationKind.friendAccepted
            ? 'friendship'
            : 'reward',
        'entity_id': 'entity-1',
        'copy_key': 'community_activity_test',
        'deep_link_path': '/community/notifications',
        'metadata': <String, dynamic>{},
        'created_at': '2026-10-03T00:00:00Z',
        'seen_at': null,
      });
      expect(notification.kind, kind);
      expect(notification.seen, isFalse);
    }
  });

  test('legacy friend-accepted rows remain parseable', () {
    final notification = CommunityNotification.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'kind': 'friend_accepted',
      'actor_id': null,
      'actor_display_name': null,
      'actor_avatar_url': null,
      'friendship_id': '22222222-2222-4222-8222-222222222222',
      'created_at': '2026-10-03T00:00:00Z',
      'seen_at': null,
    });
    expect(notification.entityKind, 'friendship');
    expect(notification.copyKey, 'friend_accepted_v1');
    expect(notification.deepLinkPath, '/community/notifications');
  });

  test('late response cannot leak badges between accounts', () async {
    final first = Completer<CommunityAttention>();
    final second = Completer<CommunityAttention>();
    var calls = 0;
    final controller = CommunityAttentionController(
      () => calls++ == 0 ? first.future : second.future,
    );
    controller.setOwner('first');
    controller.setOwner('second');
    second.complete(const CommunityAttention(unreadMessages: 2));
    await Future<void>.delayed(Duration.zero);
    first.complete(const CommunityAttention(unreadMessages: 97));
    await Future<void>.delayed(Duration.zero);
    expect(controller.value.unreadMessages, 2);
    controller.setOwner(null);
    expect(controller.value.total, 0);
    controller.dispose();
  });
  test('bursts serialize into one queued authoritative refresh', () async {
    final first = Completer<CommunityAttention>();
    var calls = 0;
    final controller = CommunityAttentionController(() async {
      calls++;
      return calls == 1
          ? first.future
          : const CommunityAttention(unreadMessages: 7);
    });
    controller.setOwner('owner');
    final futures = List.generate(12, (_) => controller.refresh());
    expect(calls, 1);
    first.complete(const CommunityAttention(unreadMessages: 4));
    await Future.wait(futures);
    expect(calls, 2);
    expect(controller.value.total, 7);
    controller.dispose();
  });
  test(
    'a network failure preserves a known count without inventing success',
    () async {
      var fail = false;
      final controller = CommunityAttentionController(() async {
        if (fail) throw StateError('offline');
        return const CommunityAttention(unreadMessages: 5);
      });
      controller.setOwner('owner');
      await controller.refresh();
      fail = true;
      await controller.refresh();
      expect(controller.value.total, 5);
      expect(controller.stale, isTrue);
      controller.dispose();
    },
  );
  test('dispose discards an outstanding response safely', () async {
    final request = Completer<CommunityAttention>();
    final controller = CommunityAttentionController(() => request.future);
    controller.setOwner('owner');
    controller.dispose();
    request.complete(const CommunityAttention(unreadMessages: 8));
    await Future<void>.delayed(Duration.zero);
  });
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'badges stay synchronized at $direction / text scale $scale',
        (tester) async {
          final controller = CommunityAttentionController(
            () async => const CommunityAttention(
              unreadMessages: 4,
              incomingRequests: 2,
              communityUpdates: 3,
            ),
          );
          controller.setOwner('owner');
          await controller.refresh();
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: CommunityAttentionScope(
                    controller: controller,
                    child: const Scaffold(
                      body: Row(
                        children: [
                          CommunityUnreadBadge(
                            kind: CommunityAttentionKind.messages,
                            child: Icon(Icons.chat_bubble_outline),
                          ),
                          SizedBox(width: 40),
                          CommunityUnreadBadge(
                            kind: CommunityAttentionKind.requests,
                          ),
                          SizedBox(width: 40),
                          CommunityUnreadBadge(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('4'), findsOneWidget);
          expect(find.text('2'), findsOneWidget);
          expect(find.text('9'), findsOneWidget);
          expect(tester.takeException(), isNull);
          controller.setOwner(null);
          await tester.pump();
          expect(find.byType(Badge), findsNothing);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        },
      );
    }
  }
}
