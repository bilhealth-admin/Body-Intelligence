import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/channels/application/community_channels_controller.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channels_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const channelWidgetOwner = '11111111-1111-4111-8111-111111111111';
const channelWidgetOtherOwner = '22222222-2222-4222-8222-222222222222';
const channelWidgetPeer = '33333333-3333-4333-8333-333333333333';
const channelWidgetGeneral = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const channelWidgetNutrition = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

CommunityChannel widgetChannel({
  String id = channelWidgetGeneral,
  String title = 'Fixture channel',
  String description = 'Synthetic channel for local widget verification.',
  bool canRead = true,
  bool canSend = true,
  bool enabled = true,
  String membership = 'active',
  int? unread = 7,
  int latest = 20,
}) => CommunityChannel(
  id: id,
  slug: 'fixture',
  title: title,
  description: description,
  visibility: 'public',
  enabled: enabled,
  membership: membership,
  canRead: canRead,
  canSend: canSend,
  unreadCount: unread,
  latestSequence: latest,
);

CommunityChannelMessage widgetMessage(
  int sequence, {
  String channelId = channelWidgetGeneral,
  String authorId = channelWidgetPeer,
  String? authorName = 'Sample member',
  String? text,
  bool isRead = false,
}) => CommunityChannelMessage(
  id: '$channelId-message-$sequence',
  channelId: channelId,
  sequence: sequence,
  authorId: authorId,
  authorDisplayName: authorName,
  text: text ?? 'Synthetic message $sequence',
  clientMessageId: 'fixture-client-$sequence',
  createdAt: DateTime.utc(2026, 10, 7, 9, sequence),
  isRead: isRead,
);

/// In-process fixture only. No Supabase client, HTTP, credentials, or cloud URL.
class ChannelWidgetRepository implements CommunityChannelsRepository {
  String? owner = channelWidgetOwner;
  final owners = StreamController<String?>.broadcast(sync: true);
  final changes = StreamController<CommunityChannelChange>.broadcast(
    sync: true,
  );
  List<CommunityChannel> directory = [widgetChannel()];
  final rows = <String, List<CommunityChannelMessage>>{};
  final reads =
      <({ChannelRequestScope scope, String channel, List<String> ids})>[];
  final presence = <({ChannelRequestScope scope, bool heartbeat})>[];
  final attempts = <CommunityChannelSendAttempt>[];
  final sentRows = <String, CommunityChannelMessage>{};
  int directoryCalls = 0;
  int messageCalls = 0;
  int watchCalls = 0;
  int pageSize = 50;
  bool realtime = false;
  bool presenceAvailable = false;
  bool capabilityAvailable = true;
  bool failNextSendAfterCommit = false;
  int online = 3;
  int? readCount;
  Set<String> Function(List<String>)? confirm;
  Completer<CommunityChannelReadback>? readReply;
  Completer<CommunityChannelMessage>? sendReply;
  Completer<CommunityChannelCapabilities>? capabilityReply;
  final serverTime = DateTime.utc(2026, 10, 7, 12);

  @override
  String? get currentOwnerId => owner;

  @override
  Stream<String?> get ownerChanges => owners.stream;

  void changeOwner(String? next) {
    owner = next;
    owners.add(next);
  }

  @override
  Future<CommunityChannelCapabilities> loadCapabilities(
    ChannelRequestScope scope,
  ) async {
    scope.check();
    if (capabilityReply != null) return capabilityReply!.future;
    if (!capabilityAvailable) {
      throw const ChannelFailure(ChannelFailureKind.unavailable);
    }
    return CommunityChannelCapabilities(realtimeAvailable: realtime);
  }

  @override
  Future<CommunityChannelDirectory> loadDirectory(
    ChannelRequestScope scope, {
    String? afterId,
    int limit = 50,
  }) async {
    scope.check();
    directoryCalls++;
    return CommunityChannelDirectory(
      channels: directory,
      serverTime: serverTime,
    );
  }

  @override
  Future<CommunityChannelMessagePage> loadMessages(
    ChannelRequestScope scope,
    String channelId, {
    int? beforeSequence,
    int? afterSequence,
    int limit = 50,
  }) async {
    scope.check();
    messageCalls++;
    final selected =
        (rows[channelId] ?? const <CommunityChannelMessage>[])
            .where(
              (row) =>
                  (beforeSequence == null || row.sequence < beforeSequence) &&
                  (afterSequence == null || row.sequence > afterSequence),
            )
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final hasMore = selected.length > pageSize;
    final page = !hasMore
        ? selected
        : afterSequence != null
        ? selected.take(pageSize).toList()
        : selected.sublist(selected.length - pageSize);
    return CommunityChannelMessagePage(
      messages: page,
      hasMore: hasMore,
      nextBeforeSequence: page.isEmpty ? null : page.first.sequence,
      nextAfterSequence: page.isEmpty ? afterSequence : page.last.sequence,
      serverTime: serverTime,
    );
  }

  @override
  Future<CommunityChannelReadback> acknowledgeVisible(
    ChannelRequestScope scope,
    String channelId,
    List<String> messageIds,
  ) async {
    scope.check();
    reads.add((scope: scope, channel: channelId, ids: [...messageIds]));
    if (readReply != null) return readReply!.future;
    final confirmed = confirm?.call(messageIds) ?? messageIds.toSet();
    final current = rows[channelId] ?? const <CommunityChannelMessage>[];
    rows[channelId] = [
      for (final row in current)
        if (confirmed.contains(row.id)) row.confirmedRead() else row,
    ];
    return CommunityChannelReadback(
      confirmedIds: confirmed,
      unreadCount:
          readCount ?? rows[channelId]!.where((row) => !row.isRead).length,
      serverTime: serverTime.add(const Duration(seconds: 1)),
    );
  }

  @override
  Future<CommunityChannelPresence> loadPresence(
    ChannelRequestScope scope,
    String channelId, {
    required bool heartbeat,
    required bool Function() isForeground,
  }) async {
    scope.check();
    if (!isForeground()) throw const ChannelVisitCancelled();
    presence.add((scope: scope, heartbeat: heartbeat));
    if (!presenceAvailable) {
      throw const ChannelFailure(ChannelFailureKind.unavailable);
    }
    return CommunityChannelPresence(
      onlineCount: online,
      serverTime: serverTime,
      validUntil: serverTime.add(const Duration(seconds: 30)),
      ownExpiresAt: heartbeat
          ? serverTime.add(const Duration(seconds: 90))
          : null,
    );
  }

  @override
  Future<CommunityChannelMessage> send(
    ChannelRequestScope scope,
    CommunityChannelSendAttempt attempt,
  ) async {
    scope.check();
    attempts.add(attempt);
    if (sendReply != null) return sendReply!.future;
    final existing = sentRows[attempt.clientMessageId];
    if (existing != null) return existing;
    final messages = rows.putIfAbsent(attempt.channelId, () => []);
    final sequence = messages.isEmpty ? 1 : messages.last.sequence + 1;
    final result = CommunityChannelMessage(
      id: 'sent-${attempt.clientMessageId}',
      channelId: attempt.channelId,
      sequence: sequence,
      authorId: attempt.ownerId,
      authorDisplayName: 'Sample sender',
      text: attempt.text,
      clientMessageId: attempt.clientMessageId,
      createdAt: serverTime,
      isRead: true,
    );
    sentRows[attempt.clientMessageId] = result;
    messages.add(result);
    if (failNextSendAfterCommit) {
      failNextSendAfterCommit = false;
      throw const ChannelFailure(ChannelFailureKind.transport);
    }
    return result;
  }

  @override
  Stream<CommunityChannelChange> watchChanges(
    ChannelRequestScope scope,
    String? channelId,
  ) {
    scope.check();
    watchCalls++;
    return changes.stream;
  }

  Future<void> dispose() async {
    await owners.close();
    await changes.close();
  }
}

Future<void> pumpChannelWidget(
  WidgetTester tester,
  ChannelWidgetRepository repository, {
  String? channelId = channelWidgetGeneral,
  CommunityChannelDraftStore? drafts,
  CommunityChannelPolicyReview? reviewPolicy,
  Locale locale = const Locale('en'),
  double scale = 1,
  Key? pageKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: channelId == null
          ? CommunityChannelsPage(
              key: pageKey,
              repository: repository,
              drafts: drafts,
              onReviewPolicy: reviewPolicy,
            )
          : CommunityChannelMessagesPage(
              key: pageKey,
              repository: repository,
              channelId: channelId,
              drafts: drafts,
              onReviewPolicy: reviewPolicy,
            ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> closeChannelWidget(
  WidgetTester tester,
  Iterable<ChannelWidgetRepository> repositories,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  for (final repository in repositories) {
    await repository.dispose();
  }
}

Future<void> pumpChannelActivityFrames(WidgetTester tester) async {
  // The route publishes foreground after its first visible frame. Draw that
  // notification and its asynchronous refresh before measuring a fresh dwell.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void pauseChannelApplication(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void resumeChannelApplication(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.paused) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}
