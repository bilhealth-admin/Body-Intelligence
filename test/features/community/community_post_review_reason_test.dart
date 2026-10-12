import 'dart:async';
import 'dart:convert';
import 'support/community_rewards_rpc_fixture.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_post_review_reason.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ownedPost = CommunityPost(
  id: 'post-test',
  authorId: rewardsOwnerA,
  body: 'TEST منشور يحتاج توضيحًا',
  createdAt: DateTime.utc(2026, 10, 11),
  moderationStatus: CommunityPostModerationStatus.rejected,
);

class _Repository extends CommunityRepository {
  _Repository(super.client);
  Completer<String?> response = Completer<String?>();
  int calls = 0;
  @override
  String get currentUserId => rewardsOwnerA;
  @override
  Future<String?> loadMyPostReviewReason(CommunityPost post) {
    calls++;
    return response.future;
  }
}

void main() {
  late SupabaseClient client;
  late _Repository repository;
  late ValueNotifier<bool> scope;
  setUp(() async {
    client = SupabaseClient(
      'https://reason.invalid',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = _Repository(client);
    scope = ValueNotifier(true);
    await client.auth.recoverSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
    );
  });
  tearDown(() async {
    scope.dispose();
    await client.dispose();
  });
  Widget view() => MaterialApp(
    home: Scaffold(
      body: CommunityPostReviewReason(
        repository: repository,
        post: ownedPost,
        ownerChanges: scope,
        ownerIsCurrent: () => scope.value,
      ),
    ),
  );
  testWidgets(
    'confirmed author explanation is visible with its real reading direction',
    (tester) async {
      repository.response = Completer<String?>();
      await tester.pumpWidget(view());
      expect(repository.calls, 1);
      expect(find.text('الرجاء توضيح مصدر الصورة'), findsNothing);
      repository.response.complete('الرجاء توضيح مصدر الصورة');
      await tester.pumpAndSettle();
      final text = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == 'الرجاء توضيح مصدر الصورة',
        ),
      );
      expect(text.textDirection, TextDirection.rtl);
      expect(repository.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'ABA ownership signals hide an explanation arriving after the visit retired',
    (tester) async {
      repository.response = Completer<String?>();
      await tester.pumpWidget(view());
      scope.value = false;
      scope.value = true;
      repository.response.complete('OLD OWNER EXPLANATION');
      await tester.pumpAndSettle();
      expect(find.text('OLD OWNER EXPLANATION'), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
      expect(repository.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed explanation stays unavailable and explicit retry starts a new read',
    (tester) async {
      repository.response = Completer<String?>();
      await tester.pumpWidget(view());
      repository.response.completeError(StateError('Synthetic read failure'));
      await tester.pumpAndSettle();
      repository.response = Completer<String?>();
      await tester.tap(find.byKey(const Key('community-review-reason-retry')));
      await tester.pump();
      repository.response.complete('Confirmed after retry');
      await tester.pumpAndSettle();
      expect(find.text('Confirmed after retry'), findsOneWidget);
      expect(repository.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
