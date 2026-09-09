import 'dart:io';

import 'package:body_intelligence_log/features/community/data/community_public_code_failure.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_bil_code_page.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_deep_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _CodeRepository extends CommunityRepository {
  _CodeRepository()
    : super(
        SupabaseClient(
          'https://public-code.invalid',
          'public-code-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  static const userId = '22222222-2222-4222-8222-222222222222';
  static const firstCode = '0123456789abcdef0123456789abcdef';
  static const secondCode = 'fedcba9876543210fedcba9876543210';
  int rotations = 0;
  int resolutions = 0;
  int friendRequests = 0;
  bool unavailable = false;
  CommunityPublicCodeFailure? publicCodeFailure;

  CommunityPublicCode code(String value) => CommunityPublicCode.fromJson({
    'code': value,
    'uri': 'bil://community/member/$value',
    'handle': 'bil_runner',
  });

  @override
  Future<CommunityPublicCode> loadPublicCode() async {
    final failure = publicCodeFailure;
    if (failure != null) throw failure;
    return code(firstCode);
  }

  @override
  Future<CommunityPublicCode> rotatePublicCode() async {
    rotations++;
    return code(secondCode);
  }

  @override
  Future<CommunityResolvedMember?> resolvePublicCode(String value) async {
    resolutions++;
    if (unavailable) return null;
    return CommunityResolvedMember.fromJson({
      'user_id': userId,
      'handle': 'training_partner',
      'display_name': 'Training Partner',
      'avatar_url': null,
      'relationship': 'none',
    });
  }

  @override
  Future<CommunityFriendRequestStatus> requestFriend(String addresseeId) async {
    expect(addresseeId, userId);
    friendRequests++;
    return CommunityFriendRequestStatus.pending;
  }
}

void main() {
  test('post author payload rejects non-UUID and unknown relationships', () {
    const validId = '22222222-2222-4222-8222-222222222222';
    expect(
      CommunityPostAuthorSocial.fromJson({
        'user_id': validId,
        'handle': 'training_partner',
        'relationship': 'none',
        'can_request': false,
      }).userId,
      validId,
    );
    for (final payload in <Map<String, dynamic>>[
      {
        'user_id': 'not-a-user-id',
        'handle': 'training_partner',
        'relationship': 'none',
        'can_request': false,
      },
      {
        'user_id': validId,
        'handle': 'training_partner',
        'relationship': 'declined',
        'can_request': false,
      },
    ]) {
      expect(
        () => CommunityPostAuthorSocial.fromJson(payload),
        throwsFormatException,
      );
    }
  });

  test('public-code models accept only the exact opaque BIL URI', () {
    const code = _CodeRepository.firstCode;
    expect(
      CommunityCodeScannerPage.codeFromPayload('bil://community/member/$code'),
      code,
    );
    expect(
      CommunityCodeScannerPage.codeFromPayload(
        'bil://community/member/$code?token=x',
      ),
      isNull,
    );
    expect(
      CommunityCodeScannerPage.codeFromPayload(
        'https://example.invalid/community/member/$code',
      ),
      isNull,
    );
    expect(
      CommunityCodeScannerPage.codeFromPayload('bil://community/member/old'),
      isNull,
    );
    expect(
      CommunityDeepLink.routeFor(Uri.parse('bil://community/member/$code')),
      '/community/member/$code',
    );
  });

  test('Flutter RPC names and the frozen SQL signatures stay aligned', () {
    final flutterSource = File(
      'lib/features/community/data/community_social_repository_mixin.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260908181700_community_social_saves_and_public_codes.sql',
    ).readAsStringSync();
    for (final name in <String>[
      'bil_social_save_v2',
      'bil_social_saved_state_v2',
      'bil_social_saved_posts_v2',
      'bil_social_public_code_v2',
      'bil_social_rotate_public_code_v2',
      'bil_social_resolve_public_code_v2',
    ]) {
      expect(flutterSource, contains("'$name'"));
      expect(migration, contains('function public.$name'));
    }
    final authorsMigration = File(
      'supabase/migrations/20260908181900_community_social_post_authors_v2.sql',
    ).readAsStringSync();
    expect(flutterSource, contains("'bil_social_post_authors_v2'"));
    expect(
      authorsMigration,
      contains('function public.bil_social_post_authors_v2(p_user_ids uuid[])'),
    );
    expect(flutterSource, contains("'p_user_ids': userIds"));
    expect(flutterSource, contains("'p_post_id': postId"));
    expect(flutterSource, contains("'p_saved': saved"));
    expect(flutterSource, contains("'p_post_ids': postIds"));
    expect(flutterSource, contains("'p_code': code"));
  });

  testWidgets('My BIL Code renders a real QR and rotates explicitly', (
    tester,
  ) async {
    final repository = _CodeRepository();
    await tester.pumpWidget(
      MaterialApp(home: CommunityBilCodePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('community-bil-code-qr')), findsOneWidget);
    expect(find.text('@bil_runner'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-bil-code-rotate')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your old code will stop working. Friends will need the new one.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Replace code'));
    await tester.pumpAndSettle();
    expect(repository.rotations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BIL Code explains a missing profile without claiming a friend is required',
    (tester) async {
      final repository = _CodeRepository()
        ..publicCodeFailure =
            const CommunityPublicCodeFailure.profileRequired();
      await tester.pumpWidget(
        MaterialApp(home: CommunityBilCodePage(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Save your Community profile first. Your BIL Code is then created automatically; you do not need to add a friend first.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-bil-code-open-profile')),
        findsOneWidget,
      );
      expect(find.textContaining('add a friend first'), findsOneWidget);
    },
  );

  testWidgets('resolved code requires an explicit Add Friend action', (
    tester,
  ) async {
    final repository = _CodeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityMemberCodePage(
          code: _CodeRepository.firstCode,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.resolutions, 1);
    expect(find.text('Training Partner'), findsOneWidget);
    expect(find.text('@training_partner'), findsOneWidget);
    expect(repository.friendRequests, 0);
    await tester.tap(find.byKey(const Key('community-code-add-friend')));
    await tester.pumpAndSettle();
    expect(repository.friendRequests, 1);
    expect(find.text('Request pending'), findsOneWidget);
  });

  testWidgets('invalid, rotated, blocked, and suspended codes fail closed', (
    tester,
  ) async {
    final repository = _CodeRepository()..unavailable = true;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityMemberCodePage(
          code: _CodeRepository.firstCode,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This code is invalid, expired, private, or unavailable.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-code-add-friend')), findsNothing);
  });

  testWidgets('scanner unavailable state is honest and does not fake a scan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CommunityCodeScannerPage(scannerEnabled: false)),
    );
    expect(
      find.text('Code scanning needs an iOS or Android camera.'),
      findsOneWidget,
    );
  });
}
