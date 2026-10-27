import '../../../tools/qa/flutter/native_conversation_observer.dart';
import '../../support/bil_waiting_indicators.dart';
import 'dart:async';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_reply_arrival.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_sent_message_arrival.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ChatRepository extends CommunityRepository {
  _ChatRepository(super.client, {List<CommunityMessage>? messages})
    : messages = messages ?? <CommunityMessage>[];
  final changes = StreamController<void>.broadcast();
  final List<CommunityMessage> messages;
  Completer<List<CommunityMessage>>? pendingLoad;
  Completer<void>? pendingSend;
  bool appendSentMessage = false;
  int sendCalls = 0;
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
  Future<int> markVisibleMessagesRead(List<String> ids) async => ids.length;
  @override
  Future<Set<String>> loadReadMessageIds(String peer, List<String> ids) async =>
      ids.toSet();
  @override
  Future<void> sendMessageOperation(
    String recipientId,
    String body, {
    required String requestId,
  }) => sendMessage(recipientId, body);

  @override
  Future<void> sendMessage(String id, String body) async {
    sendCalls++;
    await (pendingSend?.future ?? Future.value());
    if (appendSentMessage) {
      messages.add(
        CommunityMessage(
          id: 'accepted-own-$sendCalls',
          senderId: currentUserId,
          recipientId: id,
          body: body,
          createdAt: DateTime(2026, 10, 26, 12, sendCalls),
        ),
      );
    }
  }
}

Widget _chat(_ChatRepository repository) => MaterialApp(
  home: CommunityChatPage(
    userId: '22222222-2222-4222-8222-222222222222',
    displayName: 'QA chat',
    repository: repository,
  ),
);
void main() {
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://chat-unit.invalid',
      'unit-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() async {
    await client.dispose();
  });
  testWidgets(
    'accepted iOS send is observable while an independent ticker remains active',
    (tester) async {
      final repository = _ChatRepository(client)..appendSentMessage = true;
      addTearDown(repository.changes.close);
      await tester.pumpWidget(_chat(repository));
      await tester.pumpAndSettle();
      final composer = find.byKey(const Key('community-message-composer'));
      final button = find.byKey(const Key('community-chat-send'));
      await tester.enterText(composer, 'Acknowledged iOS message');
      await tester.tap(button);
      final ongoing = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      )..repeat();
      await nativeQaAwaitAcceptedConversationSend(
        tester,
        sendCount: () => repository.sendCalls,
        composer: composer,
        sendButton: button,
        acceptedRow: find.byKey(
          const Key('community-message-text-accepted-own-1'),
        ),
        viewport: find.byKey(const Key('community-message-history')),
      );
      expect(repository.sendCalls, 1);
      expect(find.text('Acknowledged iOS message'), findsOneWidget);
      expect(tester.widget<TextField>(composer).controller!.text, '');
      final editable = find.descendant(
        of: composer,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      expect(ongoing.isAnimating, isTrue);
      FlutterError? idleError;
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 20),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
      } on FlutterError catch (error) {
        idleError = error;
      }
      expect(idleError.toString(), contains('pumpAndSettle timed out'));
      ongoing.dispose();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'conversation observer refuses a send before acknowledgement',
    (tester) async {
      final acknowledgement = Completer<void>();
      final repository = _ChatRepository(client)
        ..appendSentMessage = true
        ..pendingSend = acknowledgement;
      addTearDown(repository.changes.close);
      await tester.pumpWidget(_chat(repository));
      await tester.pumpAndSettle();
      final composer = find.byKey(const Key('community-message-composer'));
      final button = find.byKey(const Key('community-chat-send'));
      await tester.enterText(composer, 'Keep until acknowledged');
      await tester.tap(button);
      Object? pendingError;
      try {
        await nativeQaAwaitAcceptedConversationSend(
          tester,
          sendCount: () => repository.sendCalls,
          composer: composer,
          sendButton: button,
          acceptedRow: find.byKey(
            const Key('community-message-text-accepted-own-1'),
          ),
          viewport: find.byKey(const Key('community-message-history')),
        );
      } catch (error) {
        pendingError = error;
      }
      expect(
        pendingError.toString(),
        contains('Send did not reach one acknowledged'),
      );
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Keep until acknowledged',
      );
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      acknowledgement.complete();
      await nativeQaAwaitAcceptedConversationSend(
        tester,
        sendCount: () => repository.sendCalls,
        composer: composer,
        sendButton: button,
        acceptedRow: find.byKey(
          const Key('community-message-text-accepted-own-1'),
        ),
        viewport: find.byKey(const Key('community-message-history')),
      );
      expect(repository.sendCalls, 1);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'accepted DM history and latest navigation at scale $scale',
      (tester) async {
        tester.view.reset();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(402, 874);
        addTearDown(tester.view.reset);
        final repository = _ChatRepository(
          client,
          messages: List.generate(
            24,
            (index) => CommunityMessage(
              id: 'old-$index',
              senderId: '22222222-2222-4222-8222-222222222222',
              recipientId: '11111111-1111-4111-8111-111111111111',
              body:
                  'Previously acknowledged history message $index. Read the saved plan before making changes.',
              createdAt: DateTime(2026, 10, 25, 8, index),
            ),
          ),
        )..appendSentMessage = true;
        addTearDown(repository.changes.close);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: CommunityChatPage(
              userId: '22222222-2222-4222-8222-222222222222',
              displayName: 'QA chat',
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final composer = find.byKey(const Key('community-message-composer'));
        final button = find.byKey(const Key('community-chat-send'));
        final history = find.byKey(const Key('community-message-history'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 336);
        await tester.pump();
        await tester.enterText(
          composer,
          'Received the plan; this is a local test message.',
        );
        await tester.tap(button);
        await nativeQaAwaitAcceptedConversationSend(
          tester,
          sendCount: () => repository.sendCalls,
          composer: composer,
          sendButton: button,
          acceptedRow: find.byKey(
            const Key('community-message-text-accepted-own-1'),
          ),
          viewport: history,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.drag(history, const Offset(0, 300));
        await tester.pumpAndSettle();
        final latest = find.byKey(const ValueKey('chat-jump-to-latest'));
        expect(latest.hitTestable(), findsOneWidget);
        await tester.tap(latest);
        await tester.pumpAndSettle();
        final controller = tester.widget<ListView>(history).controller!;
        expect(
          controller.offset,
          closeTo(controller.position.minScrollExtent, 1),
        );
        expect(repository.sendCalls, 1);
        expect(tester.widget<TextField>(composer).controller!.text, '');
        expect(
          find.text('Received the plan; this is a local test message.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets('accepted DM travels to its own bubble without a second send', (
    tester,
  ) async {
    final repository = _ChatRepository(client)..appendSentMessage = true;
    addTearDown(repository.changes.close);
    await tester.pumpWidget(_chat(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Accepted outgoing text');
    await tester.tap(find.byKey(const Key('community-chat-send')));
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final arrival = find.byType(CoachSentMessageArrival);
    expect(arrival, findsOneWidget);
    expect(tester.widget<CoachSentMessageArrival>(arrival).origin, isNotNull);
    final flight = find.byKey(const ValueKey('coach-sent-message-flight'));
    expect(flight, findsOneWidget);
    final history = find.byKey(const Key('community-message-history'));
    expect(
      tester.getRect(arrival).width,
      lessThan(tester.getRect(history).width),
    );
    expect(repository.sendCalls, 1);
    expect(find.text('Accepted outgoing text'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(flight, findsNothing);
    expect(repository.sendCalls, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('new DM uses Coach entrance once without replaying history', (
    tester,
  ) async {
    final repository = _ChatRepository(
      client,
      messages: [
        CommunityMessage(
          id: 'history',
          senderId: '22222222-2222-4222-8222-222222222222',
          recipientId: '11111111-1111-4111-8111-111111111111',
          body: 'Visible historical text',
          createdAt: DateTime(2026, 10, 25),
        ),
      ],
    );
    addTearDown(repository.changes.close);
    await tester.pumpWidget(_chat(repository));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CoachReplyArrival>(find.byType(CoachReplyArrival)).animate,
      isFalse,
    );
    repository.messages.add(
      CommunityMessage(
        id: 'new-incoming',
        senderId: '22222222-2222-4222-8222-222222222222',
        recipientId: repository.currentUserId,
        body: 'New incoming text',
        createdAt: DateTime(2026, 10, 26),
      ),
    );
    repository.changes.add(null);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('New incoming text').evaluate().isNotEmpty) break;
    }
    expect(find.text('New incoming text'), findsOneWidget);
    final arrivals = tester.widgetList<CoachReplyArrival>(
      find.byType(CoachReplyArrival),
    );
    expect(arrivals.where((row) => row.animate).length, 1);
    final fade = find.byWidgetPredicate(
      (widget) =>
          widget is FadeTransition &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.endsWith(':new-incoming'),
    );
    expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(repository.sendCalls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'friend chat opens at latest and leaves an older-reading user in place',
    (tester) async {
      final recipient = '22222222-2222-4222-8222-222222222222';
      final repository = _ChatRepository(
        client,
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
      await tester.tap(find.byKey(const Key('chat-jump-to-latest')));
      await tester.pump();
      expect(historyController.offset, closeTo(readingOffset, .5));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(historyController.offset, inExclusiveRange(0, readingOffset));
      await tester.pumpAndSettle();
      expect(historyController.offset, closeTo(0, .5));
      expect(find.text('New incoming message'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'realtime refresh keeps selectable history visible while loading',
    (tester) async {
      final repository = _ChatRepository(client);
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
      expect(bilWaitingIndicators(), findsNothing);
      repository.pendingLoad!.complete([]);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a new draft typed during send is not erased by the old completion',
    (tester) async {
      final repository = _ChatRepository(client)
        ..pendingSend = Completer<void>();
      addTearDown(repository.changes.close);
      await tester.pumpWidget(_chat(repository));
      await tester.pumpAndSettle();
      final composer = find.byType(TextField);
      await tester.enterText(composer, 'First message');
      await tester.tap(find.byKey(const Key('community-chat-send')));
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
    final repository = _ChatRepository(client)..pendingSend = Completer<void>();
    addTearDown(repository.changes.close);
    await tester.pumpWidget(_chat(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test outgoing message');
    final send = find.byKey(const Key('community-chat-send'));
    await tester.tap(send);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    repository.pendingSend!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
