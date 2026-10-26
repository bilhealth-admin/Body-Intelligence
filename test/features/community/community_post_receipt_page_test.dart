import '../../support/bil_waiting_indicators.dart';
import 'dart:async';

import 'package:body_intelligence_log/features/community/activity_rewards/community_post_receipt_page.dart';
import 'package:body_intelligence_log/features/community/data/community_post_cloud_store.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/community_rewards_rpc_fixture.dart';

const _postId = '44444444-4444-4444-8444-444444444444';

CommunityPost _post(String owner, String body) => CommunityPost(
  id: _postId,
  authorId: owner,
  body: body,
  createdAt: DateTime.utc(2026, 10, 13),
);

/// Isolated lookup contract and the real Auth SDK; no server/device/RLS claim.
class _ReceiptStore
    implements CommunityPostStoreContract, CommunityPostLookupContract {
  _ReceiptStore(this.client);
  final SupabaseClient client;
  final reads = <String>[];
  final mutations = <String>[];
  bool failRead = false;
  Completer<List<CommunityPost>>? pending;

  @override
  Future<List<CommunityPost>> loadPostsByIds(List<String> postIds) async {
    expect(postIds, [_postId]);
    final owner = client.auth.currentUser!.id;
    reads.add(owner);
    if (failRead) {
      throw StateError('Synthetic receipt lookup failure');
    }
    final held = pending;
    pending = null;
    if (held != null) {
      return held.future;
    }
    return [_post(owner, 'Fresh verified receipt for $owner')];
  }

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async {
    throw StateError('A receipt must not open a generic feed');
  }

  @override
  Future<List<CommunityPost>> loadModerationQueue({int limit = 100}) async {
    throw StateError('A receipt must not open moderation');
  }

  @override
  Future<void> publishText(String body) async {
    mutations.add('publish');
    throw StateError('A receipt cannot publish');
  }

  @override
  Future<void> publishWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async {
    mutations.add('publish_image');
    throw StateError('A receipt cannot publish images');
  }

  @override
  Future<void> delete(String postId) async {
    mutations.add('delete');
    throw StateError('A receipt cannot delete');
  }
}

class _ReceiptRepository extends CommunityRepository {
  _ReceiptRepository(super.client, _ReceiptStore store)
    : super(postStore: store);
  final polls = <List<String>>[];
  @override
  Future<List<CommunityPoll>> loadCommunityPolls(List<String> postIds) async {
    polls.add(List.of(postIds));
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RewardsRpcFixture auth;
  late _ReceiptStore store;
  late _ReceiptRepository repository;
  setUp(() async {
    auth = RewardsRpcFixture();
    await auth.prepare();
    store = _ReceiptStore(auth.client);
    repository = _ReceiptRepository(auth.client, store);
  });
  tearDown(() async {
    await auth.client.dispose();
  });

  Widget app() => MaterialApp(
    home: CommunityPostReceiptPage(postId: _postId, repository: repository),
  );

  testWidgets(
    'future callback regression receipt retry reads verified post without side effects',
    (tester) async {
      store.failRead = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        find.text('This post could not be loaded for the current account.'),
        findsOneWidget,
      );
      expect(store.reads, [rewardsOwnerA]);
      store.failRead = false;
      final retry = find.text('Retry');
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(
        find.text('Fresh verified receipt for $rewardsOwnerA'),
        findsOneWidget,
      );
      expect(find.text('Approved'), findsOneWidget);
      expect(
        find.text('This post could not be loaded for the current account.'),
        findsNothing,
      );
      expect(bilWaitingIndicators(), findsNothing);
      expect(store.reads, [rewardsOwnerA, rewardsOwnerA]);
      expect(store.mutations, isEmpty);
      expect(auth.requests, isEmpty);
      expect(repository.polls, [
        [_postId],
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'future callback regression receipt pending lookup retires on queued A B A',
    (tester) async {
      final pending = Completer<List<CommunityPost>>();
      store.pending = pending;
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.byType(BilFeatureWelcomeStatus), findsOneWidget);
      await auth.roundTrip();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      pending.complete([_post(rewardsOwnerA, 'Stale original A receipt')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.text('Fresh verified receipt for $rewardsOwnerA'),
        findsOneWidget,
      );
      expect(find.text('Stale original A receipt'), findsNothing);
      expect(
        find.text('Fresh verified receipt for $rewardsOwnerB'),
        findsNothing,
      );
      expect(bilWaitingIndicators(), findsNothing);
      expect(store.reads.length, greaterThanOrEqualTo(3));
      expect(store.mutations, isEmpty);
      expect(auth.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
