import 'dart:async';

import 'package:body_intelligence_log/features/community/channels/application/community_channels_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_channels_widget_fixture.dart';

typedef _PageHook =
    Future<CommunityChannelMessagePage> Function(
      ChannelRequestScope scope,
      String channelId,
      int? before,
      int? after,
    );

class _PagingRepository extends ChannelWidgetRepository {
  _PageHook? pageHook;
  Future<CommunityChannelDirectory> Function(String? after)? directoryHook;
  final pageCursors = <(int?, int?)>[];
  final directoryCursors = <String?>[];
  Completer<CommunityChannelPresence>? presenceReply;
  ChannelRequestScope? pendingPresenceScope;

  @override
  Future<CommunityChannelPresence> loadPresence(
    ChannelRequestScope scope,
    String channelId, {
    required bool heartbeat,
    required bool Function() isForeground,
  }) {
    final reply = presenceReply;
    if (reply == null) {
      return super.loadPresence(
        scope,
        channelId,
        heartbeat: heartbeat,
        isForeground: isForeground,
      );
    }
    scope.check();
    if (!isForeground()) throw const ChannelVisitCancelled();
    pendingPresenceScope = scope;
    return reply.future;
  }

  @override
  Future<CommunityChannelMessagePage> loadMessages(
    ChannelRequestScope scope,
    String channelId, {
    int? beforeSequence,
    int? afterSequence,
    int limit = 50,
  }) {
    pageCursors.add((beforeSequence, afterSequence));
    final hook = pageHook;
    if (hook != null) {
      return hook(scope, channelId, beforeSequence, afterSequence);
    }
    return super.loadMessages(
      scope,
      channelId,
      beforeSequence: beforeSequence,
      afterSequence: afterSequence,
      limit: limit,
    );
  }

  @override
  Future<CommunityChannelDirectory> loadDirectory(
    ChannelRequestScope scope, {
    String? afterId,
    int limit = 50,
  }) {
    directoryCursors.add(afterId);
    final hook = directoryHook;
    if (hook != null) return hook(afterId);
    return super.loadDirectory(scope, afterId: afterId, limit: limit);
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

CommunityChannelsController _controller(
  ChannelWidgetRepository repo, {
  String? channelId = channelWidgetGeneral,
  CommunityChannelDraftStore? drafts,
  DateTime Function()? clock,
}) {
  final controller = CommunityChannelsController(
    repository: repo,
    channelId: channelId,
    drafts: drafts ?? CommunityChannelDraftStore(),
    clock: clock,
  );
  addTearDown(() async {
    controller.dispose();
    await repo.dispose();
  });
  return controller;
}

CommunityChannelMessagePage _page(
  List<CommunityChannelMessage> rows, {
  bool more = false,
}) => CommunityChannelMessagePage(
  messages: rows,
  hasMore: more,
  serverTime: DateTime.utc(2026, 10, 7, 12),
  nextBeforeSequence: rows.isEmpty ? null : rows.first.sequence,
  nextAfterSequence: rows.isEmpty ? null : rows.last.sequence,
);

CommunityChannelMessage _sent(
  CommunityChannelSendAttempt attempt,
  int sequence,
) => CommunityChannelMessage(
  id: 'own-$sequence',
  channelId: attempt.channelId,
  sequence: sequence,
  authorId: attempt.ownerId,
  authorDisplayName: 'Synthetic owner',
  text: attempt.text,
  clientMessageId: attempt.clientMessageId,
  createdAt: DateTime.utc(2026, 10, 7, 12),
  isRead: true,
);

void main() {
  test(
    'missing capability stays unavailable without reads, presence, or sends',
    () async {
      final repo = ChannelWidgetRepository()..capabilityAvailable = false;
      final controller = _controller(repo);
      controller.setForeground(true);
      await controller.initialize();
      controller.updateDraft('Keep this draft');
      await controller.send();
      expect(controller.available, isFalse);
      expect(controller.channels, isEmpty);
      expect(controller.messages, isEmpty);
      expect(controller.draftText, 'Keep this draft');
      expect(repo.attempts, isEmpty);
      expect(repo.reads, isEmpty);
      expect(repo.presence, isEmpty);
    },
  );

  test(
    'reading directory never acknowledges any channel or private messages',
    () async {
      final repo = ChannelWidgetRepository();
      final controller = _controller(repo, channelId: null);
      await controller.initialize();
      await controller.refresh();
      expect(controller.channels.single.unreadCount, 7);
      expect(repo.reads, isEmpty);
      expect(repo.presence, isEmpty);
    },
  );

  test(
    'before paging and new incoming messages merge in stable order',
    () async {
      final repo = _PagingRepository()..pageSize = 2;
      repo.rows[channelWidgetGeneral] = [
        for (var n = 1; n <= 6; n++) widgetMessage(n),
      ];
      final controller = _controller(repo);
      await controller.initialize();
      expect(controller.messages.map((row) => row.sequence), [5, 6]);
      final older = Completer<CommunityChannelMessagePage>();
      repo.pageHook = (_, _, before, _) {
        expect(before, 5);
        return older.future;
      };
      final loading = controller.loadOlder();
      repo.pageHook = null;
      repo.rows[channelWidgetGeneral]!.add(widgetMessage(7));
      await controller.loadNewer();
      older.complete(_page([widgetMessage(3), widgetMessage(4)], more: true));
      await loading;
      expect(controller.messages.map((row) => row.sequence), [3, 4, 5, 6, 7]);
      await controller.loadOlder();
      expect(controller.messages.map((row) => row.sequence), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
      expect(controller.messages.map((row) => row.id).toSet().length, 7);
    },
  );

  test(
    'own send while refresh is pending cannot skip unseen intervening message',
    () async {
      final repo = _PagingRepository();
      repo.directory = [widgetChannel(latest: 100)];
      repo.rows[channelWidgetGeneral] = [
        for (var n = 1; n <= 100; n++) widgetMessage(n),
      ];
      final controller = _controller(repo);
      await controller.initialize();
      final refreshReply = Completer<CommunityChannelMessagePage>();
      repo.pageHook = (_, _, _, after) {
        expect(after, 50);
        return refreshReply.future;
      };
      final refresh = controller.refresh();
      await _flush();
      repo.sendReply = Completer<CommunityChannelMessage>();
      controller.updateDraft('A message after the unseen incoming one');
      final send = controller.send();
      await _flush();
      final own = _sent(repo.attempts.single, 102);
      repo.sendReply!.complete(own);
      await send;
      expect(controller.messages.last.sequence, 102);
      refreshReply.complete(
        _page([for (var n = 51; n <= 100; n++) widgetMessage(n)]),
      );
      await refresh;
      repo.pageHook = null;
      repo.rows[channelWidgetGeneral]!.addAll([widgetMessage(101), own]);
      await controller.loadNewer();
      expect(repo.pageCursors.last.$2, 100);
      expect(
        controller.messages.where((row) => row.sequence == 101),
        hasLength(1),
      );
      expect(
        controller.messages.where((row) => row.sequence == 102),
        hasLength(1),
      );
    },
  );

  test(
    'lost send response retries original key and text while preserving newer draft',
    () async {
      final repo = ChannelWidgetRepository()..failNextSendAfterCommit = true;
      final controller = _controller(repo);
      await controller.initialize();
      controller.updateDraft('  Original text  ');
      await controller.send();
      final pending = controller.pendingSend!;
      expect(controller.draftText, '  Original text  ');
      controller.updateDraft('A newer draft');
      await controller.retrySend();
      expect(repo.attempts, hasLength(2));
      expect(repo.attempts.map((attempt) => attempt.clientMessageId).toSet(), {
        pending.clientMessageId,
      });
      expect(repo.attempts.map((attempt) => attempt.text).toSet(), {
        '  Original text  ',
      });
      expect(repo.sentRows, hasLength(1));
      expect(controller.pendingSend, isNull);
      expect(controller.draftText, 'A newer draft');
      await _flush();
    },
  );

  test(
    'partial readback cannot acknowledge a message arriving during the request',
    () async {
      final repo = ChannelWidgetRepository();
      repo.rows[channelWidgetGeneral] = [widgetMessage(1), widgetMessage(2)];
      final controller = _controller(repo);
      await controller.initialize();
      controller.setForeground(true);
      await _flush();
      repo.readReply = Completer<CommunityChannelReadback>();
      final reading = controller.markSeen(controller.unreadIds.toList());
      repo.rows[channelWidgetGeneral]!.add(widgetMessage(3));
      await controller.loadNewer();
      final first = widgetMessage(1).id;
      repo.readReply!.complete(
        CommunityChannelReadback(
          confirmedIds: {first, 'unrequested-forged-id'},
          unreadCount: 2,
          serverTime: repo.serverTime.add(const Duration(seconds: 1)),
        ),
      );
      expect(await reading, {first});
      expect(controller.unreadIds, {widgetMessage(2).id, widgetMessage(3).id});
      expect(controller.channel!.unreadCount, 2);
    },
  );

  test(
    'covered request cannot block or release a resumed read operation',
    () async {
      final repo = ChannelWidgetRepository();
      repo.rows[channelWidgetGeneral] = [widgetMessage(1)];
      final controller = _controller(repo);
      await controller.initialize();
      controller.setForeground(true);
      await _flush();
      final oldReply = Completer<CommunityChannelReadback>();
      repo.readReply = oldReply;
      final old = controller.markSeen([widgetMessage(1).id]);
      controller.setForeground(false);
      controller.setForeground(true);
      await _flush();
      final newReply = Completer<CommunityChannelReadback>();
      repo.readReply = newReply;
      final current = controller.markSeen([widgetMessage(1).id]);
      expect(repo.reads, hasLength(2));
      oldReply.complete(
        CommunityChannelReadback(
          confirmedIds: {widgetMessage(1).id},
          unreadCount: 0,
          serverTime: repo.serverTime,
        ),
      );
      expect(await old, isEmpty);
      expect(controller.unreadIds, {widgetMessage(1).id});
      expect(await controller.markSeen([widgetMessage(1).id]), isEmpty);
      expect(repo.reads, hasLength(2));
      newReply.complete(
        CommunityChannelReadback(
          confirmedIds: {widgetMessage(1).id},
          unreadCount: 0,
          serverTime: repo.serverTime,
        ),
      );
      expect(await current, {widgetMessage(1).id});
    },
  );

  test('A to B to A permanently retires old capability response', () async {
    final repo = ChannelWidgetRepository()
      ..capabilityReply = Completer<CommunityChannelCapabilities>();
    final controller = _controller(repo);
    final loading = controller.initialize();
    repo.changeOwner(channelWidgetOtherOwner);
    repo.changeOwner(channelWidgetOwner);
    repo.capabilityReply!.complete(const CommunityChannelCapabilities());
    await loading;
    expect(controller.isCurrent, isFalse);
    expect(controller.channels, isEmpty);
    expect(controller.available, isFalse);
    expect(repo.directoryCalls, 0);
  });

  test(
    'cancelled page leaves owner/channel draft and pending attempt intact',
    () async {
      final repo = ChannelWidgetRepository()
        ..sendReply = Completer<CommunityChannelMessage>();
      final drafts = CommunityChannelDraftStore();
      final controller = _controller(repo, drafts: drafts);
      await controller.initialize();
      controller.updateDraft('Private unsent channel draft');
      final sending = controller.send();
      controller.dispose();
      repo.sendReply!.complete(_sent(repo.attempts.single, 1));
      await sending;
      expect(
        drafts.text(channelWidgetOwner, channelWidgetGeneral),
        'Private unsent channel draft',
      );
      expect(
        drafts.pending(channelWidgetOwner, channelWidgetGeneral),
        isNotNull,
      );
      expect(
        drafts.text(channelWidgetOtherOwner, channelWidgetGeneral),
        isEmpty,
      );
      expect(drafts.text(channelWidgetOwner, channelWidgetNutrition), isEmpty);
    },
  );

  test(
    'permission refresh removes cached rows and rejects stale page response',
    () async {
      final repo = _PagingRepository()..pageSize = 2;
      repo.rows[channelWidgetGeneral] = [
        for (var n = 1; n <= 4; n++) widgetMessage(n),
      ];
      final controller = _controller(repo);
      await controller.initialize();
      final older = Completer<CommunityChannelMessagePage>();
      repo.pageHook = (_, _, _, _) => older.future;
      final loading = controller.loadOlder();
      repo.directory = [];
      await controller.refreshAccess();
      older.complete(_page([widgetMessage(1), widgetMessage(2)]));
      await loading;
      expect(controller.channel, isNull);
      expect(controller.messages, isEmpty);
      expect(controller.canSend, isFalse);
      expect(controller.onlineCount, isNull);
    },
  );

  test(
    'permission denial clears cached messages before access reload completes',
    () async {
      final repo = _PagingRepository()..pageSize = 2;
      repo.rows[channelWidgetGeneral] = [
        for (var n = 1; n <= 4; n++) widgetMessage(n),
      ];
      final controller = _controller(repo);
      await controller.initialize();
      final directoryReply = Completer<CommunityChannelDirectory>();
      repo.directoryHook = (_) => directoryReply.future;
      repo.pageHook = (_, _, _, _) async =>
          throw const ChannelFailure(ChannelFailureKind.denied);
      await controller.loadOlder();
      expect(controller.messages, isEmpty);
      expect(controller.canSend, isFalse);
      expect(controller.channel, isNull);
      directoryReply.complete(
        CommunityChannelDirectory(channels: [], serverTime: repo.serverTime),
      );
      await _flush();
    },
  );

  test(
    'permission loss fences pending send even if channel access returns',
    () async {
      final repo = ChannelWidgetRepository()
        ..sendReply = Completer<CommunityChannelMessage>();
      final controller = _controller(repo);
      await controller.initialize();
      controller.updateDraft('Keep the original permission-scoped attempt');
      final sending = controller.send();
      final attempt = repo.attempts.single;
      repo.directory = [];
      await controller.refreshAccess();
      repo.directory = [widgetChannel()];
      await controller.refreshAccess();
      repo.sendReply!.complete(_sent(attempt, 1));
      await sending;
      expect(controller.messages, isEmpty);
      expect(controller.draftText, attempt.text);
      expect(controller.pendingSend, same(attempt));
    },
  );

  test(
    'old presence cannot return after access is revoked and restored',
    () async {
      final reply = Completer<CommunityChannelPresence>();
      final repo = _PagingRepository()
        ..presenceAvailable = true
        ..presenceReply = reply;
      final controller = _controller(repo);
      await controller.initialize();
      controller.setForeground(true);
      await _flush();
      final originalScope = repo.pendingPresenceScope!;
      expect(originalScope.isCurrent, isTrue);
      repo.directory = [];
      await controller.refreshAccess();
      expect(originalScope.isCurrent, isFalse);
      expect(controller.onlineCount, isNull);
      repo.directory = [widgetChannel()];
      await controller.refreshAccess();
      expect(originalScope.isCurrent, isFalse);
      repo.presenceReply = null;
      reply.complete(
        CommunityChannelPresence(
          onlineCount: 99,
          serverTime: repo.serverTime,
          validUntil: repo.serverTime.add(const Duration(seconds: 30)),
          ownExpiresAt: repo.serverTime.add(const Duration(seconds: 90)),
        ),
      );
      await _flush();
      expect(controller.onlineCount, isNull);
      await controller.refresh();
      expect(controller.onlineCount, 3);
    },
  );

  test(
    'reconciliation removes a newly blocked author from the loaded range',
    () async {
      final repo = _PagingRepository();
      repo.rows[channelWidgetGeneral] = [widgetMessage(1), widgetMessage(2)];
      final controller = _controller(repo);
      await controller.initialize();
      repo.rows[channelWidgetGeneral] = [widgetMessage(2, authorName: null)];
      await controller.refresh();
      expect(controller.messages.map((row) => row.sequence), [2]);
      expect(controller.messages.single.authorDisplayName, isNull);
    },
  );

  test(
    'a first-page refresh queued behind more paging actually reloads access',
    () async {
      final repo = _PagingRepository();
      var firstReads = 0;
      final moreReply = Completer<CommunityChannelDirectory>();
      repo.directoryHook = (after) async {
        if (after != null) return moreReply.future;
        firstReads++;
        return CommunityChannelDirectory(
          channels: firstReads == 1 ? [widgetChannel()] : [],
          serverTime: repo.serverTime,
          nextAfterId: firstReads == 1 ? channelWidgetGeneral : null,
        );
      };
      final controller = _controller(repo, channelId: null);
      await controller.initialize();
      final more = controller.loadDirectory(more: true);
      final refresh = controller.refreshAccess();
      moreReply.complete(
        CommunityChannelDirectory(
          channels: [widgetChannel(id: channelWidgetNutrition)],
          serverTime: repo.serverTime,
        ),
      );
      await Future.wait([more, refresh]);
      expect(repo.directoryCursors, [null, channelWidgetGeneral, null]);
      expect(controller.channels, isEmpty);
    },
  );

  test(
    'presence expires to unknown and background immediately invalidates it',
    () async {
      final repo = ChannelWidgetRepository()..presenceAvailable = true;
      var now = DateTime.utc(
        2040,
        1,
        1,
      ); // deliberately skewed from server time
      final controller = _controller(repo, clock: () => now);
      await controller.initialize();
      controller.setForeground(true);
      await _flush();
      expect(controller.onlineCount, 3);
      now = now.add(const Duration(seconds: 31));
      expect(controller.onlineCount, isNull);
      await controller.refresh();
      expect(controller.onlineCount, 3);
      controller.setForeground(false);
      expect(controller.onlineCount, isNull);
    },
  );

  test(
    'reconnect creates a new subscription and catches up missed messages',
    () async {
      final repo = ChannelWidgetRepository()..realtime = true;
      repo.rows[channelWidgetGeneral] = [widgetMessage(1)];
      final controller = _controller(repo);
      await controller.initialize();
      controller.setForeground(true);
      await _flush();
      expect(repo.watchCalls, 1);
      repo.changes.add(CommunityChannelChange.disconnected);
      expect(
        controller.connectionState,
        CommunityChannelConnectionState.disconnected,
      );
      repo.rows[channelWidgetGeneral]!.add(widgetMessage(2));
      await controller.reconnect();
      expect(repo.watchCalls, 2);
      expect(controller.messages.map((row) => row.sequence), [1, 2]);
      repo.changes.add(CommunityChannelChange.connected);
      await _flush();
      expect(
        controller.connectionState,
        CommunityChannelConnectionState.connected,
      );
    },
  );
}
