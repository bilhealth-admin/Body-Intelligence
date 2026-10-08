import 'dart:async';

import 'package:body_intelligence_log/features/community/channels/application/community_channels_controller.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channels_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_channels_widget_fixture.dart';

void main() {
  testWidgets(
    'directory uses authorized server rows and never marks channels read',
    (tester) async {
      final repository = ChannelWidgetRepository()
        ..directory = [
          widgetChannel(title: 'Fixture General', unread: 11),
          widgetChannel(
            id: channelWidgetNutrition,
            title: 'Fixture Nutrition',
            unread: null,
          ),
          widgetChannel(
            id: 'hidden-fixture',
            title: 'Hidden fixture',
            canRead: false,
          ),
        ];
      try {
        await pumpChannelWidget(tester, repository, channelId: null);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Fixture General'), findsOneWidget);
        expect(find.text('Fixture Nutrition'), findsOneWidget);
        expect(find.text('Hidden fixture'), findsNothing);
        expect(find.text('Unread: 11'), findsOneWidget);
        expect(find.text('Unread count unavailable'), findsOneWidget);
        expect(repository.reads, isEmpty);
        expect(repository.presence, isEmpty);
        expect(repository.attempts, isEmpty);
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets('only actual viewport messages qualify after continuous dwell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ChannelWidgetRepository();
    repository.rows[channelWidgetGeneral] = [
      for (var index = 1; index <= 15; index++)
        widgetMessage(
          index,
          text: 'Message $index. ${'A local fixture sentence. ' * 5}',
        ),
    ];
    try {
      await pumpChannelWidget(tester, repository);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.reads, isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 30));
      final seen = repository.reads.expand((read) => read.ids).toSet();
      expect(seen, isNotEmpty);
      expect(seen.length, lessThan(15));
      expect(seen, contains('$channelWidgetGeneral-message-15'));
      expect(seen, isNot(contains('$channelWidgetGeneral-message-1')));
      expect(find.text('Online count unavailable'), findsOneWidget);
      expect(find.text('Online: 0'), findsNothing);
    } finally {
      await closeChannelWidget(tester, [repository]);
    }
  });

  testWidgets(
    'covered route stops dwell and presence, uncover starts a fresh dwell',
    (tester) async {
      final repository = ChannelWidgetRepository()..presenceAvailable = true;
      repository.rows[channelWidgetGeneral] = [widgetMessage(1)];
      try {
        await pumpChannelWidget(tester, repository);
        await tester.pump(const Duration(milliseconds: 250));
        expect(repository.presence, isNotEmpty);
        final navigator = Navigator.of(
          tester.element(find.byKey(const Key('bil07-channels-page'))),
        );
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Cover fixture')),
            ),
          ),
        );
        await tester.pump();
        final presenceAtCover = repository.presence.length;
        await tester.pump(const Duration(seconds: 31));
        expect(repository.reads, isEmpty);
        expect(repository.presence.length, presenceAtCover);
        navigator.pop();
        await pumpChannelActivityFrames(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.reads, isEmpty);
        await tester.pump(const Duration(milliseconds: 360));
        await tester.pump(const Duration(milliseconds: 30));
        expect(repository.reads, isNotEmpty);
        expect(repository.presence.length, greaterThan(presenceAtCover));
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'resume can confirm a new read before the old covered request ends',
    (tester) async {
      final oldReply = Completer<CommunityChannelReadback>();
      final repository = ChannelWidgetRepository()
        ..readReply = oldReply
        ..readCount = 8;
      repository.rows[channelWidgetGeneral] = [widgetMessage(1)];
      try {
        await pumpChannelWidget(tester, repository);
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 30));
        expect(repository.reads, hasLength(1));
        final navigator = Navigator.of(
          tester.element(find.byKey(const Key('bil07-channels-page'))),
        );
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Pending read cover')),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        repository.readReply = null;
        navigator.pop();
        await pumpChannelActivityFrames(tester);
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 30));
        expect(repository.reads, hasLength(2));
        expect(find.text('Unread: 8'), findsOneWidget);
        oldReply.complete(
          CommunityChannelReadback(
            confirmedIds: repository.reads.first.ids.toSet(),
            unreadCount: 0,
            serverTime: repository.serverTime.add(const Duration(minutes: 1)),
          ),
        );
        await tester.pump();
        expect(find.text('Unread: 8'), findsOneWidget);
        expect(find.text('Unread: 0'), findsNothing);
        expect(find.byKey(const Key('bil07-read-unconfirmed')), findsNothing);
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets('background cancels read dwell and heartbeat until resumed', (
    tester,
  ) async {
    final repository = ChannelWidgetRepository()..presenceAvailable = true;
    repository.rows[channelWidgetGeneral] = [widgetMessage(1)];
    try {
      await pumpChannelWidget(tester, repository);
      await tester.pump(const Duration(milliseconds: 250));
      pauseChannelApplication(tester);
      await tester.pump();
      final backgroundPresence = repository.presence.length;
      await tester.pump(const Duration(seconds: 31));
      expect(repository.reads, isEmpty);
      expect(repository.presence.length, backgroundPresence);
      resumeChannelApplication(tester);
      await pumpChannelActivityFrames(tester);
      await tester.pump(const Duration(milliseconds: 350));
      expect(repository.reads, isEmpty);
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 30));
      expect(repository.reads, isNotEmpty);
    } finally {
      resumeChannelApplication(tester);
      await closeChannelWidget(tester, [repository]);
    }
  });

  testWidgets(
    'partial readback preserves unconfirmed rows and authoritative count',
    (tester) async {
      tester.view.physicalSize = const Size(390, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ChannelWidgetRepository()
        ..readCount = 9
        ..confirm = (ids) => {ids.first};
      repository.rows[channelWidgetGeneral] = [
        widgetMessage(1),
        widgetMessage(2),
      ];
      try {
        await pumpChannelWidget(tester, repository);
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump();
        expect(repository.reads, hasLength(1));
        expect(repository.reads.single.ids, hasLength(2));
        expect(find.text('Unread: 9'), findsOneWidget);
        expect(find.byKey(const Key('bil07-read-unconfirmed')), findsOneWidget);
        final confirmed = repository.reads.single.ids.first;
        final unconfirmed = repository.reads.single.ids.last;
        expect(find.byKey(ValueKey('bil07-unread-$confirmed')), findsNothing);
        expect(
          find.byKey(ValueKey('bil07-unread-$unconfirmed')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(repository.reads, hasLength(1));
        repository.confirm = (ids) => ids.toSet();
        repository.readCount = 8;
        await tester.tap(find.byKey(const Key('bil07-retry-read')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 30));
        expect(repository.reads, hasLength(2));
        expect(find.text('Unread: 8'), findsOneWidget);
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'lost send response retries original text and id while keeping a newer draft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ChannelWidgetRepository()
        ..failNextSendAfterCommit = true
        ..realtime = true;
      final drafts = CommunityChannelDraftStore();
      const original = '  Original 👋\nmessage  ';
      try {
        await pumpChannelWidget(tester, repository, drafts: drafts);
        await tester.enterText(
          find.byKey(const Key('bil07-composer')),
          original,
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('bil07-send')));
        await tester.pump();
        await tester.pump();
        expect(repository.attempts, hasLength(1));
        expect(repository.attempts.single.text, original);
        expect(find.byKey(const Key('bil07-pending-attempt')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('bil07-composer')),
          'A newer draft',
        );
        repository.changes.add(CommunityChannelChange.connected);
        await tester.pump();
        await tester.pump();
        expect(
          repository.attempts,
          hasLength(1),
          reason: 'Reconnect must not send.',
        );
        await tester.ensureVisible(find.byKey(const Key('bil07-retry-send')));
        await tester.tap(find.byKey(const Key('bil07-retry-send')));
        await tester.pump();
        await tester.pump();
        expect(repository.attempts, hasLength(2));
        expect(repository.attempts.last.text, original);
        expect(
          repository.attempts.last.clientMessageId,
          repository.attempts.first.clientMessageId,
        );
        expect(repository.sentRows, hasLength(1));
        expect(
          drafts.text(channelWidgetOwner, channelWidgetGeneral),
          'A newer draft',
        );
        expect(
          drafts.pending(channelWidgetOwner, channelWidgetGeneral),
          isNull,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('bil07-composer')))
              .controller!
              .text,
          'A newer draft',
        );
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'channel navigation keeps separate drafts without sending on restore',
    (tester) async {
      final repository = ChannelWidgetRepository()
        ..directory = [
          widgetChannel(),
          widgetChannel(id: channelWidgetNutrition),
        ];
      final drafts = CommunityChannelDraftStore();
      try {
        await pumpChannelWidget(tester, repository, drafts: drafts);
        await tester.enterText(
          find.byKey(const Key('bil07-composer')),
          'General draft',
        );
        await pumpChannelWidget(
          tester,
          repository,
          channelId: channelWidgetNutrition,
          drafts: drafts,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('bil07-composer')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.enterText(
          find.byKey(const Key('bil07-composer')),
          'Nutrition draft',
        );
        await pumpChannelWidget(tester, repository, drafts: drafts);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('bil07-composer')))
              .controller!
              .text,
          'General draft',
        );
        expect(
          drafts.text(channelWidgetOwner, channelWidgetNutrition),
          'Nutrition draft',
        );
        expect(repository.attempts, isEmpty);
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'owner A to B to A permanently retires old send and does not auto retry',
    (tester) async {
      final reply = Completer<CommunityChannelMessage>();
      final repository = ChannelWidgetRepository()..sendReply = reply;
      final drafts = CommunityChannelDraftStore();
      try {
        await pumpChannelWidget(
          tester,
          repository,
          drafts: drafts,
          pageKey: const ValueKey('visit-one'),
        );
        await tester.enterText(
          find.byKey(const Key('bil07-composer')),
          'Owner A draft',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('bil07-send')));
        await tester.pump();
        final attempted = repository.attempts.single;
        repository
          ..changeOwner(channelWidgetOtherOwner)
          ..changeOwner(channelWidgetOwner);
        await tester.pump();
        expect(
          find.text('Your account changed. Return to Community to continue.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('bil07-composer')), findsNothing);
        reply.complete(
          CommunityChannelMessage(
            id: 'late-send',
            channelId: attempted.channelId,
            sequence: 1,
            authorId: attempted.ownerId,
            authorDisplayName: 'Sample sender',
            text: attempted.text,
            clientMessageId: attempted.clientMessageId,
            createdAt: repository.serverTime,
            isRead: true,
          ),
        );
        await tester.pump();
        expect(find.text('Owner A draft'), findsNothing);
        expect(
          drafts.pending(channelWidgetOwner, channelWidgetGeneral),
          isNotNull,
        );
        await pumpChannelWidget(
          tester,
          repository,
          drafts: drafts,
          pageKey: const ValueKey('visit-two'),
        );
        expect(repository.attempts, hasLength(1));
        expect(find.byKey(const Key('bil07-pending-attempt')), findsOneWidget);
        expect(
          drafts.text(channelWidgetOtherOwner, channelWidgetGeneral),
          isEmpty,
        );
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'an old Send callback cannot send the replacement channel draft',
    (tester) async {
      final repository = ChannelWidgetRepository()
        ..directory = [
          widgetChannel(),
          widgetChannel(id: channelWidgetNutrition),
        ];
      final drafts = CommunityChannelDraftStore();
      try {
        await pumpChannelWidget(tester, repository, drafts: drafts);
        await tester.enterText(
          find.byKey(const Key('bil07-composer')),
          'Old channel draft',
        );
        await tester.pump();
        final oldSend = tester
            .widget<IconButton>(find.byKey(const Key('bil07-send')))
            .onPressed!;
        await pumpChannelWidget(
          tester,
          repository,
          channelId: channelWidgetNutrition,
          drafts: drafts,
        );
        await tester.enterText(
          find.byKey(const Key('bil07-composer')),
          'New channel draft',
        );
        oldSend();
        await tester.pump();
        expect(repository.attempts, isEmpty);
        expect(
          drafts.text(channelWidgetOwner, channelWidgetNutrition),
          'New channel draft',
        );
        await tester.tap(find.byKey(const Key('bil07-send')));
        await tester.pump();
        expect(repository.attempts.single.channelId, channelWidgetNutrition);
        expect(repository.attempts.single.text, 'New channel draft');
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'repository replacement cannot publish old readback into a new visit',
    (tester) async {
      final reply = Completer<CommunityChannelReadback>();
      final first = ChannelWidgetRepository()..readReply = reply;
      final second = ChannelWidgetRepository();
      first.rows[channelWidgetGeneral] = [widgetMessage(1)];
      second.rows[channelWidgetGeneral] = [widgetMessage(1)];
      try {
        await pumpChannelWidget(tester, first);
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 30));
        expect(first.reads, hasLength(1));
        await pumpChannelWidget(tester, second);
        reply.complete(
          CommunityChannelReadback(
            confirmedIds: first.reads.single.ids.toSet(),
            unreadCount: 0,
            serverTime: first.serverTime.add(const Duration(minutes: 1)),
          ),
        );
        await tester.pump();
        expect(find.text('Unread: 7'), findsOneWidget);
        expect(find.text('Unread: 0'), findsNothing);
        expect(second.reads, isEmpty);
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 30));
        expect(second.reads, hasLength(1));
        expect(
          second.reads.single.scope.visitGeneration,
          isNot(first.reads.single.scope.visitGeneration),
        );
      } finally {
        await closeChannelWidget(tester, [first, second]);
      }
    },
  );

  testWidgets('policy review is explicit and returning never sends a draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ChannelWidgetRepository()
      ..directory = [widgetChannel(canSend: false)];
    var reviews = 0;
    final drafts = CommunityChannelDraftStore();
    try {
      await pumpChannelWidget(
        tester,
        repository,
        drafts: drafts,
        reviewPolicy: (_, isCurrent) async {
          expect(isCurrent(), isTrue);
          reviews++;
          repository.directory = [widgetChannel(canSend: true)];
        },
      );
      await tester.enterText(
        find.byKey(const Key('bil07-composer')),
        'Keep this draft',
      );
      expect(reviews, 0);
      expect(repository.attempts, isEmpty);
      await tester.ensureVisible(find.byKey(const Key('bil07-review-policy')));
      await tester.tap(find.byKey(const Key('bil07-review-policy')));
      await tester.pump();
      await tester.pump();
      expect(reviews, 1);
      expect(repository.attempts, isEmpty);
      expect(
        drafts.text(channelWidgetOwner, channelWidgetGeneral),
        'Keep this draft',
      );
      await tester.tap(find.byKey(const Key('bil07-send')));
      await tester.pump();
      expect(repository.attempts, hasLength(1));
    } finally {
      await closeChannelWidget(tester, [repository]);
    }
  });

  testWidgets('reconnect is explicit and does not reuse a canceled watcher', (
    tester,
  ) async {
    final repository = ChannelWidgetRepository()..realtime = true;
    try {
      await pumpChannelWidget(tester, repository);
      final before = repository.watchCalls;
      expect(before, 1);
      repository.changes.add(CommunityChannelChange.disconnected);
      await tester.pump();
      expect(find.byKey(const Key('bil07-disconnected')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('bil07-reconnect')));
      await tester.tap(find.byKey(const Key('bil07-reconnect')));
      await tester.pump();
      await tester.pump();
      expect(repository.watchCalls, greaterThan(before));
      expect(repository.attempts, isEmpty);
    } finally {
      await closeChannelWidget(tester, [repository]);
    }
  });

  testWidgets(
    'Arabic channel at 2x text keeps RTL labels and accessible controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ChannelWidgetRepository()
        ..directory = [
          widgetChannel(
            title: 'قناة تجريبية للمجتمع',
            description: 'وصف تجريبي',
          ),
        ];
      repository.rows[channelWidgetGeneral] = [
        widgetMessage(
          1,
          authorName: null,
          text: 'رسالة عربية تجريبية للتحقق من اتجاه النص.',
        ),
      ];
      final semantics = tester.ensureSemantics();
      try {
        await pumpChannelWidget(
          tester,
          repository,
          locale: const Locale('ar'),
          scale: 2,
          drafts: CommunityChannelDraftStore(),
        );
        await tester.enterText(
          find.byKey(const Key('bil07-composer')),
          'مسودة عربية',
        );
        await tester.pump();
        final field = tester.widget<TextField>(
          find.byKey(const Key('bil07-composer')),
        );
        expect(field.textDirection, TextDirection.rtl);
        expect(find.byTooltip('إرسال الرسالة'), findsOneWidget);
        expect(find.text('عدد المتصلين غير متاح'), findsOneWidget);
        expect(find.text(channelWidgetPeer), findsNothing);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        semantics.dispose();
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  test(
    'role copy covers every EN/AR key and leaves other locales as fallback',
    () {
      expect(
        CommunityChannelsCopy.english.keys.toSet(),
        CommunityChannelsCopyKey.values.toSet(),
      );
      expect(
        CommunityChannelsCopy.arabic.keys.toSet(),
        CommunityChannelsCopyKey.values.toSet(),
      );
      for (final key in CommunityChannelsCopyKey.values) {
        expect(CommunityChannelsCopy.arabic[key], isNotEmpty);
        expect(
          CommunityChannelsCopy.arabic[key],
          isNot(CommunityChannelsCopy.english[key]),
        );
        expect(
          CommunityChannelsCopy.forLocale(const Locale('fr'), key),
          CommunityChannelsCopy.english[key],
        );
      }
      expect(
        CommunityChannelsCopy.forLocale(
          const Locale('ar'),
          CommunityChannelsCopyKey.textLimit,
          {'limit': 2000},
        ),
        contains('2000'),
      );
    },
  );
}
