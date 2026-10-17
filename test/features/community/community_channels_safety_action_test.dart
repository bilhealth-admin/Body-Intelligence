import 'package:body_intelligence_log/features/community/channels/domain/community_channel_models.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channel_message_tile.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channels_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const author = '35000000-0000-4000-8000-000000000001';
  const visitor = '35000000-0000-4000-8000-000000000002';
  const channel = '35000000-0000-4000-8000-000000000010';
  final message = CommunityChannelMessage(
    id: '35000000-0000-4000-8000-000000000100',
    channelId: channel,
    sequence: 1,
    authorId: author,
    authorDisplayName: 'Fixture author',
    text: 'Fixture reportable text',
    clientMessageId: '35000000-0000-4000-8000-000000000101',
    createdAt: DateTime.utc(2026, 10, 17, 19),
    isRead: false,
  );

  Widget surface(String owner, ValueChanged<CommunityChannelMessage> callback) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CommunityChannelMessageTile(
            message: message,
            ownerId: owner,
            viewportMarker: const Key('fixture-visible-message'),
            onSafety: callback,
          ),
        ),
      ),
    );
  }

  testWidgets('user can open the safety menu on another member message', (tester) async {
    CommunityChannelMessage? selected;
    await tester.pumpWidget(surface(visitor, (message) => selected = message));
    final action = find.byKey(const ValueKey('bil07-message-safety-35000000-0000-4000-8000-000000000100'));
    expect(action, findsOneWidget);
    expect(find.text('Fixture reportable text'), findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    expect(selected?.id, message.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('author cannot report or block their own channel message', (tester) async {
    var actions = 0;
    await tester.pumpWidget(surface(author, (_) => actions++));
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    expect(actions, 0);
  });

  test('safety menu has Arabic and English labels without raw RPC code', () {
    expect(
      CommunityChannelsCopy.forLocale(
        const Locale('ar'),
        CommunityChannelsCopyKey.reportMessage,
      ),
      contains('الإبلاغ'),
    );
    expect(
      CommunityChannelsCopy.forLocale(
        const Locale('en'),
        CommunityChannelsCopyKey.blockMember,
      ),
      contains('Block'),
    );
  });
}
