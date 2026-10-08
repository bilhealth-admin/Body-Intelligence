import 'dart:async';

import 'package:body_intelligence_log/features/community/channels/application/community_channels_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_channels_widget_fixture.dart';

void main() {
  testWidgets(
    'missing capability stays unavailable until an explicit successful retry',
    (tester) async {
      final repository = ChannelWidgetRepository()..capabilityAvailable = false;
      try {
        await pumpChannelWidget(tester, repository);
        expect(
          find.text('This channel is currently unavailable.'),
          findsOneWidget,
        );
        expect(find.text('Fixture channel'), findsNothing);
        expect(find.byKey(const Key('bil07-composer')), findsNothing);
        expect(repository.directoryCalls, 0);
        expect(repository.presence, isEmpty);
        expect(repository.reads, isEmpty);
        repository.capabilityAvailable = true;
        await tester.tap(find.byKey(const Key('bil07-empty-retry')));
        await tester.pump();
        await tester.pump();
        expect(find.text('Fixture channel'), findsOneWidget);
        expect(find.byKey(const Key('bil07-composer')), findsOneWidget);
        expect(repository.attempts, isEmpty);
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'no messages, presence, or composer are exposed without read access',
    (tester) async {
      final repository = ChannelWidgetRepository()
        ..directory = [
          widgetChannel(canRead: false, canSend: false, membership: 'banned'),
        ];
      repository.rows[channelWidgetGeneral] = [
        widgetMessage(1, text: 'Inaccessible synthetic content'),
      ];
      try {
        await pumpChannelWidget(tester, repository);
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text('Your account cannot access this channel.'),
          findsOneWidget,
        );
        expect(find.text('Inaccessible synthetic content'), findsNothing);
        expect(find.byKey(const Key('bil07-composer')), findsNothing);
        expect(repository.messageCalls, 0);
        expect(repository.presence, isEmpty);
        expect(repository.reads, isEmpty);
        expect(repository.attempts, isEmpty);
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'closing during capability load cannot start a late channel subscription',
    (tester) async {
      final response = Completer<CommunityChannelCapabilities>();
      final repository = ChannelWidgetRepository()..capabilityReply = response;
      try {
        await pumpChannelWidget(tester, repository);
        await tester.pumpWidget(const SizedBox.shrink());
        response.complete(
          const CommunityChannelCapabilities(realtimeAvailable: true),
        );
        await tester.pump();
        await tester.pump();
        expect(repository.directoryCalls, 0);
        expect(repository.watchCalls, 0);
        expect(repository.messageCalls, 0);
        expect(repository.presence, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );

  testWidgets(
    'over-limit Unicode draft is retained exactly and cannot be sent',
    (tester) async {
      final repository = ChannelWidgetRepository();
      final drafts = CommunityChannelDraftStore();
      final text = '🥗' * 2001;
      try {
        await pumpChannelWidget(tester, repository, drafts: drafts);
        await tester.enterText(find.byKey(const Key('bil07-composer')), text);
        await tester.pump();
        final field = tester.widget<TextField>(
          find.byKey(const Key('bil07-composer')),
        );
        final send = tester.widget<IconButton>(
          find.byKey(const Key('bil07-send')),
        );
        expect(field.controller!.text, text);
        expect(field.decoration!.counterText, '2001/2000');
        expect(field.decoration!.errorText, contains('has not been shortened'));
        expect(send.onPressed, isNull);
        expect(drafts.text(channelWidgetOwner, channelWidgetGeneral), text);
        expect(repository.attempts, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await closeChannelWidget(tester, [repository]);
      }
    },
  );
}
