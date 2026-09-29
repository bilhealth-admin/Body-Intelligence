import 'dart:async';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _VisibleRepository extends CommunityRepository {
  _VisibleRepository()
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final acknowledged = <String>{};
  final changes = StreamController<void>.broadcast();
  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';
  @override
  Stream<void> watchConversationChanges(String other) => changes.stream;
  @override
  Future<List<CommunityMessage>> loadMessages(String other) async => [
    for (var i = 0; i < 60; i++)
      CommunityMessage(
        id: 'message-$i',
        senderId: other,
        recipientId: currentUserId,
        body: 'Message $i',
        createdAt: DateTime(2026, 9, 29, 10, i),
      ),
  ];
  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async {
    acknowledged.addAll(ids);
    return ids.length;
  }

  @override
  Future<void> markConversationRead(String other) =>
      throw StateError('Unbounded conversation read must not be called');
}

void main() {
  testWidgets(
    'only visible messages are acknowledged, not cached or offscreen history',
    (tester) async {
      final repository = _VisibleRepository();
      addTearDown(repository.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityChatPage(
            userId: '22222222-2222-4222-8222-222222222222',
            displayName: 'Fixture',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.acknowledged, contains('message-59'));
      expect(repository.acknowledged, isNot(contains('message-0')));
      expect(repository.acknowledged.length, lessThan(60));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('backgrounded chat does not mark new messages read', (
    tester,
  ) async {
    final repository = _VisibleRepository();
    addTearDown(repository.changes.close);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityChatPage(
          userId: '22222222-2222-4222-8222-222222222222',
          displayName: 'Fixture',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.acknowledged, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.acknowledged, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
