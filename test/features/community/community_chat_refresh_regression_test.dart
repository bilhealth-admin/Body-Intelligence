import 'dart:async';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ChatRepository extends CommunityRepository {
  _ChatRepository({List<CommunityMessage>? messages})
    : messages = messages ?? <CommunityMessage>[],
      super(
        SupabaseClient(
          'https://chat-unit.invalid',
          'unit-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final changes = StreamController<void>.broadcast();
  final List<CommunityMessage> messages;
  Completer<List<CommunityMessage>>? pendingLoad;
  Completer<void>? pendingSend;
  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';
  @override
  Stream<void> watchConversationChanges(String id) => changes.stream;
  @override
  Future<List<CommunityMessage>> loadMessages(String id) =>
      pendingLoad?.future ??
      Future.value(
        messages.isNotEmpty
            ? List<CommunityMessage>.unmodifiable(messages)
            : [
                CommunityMessage(
                  id: 'message-1',
                  senderId: id,
                  recipientId: currentUserId,
                  body: 'Previously loaded message',
                  createdAt: DateTime(2026, 9, 8, 10, 30),
                ),
              ],
      );
  @override
  Future<void> markConversationRead(String id) async {}
  @override
  Future<void> sendMessage(String id, String body) =>
      pendingSend?.future ?? Future.value();
}

Widget _chat(_ChatRepository repository) => MaterialApp(
  home: CommunityChatPage(
    userId: '22222222-2222-4222-8222-222222222222',
    displayName: 'QA chat',
    repository: repository,
  ),
);
void main() {
  testWidgets(
    'friend chat opens at latest and leaves an older-reading user in place',
    (tester) async {
      final recipient = '22222222-2222-4222-8222-222222222222';
      final repository = _ChatRepository(
        messages: [
          for (var index = 0; index < 30; index++)
            CommunityMessage(
              id: 'message-$index',
              senderId: recipient,
              recipientId: '11111111-1111-4111-8111-111111111111',
              body: index == 29
                  ? 'Latest friend message'
                  : 'Old message $index',
              createdAt: DateTime(2026, 9, 8, 10, index),
            ),
        ],
      );
      addTearDown(repository.changes.close);
      await tester.pumpWidget(_chat(repository));
      await tester.pumpAndSettle();

      final history = find.byKey(const Key('community-message-history'));
      final historyController = tester.widget<ListView>(history).controller!;
      expect(historyController.position.pixels, closeTo(0, 0.5));
      expect(find.text('Latest friend message'), findsOneWidget);

      await tester.drag(history, const Offset(0, 320));
      await tester.pumpAndSettle();
      final readingOffset = historyController.position.pixels;
      expect(readingOffset, greaterThan(72));

      repository.messages.add(
        CommunityMessage(
          id: 'message-30',
          senderId: recipient,
          recipientId: repository.currentUserId,
          body: 'New incoming message',
          createdAt: DateTime(2026, 9, 8, 10, 30),
        ),
      );
      repository.changes.add(null);
      await tester.pumpAndSettle();

      expect(historyController.position.pixels, closeTo(readingOffset, 0.5));
      expect(
        find.byKey(const Key('chat-jump-to-latest')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'realtime refresh keeps selectable history visible while loading',
    (tester) async {
      final repository = _ChatRepository();
      addTearDown(repository.changes.close);
      await tester.pumpWidget(_chat(repository));
      await tester.pumpAndSettle();
      expect(find.text('Previously loaded message'), findsOneWidget);
      repository.pendingLoad = Completer<List<CommunityMessage>>();
      repository.changes.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.text('Previously loaded message'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repository.pendingLoad!.complete([]);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a new draft typed during send is not erased by the old completion',
    (tester) async {
      final repository = _ChatRepository()..pendingSend = Completer<void>();
      addTearDown(repository.changes.close);
      await tester.pumpWidget(_chat(repository));
      await tester.pumpAndSettle();
      final composer = find.byType(TextField);
      await tester.enterText(composer, 'First message');
      await tester.tap(find.widgetWithIcon(IconButton, Icons.send_rounded));
      await tester.pump();
      await tester.enterText(composer, 'Next unsent draft');
      repository.pendingSend!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Next unsent draft',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('leaving during send does not write to a disposed controller', (
    tester,
  ) async {
    final repository = _ChatRepository()..pendingSend = Completer<void>();
    addTearDown(repository.changes.close);
    await tester.pumpWidget(_chat(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test outgoing message');
    final send = find.widgetWithIcon(IconButton, Icons.send_rounded);
    await tester.tap(send);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    repository.pendingSend!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
