import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/community/circle_management/circle_management.dart';
import 'package:body_intelligence_log/features/community/circle_management/presentation/circle_management_surfaces.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'circle_management_client_fixture.dart';

class Bil06UiPicker implements CommunityPostImagePickerContract {
  CommunityPostImageDraft? result;
  Object? error;
  Future<CommunityPostImageDraft?> Function()? onPick;
  int calls = 0;

  @override
  Future<CommunityPostImageDraft?> pick() async {
    calls++;
    if (error != null) throw error!;
    return onPick == null ? result : await onPick!();
  }
}

class Bil06UiCleanupGateway extends Bil06FakeGateway {
  bool failCleanup = true;

  @override
  Future<void> removeCancelledMedia(CircleMediaReservation reservation) async {
    await super.removeCancelledMedia(reservation);
    if (failCleanup) throw StateError('Synthetic cleanup failure');
  }
}

class Bil06UiPagedInvitesGateway extends Bil06FakeGateway {
  final cursors = <String?>[];
  static const secondId = '66666666-6666-4666-8666-666666666666';

  @override
  Future<CircleInvitePage> loadInvites({
    String? circleSlug,
    String? afterId,
    int limit = 30,
  }) async {
    check();
    cursors.add(afterId);
    return afterId == null
        ? CircleInvitePage(invites: [bil06Invite()], nextAfterId: bil06InviteId)
        : const CircleInvitePage(
            invites: [
              CircleInvitation(
                id: secondId,
                circleSlug: 'synthetic-circle',
                inviterId: bil06OwnerB,
                inviteeId: bil06OwnerA,
                status: CircleInviteStatus.pending,
                canAccept: true,
                canDecline: true,
                canCancel: false,
              ),
            ],
          );
  }
}

CommunityPostImageDraft bil06UiImage() => validateCommunityPostImage(
  Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2))),
);

Future<void> bil06UiSize(WidgetTester tester, {double width = 430}) async {
  await tester.binding.setSurfaceSize(Size(width, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> bil06Tap(WidgetTester tester, String key) async {
  await bil06ReadyToTap(tester, key);
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> bil06ReadyToTap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  // Editing and ensureVisible each schedule layout. A pointer must target the
  // rendered position after those frames, including inside the scrolling sheet.
  await tester.pump();
  await tester.ensureVisible(target);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget, reason: '$key is tappable');
}

Future<void> bil06MountPanel(
  WidgetTester tester,
  CircleManagementController controller, {
  CommunityCircle? circle,
  CommunityPostImagePickerContract? picker,
  Future<void> Function()? onChanged,
  String locale = 'en',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key('bil06-open-test-panel'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => CircleManagementPanel(
                  controller: controller,
                  isCurrent: () => controller.isCurrent,
                  circle: circle,
                  imagePicker: picker,
                  onChanged: onChanged ?? () async {},
                ),
              ),
              child: const Text('Outside circle management'),
            ),
          ),
        ),
      ),
    ),
  );
  await bil06Tap(tester, 'bil06-open-test-panel');
}

Future<void> bil06ReviewCreate(WidgetTester tester) async {
  await bil06Tap(tester, 'bil06-create-entry');
  await tester.enterText(
    find.byKey(const Key('bil06-create-name')),
    'Synthetic circle',
  );
  await tester.enterText(
    find.byKey(const Key('bil06-create-description')),
    'A reviewed local fixture description.',
  );
  await bil06Tap(tester, 'bil06-create-privacy');
  final privacy = find.text('Private').hitTestable();
  expect(privacy, findsOneWidget);
  await tester.tap(privacy);
  await tester.pumpAndSettle();
  await bil06Tap(tester, 'bil06-create-join-private');
  final invitation = find.text('Invitation required').hitTestable();
  expect(invitation, findsOneWidget);
  await tester.tap(invitation);
  await tester.pumpAndSettle();
  await bil06Tap(tester, 'bil06-create-review');
}

class Bil06UiRepository extends CommunityRepository {
  Bil06UiRepository(super.client);

  int listCalls = 0;
  List<CommunityCircle> rows = const [
    CommunityCircle(
      slug: 'healthy-eating',
      titleCopyKey: 'community_circle_healthy_eating',
      descriptionCopyKey: 'community_circle_healthy_eating_body',
      rulesCopyKey: 'community_circle_standard_rules',
      access: CommunityCircleAccess.public,
      joinPolicy: CommunityCircleJoinPolicy.open,
      featured: false,
      memberCount: 2,
      postCount: 0,
    ),
  ];

  @override
  String get currentUserId => bil06OwnerA;

  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async {
    listCalls++;
    return rows;
  }
}

Future<void> bil06MountList(
  WidgetTester tester,
  Bil06FakeGateway gateway, {
  Bil06UiRepository? repository,
  List<CommunityCircle>? legacyRows,
}) async {
  // Supabase's persistent JSON isolate and session lifecycle must be created
  // outside the widget fake clock. The session contains synthetic local data.
  final client = repository == null
      ? (await tester.runAsync(() async {
          final client = SupabaseClient(
            'https://bil06-widget.invalid',
            'synthetic-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          );
          final payload = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({'sub': bil06OwnerA, 'exp': 4102444800}),
                ),
              )
              .replaceAll('=', '');
          await client.auth.recoverSession(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
              'refresh_token': 'synthetic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': bil06OwnerA,
                'email': 'bil06@example.invalid',
                'app_metadata': <String, Object?>{},
                'user_metadata': <String, Object?>{},
                'aud': 'authenticated',
                'created_at': '2026-10-07T00:00:00Z',
              },
            }),
          );
          return client;
        }))!
      : null;
  if (client != null) {
    addTearDown(() => tester.runAsync(client.dispose));
    expect(client.auth.currentUser?.id, bil06OwnerA);
  }
  final source = repository ?? Bil06UiRepository(client!);
  if (legacyRows != null) source.rows = legacyRows;
  await tester.pumpWidget(
    MaterialApp(
      home: CommunityCirclesPage(
        repository: source,
        managementGatewayFactory: (_, _, _, _) => gateway,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
