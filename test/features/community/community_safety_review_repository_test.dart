import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/presentation/community_post_moderation_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_blocked_members_sheet.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/community_rewards_rpc_fixture.dart';

void main() {
  const reportId = '33333333-3333-4333-8333-333333333333';
  const targetId = '44444444-4444-4444-8444-444444444444';
  const operationId = '55555555-5555-4555-8555-555555555555';
  late SupabaseClient client;
  late CommunityRepository repository;
  late List<({String method, String path, Map<String, dynamic> body})> calls;
  var closed = false,
      blocked = true,
      missing = false,
      forged = false,
      failedReadback = false;
  var changedRevision = false;
  Completer<void>? entered, release;
  Map<String, dynamic> snapshot() => {
    'contract_version': 1,
    'report_id': reportId,
    'source': 'comment',
    'target_id': forged ? rewardsOwnerA : targetId,
    'target_kind': 'reply',
    'reason': 'Misleading content',
    'status': 'open',
    'available': true,
    'can_remove': true,
    'body': changedRevision
        ? 'Edited reported reply text'
        : 'Reported reply text',
    'parent_body': 'Parent context',
    'post': null,
    'revision': (changedRevision ? 'b' : 'a') * 64,
  };
  Map<String, dynamic> receipt() => {
    'contract_version': 1,
    'report_id': reportId,
    'source': 'comment',
    'target_id': targetId,
    'reviewed_revision': (changedRevision ? 'b' : 'a') * 64,
    'operation_id': operationId,
    'status': 'closed',
    'content_removed': true,
    'duplicate': false,
    'receipt_state': 'executed',
  };
  setUp(() async {
    calls = [];
    closed = false;
    blocked = true;
    missing = forged = failedReadback = false;
    entered = release = null;
    changedRevision = false;
    client = SupabaseClient(
      'https://community-safety.invalid',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          final name = request.url.pathSegments.last;
          final decoded = request.body.isEmpty
              ? null
              : jsonDecode(request.body);
          final body = decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
          calls.add((method: request.method, path: name, body: body));
          Object? data;
          switch (name) {
            case 'bil_is_community_moderator':
              data = true;
            case 'bil_list_pending_community_posts':
            case 'bil_list_hidden_community_posts':
            case 'bil_list_open_community_reports':
            case 'bil_community_reward_review_queue_v2':
            case 'bil_list_ai_coach_safety_reports_v1':
              data = [];
            case 'bil_social_comment_reports_v2':
              data = closed
                  ? []
                  : [
                      {
                        'report_id': reportId,
                        'comment_id': targetId,
                        'body': 'Reported reply text',
                        'reason': 'Misleading content',
                        'created_at': '2026-10-13T00:00:00Z',
                      },
                    ];
            case 'bil_community_report_content_v1':
              entered?.complete();
              await release?.future;
              if (missing) {
                return http.Response(
                  jsonEncode({
                    'code': 'PGRST202',
                    'message': 'Function unavailable',
                  }),
                  404,
                  request: request,
                  headers: {'content-type': 'application/json'},
                );
              }
              data = snapshot();
            case 'bil_decide_community_report_v1':
              if (body['p_expected_revision'] != snapshot()['revision']) {
                return http.Response(
                  jsonEncode({
                    'code': '40001',
                    'message': 'community_report_content_changed',
                  }),
                  409,
                  request: request,
                  headers: {'content-type': 'application/json'},
                );
              }
              closed = true;
              data = receipt()..['operation_id'] = body['p_operation_id'];
            case 'bil_get_community_report_decision_v1':
              data = receipt()..['operation_id'] = body['p_operation_id'];
              if (failedReadback) (data as Map)['status'] = 'open';
            case 'bil_my_blocked_members_v1':
              data = blocked
                  ? [
                      {
                        'blocked_id': targetId,
                        'display_name': 'Synthetic member',
                        'created_at': '2026-10-13T00:00:00Z',
                      },
                    ]
                  : [];
            case 'bil_blocks':
              if (request.method == 'DELETE') {
                blocked = false;
                data = null;
              } else {
                data = blocked
                    ? [
                        {'blocked_id': targetId},
                      ]
                    : [];
              }
            default:
              throw StateError('Unexpected request $name');
          }
          return http.Response(
            data == null ? '' : jsonEncode(data),
            request.method == 'DELETE' ? 204 : 200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    repository = CommunityRepository(client);
    await client.auth.setInitialSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
    );
  });
  tearDown(() async {
    if (release != null && !release!.isCompleted) release!.complete();
    await client.dispose();
  });
  Future<CommunityReportReview> read() => repository.loadReportedContent(
    reportId: reportId,
    source: 'comment',
    targetId: targetId,
  );
  Widget app(Widget page, {String locale = 'en', double scale = 1}) =>
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      );

  test(
    'published comment report RPC is parsed and reply context is reviewed before mutation',
    () async {
      final reports = await repository.loadOpenCommentReports();
      expect(reports.single.commentId, targetId);
      final review = await read();
      expect(review.body, 'Reported reply text');
      expect(review.parentBody, 'Parent context');
      expect(
        calls.any(
          (c) => c.path.contains('decide') || c.path.contains('resolve'),
        ),
        false,
      );
      await repository.decideReportedContent(
        review: review,
        remove: true,
        operationId: operationId,
      );
      expect(
        calls
            .where((c) => c.path == 'bil_decide_community_report_v1')
            .single
            .body,
        {
          'p_report_id': reportId,
          'p_source': 'comment',
          'p_expected_revision': 'a' * 64,
          'p_remove': true,
          'p_operation_id': operationId,
        },
      );
      expect(
        calls.where((c) => c.path == 'bil_get_community_report_decision_v1'),
        hasLength(1),
      );
    },
  );
  test(
    'unknown report contract does not fall back to a blind legacy removal',
    () async {
      missing = true;
      await expectLater(read(), throwsA(isA<PostgrestException>()));
      expect(
        calls.any(
          (c) => c.path.contains('decide') || c.path.contains('resolve'),
        ),
        false,
      );
    },
  );
  test('forged target and unverified decision readback are rejected', () async {
    forged = true;
    await expectLater(read(), throwsFormatException);
    forged = false;
    final review = await read();
    failedReadback = true;
    await expectLater(
      repository.decideReportedContent(
        review: review,
        remove: true,
        operationId: operationId,
      ),
      throwsFormatException,
    );
  });
  test(
    'A-B-A during reported-content lookup retires the original operation',
    () async {
      entered = Completer<void>();
      release = Completer<void>();
      final pending = read();
      final assertion = expectLater(
        pending,
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      await entered!.future;
      await client.auth.setInitialSession(
        jsonEncode(RewardsRpcFixture.session(rewardsOwnerB)),
      );
      await client.auth.setInitialSession(
        jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
      );
      release!.complete();
      await assertion;
      expect(calls.any((c) => c.path.contains('decide')), false);
    },
  );
  test(
    'own-block DELETE uses both identities and verifies absence without changing the opposite block',
    () async {
      expect((await repository.loadBlockedMembers()).single.id, targetId);
      await repository.unblockMember(targetId);
      expect(
        calls.where((c) => c.path == 'bil_blocks' && c.method == 'DELETE'),
        hasLength(1),
      );
      expect(
        calls.where((c) => c.path == 'bil_blocks' && c.method == 'GET'),
        hasLength(1),
      );
      expect(blocked, false);
    },
  );
  for (final locale in ['en', 'ar']) {
    testWidgets(
      'reply is visible before a real remove tap and verified refresh in $locale',
      (tester) async {
        await tester.pumpWidget(
          app(
            CommunityPostModerationPage(repository: repository),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('community-report-remove-confirm')),
          findsNothing,
        );
        final open = find.byKey(
          const Key('community-comment-report-view-$reportId'),
        );
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('community-reported-content-body')),
          findsOneWidget,
        );
        expect(find.text('Parent context'), findsOneWidget);
        expect(
          calls.any((c) => c.path == 'bil_decide_community_report_v1'),
          false,
        );
        final remove = find.byKey(const Key('community-report-remove-confirm'));
        expect(remove.hitTestable(), findsOneWidget);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(
          calls.where((c) => c.path == 'bil_get_community_report_decision_v1'),
          hasLength(1),
        );
        expect(
          find.byKey(const Key('community-comment-report-$reportId')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'failed receipt readback retries the same confirmed operation without another review',
    (tester) async {
      await tester.pumpWidget(
        app(CommunityPostModerationPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      final open = find.byKey(
        const Key('community-comment-report-view-$reportId'),
      );
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      failedReadback = true;
      await tester.tap(
        find.byKey(const Key('community-report-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        calls.where((c) => c.path == 'bil_decide_community_report_v1'),
        hasLength(1),
      );
      failedReadback = false;
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      final decisions = calls
          .where((c) => c.path == 'bil_decide_community_report_v1')
          .toList();
      expect(decisions, hasLength(2));
      expect(
        decisions.first.body['p_operation_id'],
        decisions.last.body['p_operation_id'],
      );
      expect(
        calls.where((c) => c.path == 'bil_community_report_content_v1'),
        hasLength(1),
      );
      expect(
        calls.where((c) => c.path == 'bil_get_community_report_decision_v1'),
        hasLength(2),
      );
      expect(
        find.byKey(const Key('community-comment-report-$reportId')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'proven stale report rejection requires a fresh review before retry',
    (tester) async {
      await tester.pumpWidget(
        app(CommunityPostModerationPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      final open = find.byKey(
        const Key('community-comment-report-view-$reportId'),
      );
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('Reported reply text'), findsWidgets);
      changedRevision = true;
      await tester.tap(
        find.byKey(const Key('community-report-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(closed, false);
      expect(
        find.text(
          'The reported content changed. Review it again before deciding.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('Edited reported reply text'), findsOneWidget);
      expect(
        calls.where((c) => c.path == 'bil_community_report_content_v1'),
        hasLength(2),
      );
      expect(
        calls.where((c) => c.path == 'bil_decide_community_report_v1'),
        hasLength(1),
      );
      await tester.tap(
        find.byKey(const Key('community-report-remove-confirm')),
      );
      await tester.pumpAndSettle();
      final decisions = calls
          .where((c) => c.path == 'bil_decide_community_report_v1')
          .toList();
      expect(decisions, hasLength(2));
      expect(decisions.first.body['p_expected_revision'], 'a' * 64);
      expect(decisions.last.body['p_expected_revision'], 'b' * 64);
      expect(
        decisions.first.body['p_operation_id'],
        isNot(decisions.last.body['p_operation_id']),
      );
      expect(closed, true);
      expect(
        find.byKey(const Key('community-comment-report-$reportId')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('account switch clears open report text and decision controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(CommunityPostModerationPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    final open = find.byKey(
      const Key('community-comment-report-view-$reportId'),
    );
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-reported-content-body')),
      findsOneWidget,
    );
    await client.auth.setInitialSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerB)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-reported-content-body')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('community-report-remove-confirm')),
      findsNothing,
    );
    expect(calls.any((c) => c.path == 'bil_decide_community_report_v1'), false);
  });
  testWidgets('moderator A B A explicitly refreshes a fresh authorized visit', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(CommunityPostModerationPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-comment-report-$reportId')),
      findsOneWidget,
    );
    await client.auth.setInitialSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerB)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-comment-report-$reportId')),
      findsNothing,
    );
    await client.auth.setInitialSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-comment-report-$reportId')),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-comment-report-$reportId')),
      findsOneWidget,
    );
    expect(
      calls.where((c) => c.path == 'bil_is_community_moderator').length,
      greaterThanOrEqualTo(2),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'future callback regression unblock success remains honest at narrow Arabic 2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          Scaffold(body: CommunityBlockedMembersSheet(repository: repository)),
          locale: 'ar',
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('community-unblock-$targetId'));
      await tester.ensureVisible(action);
      expect(action.hitTestable(), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(calls.any((c) => c.method == 'DELETE'), false);
      await tester.tap(action);
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('community-unblock-confirm'));
      expect(confirm.hitTestable(), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(blocked, false);
      expect(
        find.byKey(const Key('community-unblock-$targetId')),
        findsNothing,
      );
      expect(find.text('تم إلغاء الحظر.'), findsOneWidget);
      expect(find.text('تعذر تأكيد إلغاء الحظر. حاول مجددًا.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(calls.where((call) => call.method == 'DELETE'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
