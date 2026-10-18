import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_referral.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/presentation/community_ai_reward_notice.dart';
import 'package:body_intelligence_log/features/community/presentation/community_bil_code_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_gold_balance_action.dart';
import 'package:body_intelligence_log/features/community/presentation/bil_gold_coin.dart';
import 'package:body_intelligence_log/features/community/presentation/community_invite_landing_page.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
const _member = '33333333-3333-4333-8333-333333333333';
const _token = '0123456789abcdef0123456789abcdef0123456789abcdef';
const _codeA = '11111111111111111111111111111111';
const _codeB = '22222222222222222222222222222222';
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

class _Accounts {
  String signingOwner = _a;
  final sessions = <String, String>{};
  late final client = SupabaseClient(
    'https://community-account-fixture.invalid',
    'synthetic-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: CommunityOwnerHttpClient(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/logout') {
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path != '/auth/v1/token') {
          throw StateError('Unplanned external request: ${request.url.path}');
        }
        final payload = base64Url
            .encode(
              utf8.encode(jsonEncode({'sub': signingOwner, 'exp': 4102444800})),
            )
            .replaceAll('=', '');
        return http.Response(
          jsonEncode({
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.synthetic',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': signingOwner,
              'email': 'qa@example.invalid',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-13T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    ),
  );

  Future<void> initialize() async {
    await signIn(_a);
    await signIn(_b);
    await recover(_a);
  }

  Future<void> signIn(String owner) async {
    signingOwner = owner;
    await client.auth.signInWithPassword(
      email: 'qa@example.invalid',
      password: 'synthetic-password',
    );
    sessions[owner] = jsonEncode(client.auth.currentSession!.toJson());
  }

  Future<void> recover(String owner) async {
    await client.auth.recoverSession(sessions[owner]!);
  }

  Future<void> aba() async {
    final second = client.auth.recoverSession(sessions[_b]!);
    final first = client.auth.recoverSession(sessions[_a]!);
    await Future.wait([second, first]);
  }
}

class _Repository extends CommunityRepository {
  _Repository(super.client);
  final rotations = <String>[];
  final accepts = <String>[];
  final requests = <String>[];
  final balances = <String>[];
  Completer<CommunityGoldBalance>? pendingBalance;
  Completer<CommunityPublicCode>? pendingCode;
  Completer<CommunityPublicCode>? pendingRotation;
  Completer<CommunityInviteAcceptance>? pendingAccept;
  bool failAccept = false;
  bool failPreview = false;
  int previewReads = 0;
  bool failBalance = false;
  bool missingMember = false;

  CommunityPublicCode codeFor(String owner) {
    final code = owner == _a ? _codeA : _codeB;
    return CommunityPublicCode.fromJson({
      'code': code,
      'uri': 'bil://community/member/$code',
      'handle': owner == _a ? 'member_a' : 'member_b',
    });
  }

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    final pending = pendingCode;
    return pending == null ? codeFor(currentUserId) : pending.future;
  }

  @override
  Future<CommunityPublicCode> rotatePublicCode() async {
    rotations.add(currentUserId);
    return pendingRotation?.future ?? codeFor(currentUserId);
  }

  @override
  Future<CommunityGoldBalance> loadGoldBalance() async {
    final owner = currentUserId;
    balances.add(owner);
    if (failBalance) throw StateError('synthetic balance read failure');
    final pending = pendingBalance;
    return pending == null
        ? CommunityGoldBalance(balance: owner == _a ? 7 : 3)
        : pending.future;
  }

  @override
  Future<CommunityResolvedMember?> resolvePublicCode(String code) async =>
      missingMember
      ? null
      : const CommunityResolvedMember(
          userId: _member,
          handle: 'other_member',
          displayName: 'Other Member',
          relationship: CommunityRelationshipStatus.none,
        );
  @override
  Future<CommunityFriendRequestStatus> requestFriend(String addresseeId) async {
    requests.add(currentUserId);
    return CommunityFriendRequestStatus.pending;
  }

  @override
  Future<CommunityInvitePreview> previewCommunityInvite(String token) async {
    previewReads++;
    if (failPreview) {
      throw StateError('synthetic invitation preview failure');
    }
    return CommunityInvitePreview(
      status: CommunityInvitePreviewStatus.active,
      inviterId: _member,
      displayName: 'Other Member',
      handle: 'other_member',
      expiresAt: DateTime.utc(2030),
    );
  }

  @override
  Future<CommunityInviteAcceptance> acceptCommunityInvite(String token) async {
    accepts.add(currentUserId);
    if (failAccept) throw StateError('synthetic storage failure');
    return pendingAccept?.future ?? Future.value(_acceptance());
  }
}

/// Synthetic server commits rotation; its response is lost before the UI sees it.
class _LostRotationRepository extends _Repository {
  _LostRotationRepository(super.client);
  final readback = Completer<CommunityPublicCode>();
  int codeReads = 0;
  CommunityPublicCode? committedCode;

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    codeReads++;
    if (committedCode != null && currentUserId == _a) {
      return readback.future;
    }
    return codeFor(currentUserId);
  }

  @override
  Future<CommunityPublicCode> rotatePublicCode() async {
    rotations.add(currentUserId);
    const nextCode = 'dddddddddddddddddddddddddddddddd';
    committedCode = CommunityPublicCode.fromJson({
      'code': nextCode,
      'uri': 'bil://community/member/$nextCode',
      'handle': 'current_rotated_a',
    });
    throw TimeoutException('Synthetic server response lost after commit');
  }
}

CommunityInviteAcceptance _acceptance() => const CommunityInviteAcceptance(
  status: CommunityInviteAcceptStatus.attributed,
  attributionId: '44444444-4444-4444-8444-444444444444',
  inviterId: _member,
  friendshipId: '55555555-5555-4555-8555-555555555555',
  relationship: 'accepted',
  displayName: 'Other Member',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Accounts accounts;
  late _Repository repository;
  setUp(() async {
    accounts = _Accounts();
    await accounts.initialize();
    repository = _Repository(accounts.client);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
    await accounts.client.dispose();
  });

  testWidgets(
    'Coach Gold clears the former owner and accepts a fresh account balance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityGoldBalanceAction(
              compact: true,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      await accounts.recover(_b);
      await tester.pumpAndSettle();
      expect(find.text('7'), findsNothing);
      expect(find.text('3'), findsOneWidget);
      await accounts.client.auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('3'), findsNothing);
      await accounts.recover(_a);
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-account failed Gold refresh retains its verified balance and exposes retry',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: CommunityGoldBalanceAction(repository: repository),
            ),
          ),
          GoRoute(
            path: '/community/rewards',
            builder: (_, _) => const Scaffold(body: Text('Wallet')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-coach-bil-gold')));
      await tester.pumpAndSettle();
      repository.failBalance = true;
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      expect(find.byKey(const Key('ai-coach-gold-retry')), findsOneWidget);
      repository.failBalance = false;
      await tester.tap(find.byKey(const Key('ai-coach-gold-retry')));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      expect(find.byKey(const Key('ai-coach-gold-retry')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Coach Gold rejects a late original A result after delivered A B A',
    (tester) async {
      final old = Completer<CommunityGoldBalance>();
      repository.pendingBalance = old;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityGoldBalanceAction(repository: repository),
          ),
        ),
      );
      await tester.pump();
      repository.pendingBalance = null;
      await accounts.aba();
      await tester.pumpAndSettle();
      old.complete(const CommunityGoldBalance(balance: 777));
      await tester.pumpAndSettle();
      expect(find.text('777'), findsNothing);
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Coach Earn is discoverable and opens only the existing explained composer route',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: CommunityGoldBalanceAction(
                compact: true,
                repository: repository,
              ),
            ),
          ),
          GoRoute(
            path: '/community/compose',
            builder: (_, state) => Scaffold(
              body: Column(
                children: [
                  Text(
                    state.uri.toString(),
                    key: const Key('fixture-earn-route'),
                  ),
                  Text(state.uri.queryParameters['origin'] ?? 'missing'),
                  const CommunityAiRewardNotice(),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/community/rewards',
            builder: (_, _) => const Scaffold(body: Text('Wallet')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('ai-coach-earn-post')),
          matching: find.byType(BilGoldCoin),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('ai-coach-earn-post')),
          matching: find.text('Earn'),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('ai-coach-earn-post')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('fixture-earn-route'))).data,
        '/community/compose?origin=earn',
      );
      expect(
        find.byKey(const Key('community-ai-reward-notice')),
        findsOneWidget,
      );
      expect(find.textContaining('+5 AI tokens only when'), findsOneWidget);
      expect(repository.accepts, isEmpty);
      expect(repository.requests, isEmpty);
      expect(repository.rotations, isEmpty);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai-coach-bil-gold')));
      await tester.pumpAndSettle();
      expect(find.text('Wallet'), findsOneWidget);
    },
  );

  testWidgets(
    'QR and real native share fixture carry only the current opaque public code',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            calls.add(call);
            return 'synthetic-share-target';
          });
      await tester.pumpWidget(
        MaterialApp(home: CommunityBilCodePage(repository: repository)),
      );
      await tester.pumpAndSettle();
      final qr = find.byKey(const Key('community-bil-code-qr'));
      final paint = tester.widget<CustomPaint>(
        find.descendant(of: qr, matching: find.byType(CustomPaint)),
      );
      final dynamic painter = paint.painter;
      expect(
        CommunityCodeScannerPage.codeFromPayload(painter.data as String),
        _codeA,
      );
      await accounts.recover(_b);
      await tester.pumpAndSettle();
      expect(find.text('@member_a'), findsNothing);
      expect(find.text('@member_b'), findsOneWidget);
      final share = find.byKey(const Key('community-bil-code-share'));
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      final args = calls.single.arguments as Map;
      expect(
        args['text'],
        contains('https://www.bilhealth.com/download?member=$_codeB'),
      );
      expect(args['text'], isNot(contains(_codeA)));
      expect(args['text'], isNot(contains('synthetic-refresh')));
      expect(args['originWidth'], greaterThan(0));
      expect(args['originHeight'], greaterThan(0));
      expect(repository.requests, isEmpty);
      expect(repository.rotations, isEmpty);
    },
  );

  testWidgets(
    'late original A QR cannot replace a fresh code after delivered A B A',
    (tester) async {
      final old = Completer<CommunityPublicCode>();
      repository.pendingCode = old;
      await tester.pumpWidget(
        MaterialApp(home: CommunityBilCodePage(repository: repository)),
      );
      await tester.pump();
      repository.pendingCode = null;
      await accounts.aba();
      await tester.pumpAndSettle();
      old.complete(
        CommunityPublicCode.fromJson({
          'code': 'ffffffffffffffffffffffffffffffff',
          'uri': 'bil://community/member/ffffffffffffffffffffffffffffffff',
          'handle': 'stale_a',
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('@stale_a'), findsNothing);
      expect(find.text('@member_a'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'member-code Add callback cannot send from a former displayed account',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityMemberCodePage(code: _codeA, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.byKey(const Key('community-code-add-friend'));
      final oldAction = tester.widget<FilledButton>(add).onPressed!;
      await accounts.recover(_b);
      oldAction();
      await tester.pumpAndSettle();
      expect(repository.requests, isEmpty);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(repository.requests, [_b]);
      expect(find.text('Request pending'), findsOneWidget);
    },
  );

  testWidgets(
    'future callback regression QR rotation confirms updated code without false failure',
    (tester) async {
      final pending = Completer<CommunityPublicCode>();
      repository.pendingRotation = pending;
      final shares = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            shares.add(call);
            return 'synthetic-share-target';
          });
      await tester.pumpWidget(
        MaterialApp(home: CommunityBilCodePage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('@member_a'), findsOneWidget);
      final rotate = find.byKey(const Key('community-bil-code-rotate'));
      await tester.ensureVisible(rotate);
      expect(rotate.hitTestable(), findsOneWidget);
      await tester.tap(rotate);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace code'));
      await tester.pump();
      expect(repository.rotations, [_a]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      const nextCode = 'cccccccccccccccccccccccccccccccc';
      pending.complete(
        CommunityPublicCode.fromJson({
          'code': nextCode,
          'uri': 'bil://community/member/$nextCode',
          'handle': 'rotated_member',
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('@rotated_member'), findsOneWidget);
      expect(find.text('@member_a'), findsNothing);
      expect(
        find.text('Your BIL Code is unavailable right now. Try again.'),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<OutlinedButton>(rotate).onPressed, isNotNull);
      final share = find.byKey(const Key('community-bil-code-share'));
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(shares, hasLength(1));
      expect((shares.single.arguments as Map)['text'], contains(nextCode));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rotation timeout hides invalidated code until current readback',
    (tester) async {
      final lost = _LostRotationRepository(accounts.client);
      final shares = <MethodCall>[];
      addTearDown(() {
        if (!lost.readback.isCompleted) {
          lost.readback.complete(lost.committedCode ?? lost.codeFor(_a));
        }
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            shares.add(call);
            return 'synthetic-share-target';
          });
      await tester.pumpWidget(
        MaterialApp(home: CommunityBilCodePage(repository: lost)),
      );
      await tester.pumpAndSettle();
      expect(find.text('@member_a'), findsOneWidget);
      final share = find.byKey(const Key('community-bil-code-share'));
      final oldShare = tester.widget<FilledButton>(share).onPressed!;
      final rotate = find.byKey(const Key('community-bil-code-rotate'));
      await tester.ensureVisible(rotate);
      await tester.tap(rotate);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(lost.rotations, [_a]);
      expect(lost.committedCode, isNotNull);
      expect(find.text('@member_a'), findsNothing);
      expect(find.byKey(const Key('community-bil-code-qr')), findsNothing);
      expect(share, findsNothing);
      expect(lost.codeReads, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // A tap queued by the previous frame must not share the invalidated code.
      oldShare();
      await tester.pump();
      expect(shares, isEmpty);
      expect(lost.rotations, [_a]);
      lost.readback.complete(lost.committedCode!);
      await tester.pumpAndSettle();
      expect(find.text('@current_rotated_a'), findsOneWidget);
      expect(find.text('@member_a'), findsNothing);
      expect(find.byKey(const Key('community-bil-code-qr')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Your BIL Code is unavailable right now. Try again.'),
        findsNothing,
      );
      expect(lost.rotations, [_a]);
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(shares, hasLength(1));
      expect(
        (shares.single.arguments as Map)['text'],
        contains(lost.committedCode!.code),
      );
      expect((shares.single.arguments as Map)['text'], isNot(contains(_codeA)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'future callback regression invite retry refreshes preview without acceptance',
    (tester) async {
      repository.failPreview = true;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityInviteLandingPage(
            token: _token,
            repository: repository,
            client: accounts.client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invitation unavailable'), findsOneWidget);
      expect(repository.previewReads, 1);
      expect(repository.accepts, isEmpty);
      repository.failPreview = false;
      final retry = find.text('Retry');
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Other Member invited you to join BIL'), findsOneWidget);
      expect(find.text('@other_member'), findsOneWidget);
      final previewBuilder = tester
          .widget<FutureBuilder<CommunityInvitePreview>>(
            find.byType(FutureBuilder<CommunityInvitePreview>),
          );
      final verifiedPreview = await previewBuilder.future!;
      expect(verifiedPreview.status, CommunityInvitePreviewStatus.active);
      expect(verifiedPreview.inviterId, _member);
      expect(verifiedPreview.displayName, 'Other Member');
      expect(verifiedPreview.handle, 'other_member');
      expect(find.byKey(const Key('community-accept-invite')), findsOneWidget);
      expect(
        find.byKey(const Key('community-open-inviter-profile')),
        findsNothing,
      );
      expect(find.text('Invitation unavailable'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repository.previewReads, 2);
      expect(repository.accepts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QR share remains single flight and platform failure permits retry',
    (tester) async {
      final first = Completer<String>();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            calls.add(call);
            return calls.length == 1 ? first.future : 'synthetic-share-target';
          });
      await tester.pumpWidget(
        MaterialApp(home: CommunityBilCodePage(repository: repository)),
      );
      await tester.pumpAndSettle();
      final share = find.byKey(const Key('community-bil-code-share'));
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.tap(share);
      await tester.pump();
      expect(calls, hasLength(1));
      first.completeError(PlatformException(code: 'unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your BIL Code is unavailable right now. Try again.'),
        findsOneWidget,
      );
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QR rotation confirmation cannot mutate B after its A owner changes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CommunityBilCodePage(repository: repository)),
      );
      await tester.pumpAndSettle();
      final rotate = find.byKey(const Key('community-bil-code-rotate'));
      await tester.ensureVisible(rotate);
      await tester.tap(rotate);
      await tester.pumpAndSettle();
      await accounts.recover(_b);
      await tester.pumpAndSettle();
      expect(
        find.text('Your account changed. Return to Community to continue.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Replace code'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(repository.rotations, isEmpty);
      expect(find.text('@member_b'), findsOneWidget);
    },
  );

  for (final returnToA in [false, true]) {
    testWidgets(
      'QR submitted rotation retires its spinner on ${returnToA ? 'A B A' : 'A B'}',
      (tester) async {
        final old = Completer<CommunityPublicCode>();
        repository.pendingRotation = old;
        await tester.pumpWidget(
          MaterialApp(home: CommunityBilCodePage(repository: repository)),
        );
        await tester.pumpAndSettle();
        final rotate = find.byKey(const Key('community-bil-code-rotate'));
        await tester.ensureVisible(rotate);
        await tester.tap(rotate);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Replace code'));
        await tester.pump();
        expect(repository.rotations, [_a]);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await accounts.recover(_b);
        if (returnToA) await accounts.recover(_a);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text(returnToA ? '@member_a' : '@member_b'),
          findsOneWidget,
        );
        expect(tester.widget<OutlinedButton>(rotate).onPressed, isNotNull);
        old.complete(repository.codeFor(_a));
        await tester.pumpAndSettle();
        expect(
          find.text(returnToA ? '@member_a' : '@member_b'),
          findsOneWidget,
        );
        expect(repository.rotations, [_a]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'QR displayed A share callback is rejected before the B frame rebuilds',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            calls.add(call);
            return '';
          });
      await tester.pumpWidget(
        MaterialApp(home: CommunityBilCodePage(repository: repository)),
      );
      await tester.pumpAndSettle();
      final share = tester
          .widget<FilledButton>(
            find.byKey(const Key('community-bil-code-share')),
          )
          .onPressed!;
      await accounts.recover(_b);
      share();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('@member_b'), findsOneWidget);
    },
  );

  testWidgets(
    'invitation late A acceptance is discarded after delivered A B A',
    (tester) async {
      final pending = Completer<CommunityInviteAcceptance>();
      repository.pendingAccept = pending;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityInviteLandingPage(
            token: _token,
            repository: repository,
            client: accounts.client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-accept-invite')));
      await tester.pump();
      expect(repository.accepts, [_a]);
      await accounts.aba();
      await tester.pumpAndSettle();
      pending.complete(_acceptance());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-open-inviter-profile')),
        findsNothing,
      );
      expect(find.byKey(const Key('community-accept-invite')), findsOneWidget);
      expect(repository.accepts, [_a]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invitation repeated taps send one acceptance and failure retains Retry action',
    (tester) async {
      final failed = Completer<CommunityInviteAcceptance>();
      repository.pendingAccept = failed;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityInviteLandingPage(
            token: _token,
            repository: repository,
            client: accounts.client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final accept = find.byKey(const Key('community-accept-invite'));
      await tester.tap(accept);
      await tester.tap(accept);
      await tester.pump();
      expect(repository.accepts, [_a]);
      failed.completeError(StateError('synthetic storage failure'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not accept this invitation safely. Try again.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-open-inviter-profile')),
        findsNothing,
      );
      repository.pendingAccept = null;
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(repository.accepts, [_a, _a]);
      expect(
        find.byKey(const Key('community-open-inviter-profile')),
        findsOneWidget,
      );
      await accounts.recover(_b);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('community-open-inviter-profile')),
        findsNothing,
      );
      expect(find.byKey(const Key('community-accept-invite')), findsOneWidget);
    },
  );

  testWidgets(
    'an unavailable opaque member code reveals no identity and sends no request',
    (tester) async {
      repository.missingMember = true;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityMemberCodePage(code: _codeA, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Other Member'), findsNothing);
      expect(find.byKey(const Key('community-code-add-friend')), findsNothing);
      expect(repository.requests, isEmpty);
      expect(find.textContaining('available'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'QR and Earn remain reachable at 320 and text 2x $language dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Widget app(Widget child) => MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
            ),
            builder: (context, body) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: body!,
            ),
            home: child,
          );
          await tester.pumpWidget(
            app(
              Scaffold(
                body: CommunityGoldBalanceAction(
                  compact: true,
                  repository: repository,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final earn = find.byKey(const Key('ai-coach-earn-post'));
          expect(earn.hitTestable(), findsOneWidget);
          final coin = find.descendant(
            of: earn,
            matching: find.byType(BilGoldCoin),
          );
          expect(coin, findsOneWidget);
          expect(
            find.descendant(of: earn, matching: find.byType(Text)),
            findsNothing,
          );
          expect(tester.getSize(earn).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            app(
              Scaffold(
                body: CommunityGoldBalanceAction(
                  compact: true,
                  showEarn: false,
                  repository: repository,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(earn, findsNothing);
          expect(
            find.byKey(const Key('ai-coach-bil-gold')).hitTestable(),
            findsOneWidget,
          );
          await tester.pumpWidget(
            app(CommunityBilCodePage(repository: repository)),
          );
          await tester.pumpAndSettle();
          for (final key in [
            'community-bil-code-share',
            'community-bil-code-rotate',
          ]) {
            final control = find.byKey(Key(key));
            await tester.scrollUntilVisible(
              control,
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(control.hitTestable(), findsOneWidget);
            expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
