import 'dart:async';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

late SupabaseClient _testClient;

final _acceptedPolicy = CommunityContentPolicy.fromJson({
  'version': 'community-policy-v1',
  'locale_code': 'en',
  'document_url': 'https://www.bilhealth.com/community-guidelines',
  'effective_at': '2026-09-08T00:00:00Z',
});

class _Repository extends CommunityRepository {
  _Repository() : super(_testClient);
  int imageCalls = 0;
  int textCalls = 0;
  int foodLoads = 0;
  Completer<void>? pendingTextPublication;
  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';
  @override
  Future<CommunityProfile?> loadMyProfile() async => CommunityProfile(
    userId: currentUserId,
    displayName: 'Existing member',
    localeCode: 'en',
    discoverable: false,
    visibility: CommunityProfileVisibility.private,
  );
  @override
  Future<CommunityPublicCode> loadPublicCode() async =>
      CommunityPublicCode.fromJson({
        'code': 'aabbccddaabbccddaabbccddaabbccdd',
        'uri': 'bil://community/member/aabbccddaabbccddaabbccddaabbccdd',
        'handle': 'existing_member',
      });
  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => CommunityPolicyState.accepted(
    _acceptedPolicy,
    acceptedVersion: _acceptedPolicy.version,
  );
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [];
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async => [];
  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async {
    foodLoads++;
    return [];
  }

  @override
  Future<void> publishPost(String body) async {
    textCalls++;
    if (pendingTextPublication case final pending?) await pending.future;
  }

  @override
  Future<void> publishPostWithImage(
    String body,
    CommunityPostImageDraft image,
  ) async {
    imageCalls++;
  }
}

class _Picker implements CommunityPostImagePickerContract {
  @override
  Future<CommunityPostImageDraft?> pick() async => validateCommunityPostImage(
    Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 5))),
  );
}

void main() {
  setUp(() {
    _testClient = SupabaseClient(
      'https://unit-test.invalid',
      'unit-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => _testClient.dispose());

  testWidgets('empty publication has a visible reason and does not send', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHubPage(
          repository: repository,
          postImagePicker: _Picker(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-create-post')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-post-publish')));
    await tester.pumpAndSettle();
    expect(find.text('Write your post before publishing.'), findsOneWidget);
    expect(repository.textCalls, 0);
  });
  testWidgets(
    'photo without caption is explained, then text plus photo sends',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHubPage(
            repository: repository,
            postImagePicker: _Picker(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-create-post')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-post-add-photo')));
      await tester.pumpAndSettle();
      final publish = find.byKey(const Key('community-post-publish'));
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      expect(publish.hitTestable(), findsOneWidget);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(
        find.text('Write a caption before publishing your photo.'),
        findsOneWidget,
      );
      expect(repository.imageCalls, 0);
      final composer = find.byKey(const Key('community-post-composer'));
      await tester.ensureVisible(composer);
      await tester.pumpAndSettle();
      await tester.enterText(composer, 'Test caption');
      await tester.pump();
      // Assert logical validity immediately; then let InputDecorator finish its
      // normal error fade before asserting that its old Text widget is removed.
      expect(tester.widget<TextField>(composer).decoration!.errorText, isNull);
      await tester.pumpAndSettle();
      expect(
        find.text('Write a caption before publishing your photo.'),
        findsNothing,
      );
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      expect(publish.hitTestable(), findsOneWidget);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(repository.imageCalls, 1);
      expect(repository.textCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'photo composer remains reachable in a short keyboard-sized viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHubPage(
            repository: repository,
            postImagePicker: _Picker(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-create-post')));
      await tester.pumpAndSettle();
      final photo = find.byKey(const Key('community-post-add-photo'));
      await tester.ensureVisible(photo);
      await tester.pumpAndSettle();
      await tester.tap(photo);
      await tester.pumpAndSettle();
      final publish = find.byKey(const Key('community-post-publish'));
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      expect(publish.hitTestable(), findsOneWidget);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(repository.imageCalls, 0);
      expect(
        find.text('Write a caption before publishing your photo.'),
        findsOneWidget,
      );
      final composer = find.byKey(const Key('community-post-composer'));
      await tester.ensureVisible(composer);
      await tester.pumpAndSettle();
      await tester.enterText(composer, 'A valid short-screen caption');
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(publish).dy, lessThanOrEqualTo(480));
      expect(publish.hitTestable(), findsOneWidget);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(repository.imageCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Publish keeps its geometry and never duplicates an in-flight request',
    (tester) async {
      final repository = _Repository()
        ..pendingTextPublication = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHubPage(
            repository: repository,
            postImagePicker: _Picker(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-create-post')));
      await tester.pumpAndSettle();

      final composer = find.byKey(const Key('community-post-composer'));
      await tester.enterText(composer, 'Stable publish regression');
      await tester.pumpAndSettle();
      final publish = find.byKey(const Key('community-post-publish'));
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      final before = tester.getSize(publish);
      final initialLabel = tester.widget<FilledButton>(publish);
      expect(initialLabel.onPressed, isNotNull);
      await tester.tap(publish);
      // Publish can enter its pending state before a frame is rendered. Pump
      // explicitly even when the repository receives the call immediately.
      await tester.pump();
      for (var i = 0; i < 30 && repository.textCalls == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(repository.textCalls, 1);
      expect(tester.getSize(publish), before);
      expect(tester.widget<FilledButton>(publish).onPressed, isNull);
      expect(find.text('Publish'), findsOneWidget);

      // A second tap while pending cannot call the repository again.
      await tester.tap(publish, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.textCalls, 1);
      expect(tester.getSize(publish), before);

      repository.pendingTextPublication!.complete();
      await tester.pumpAndSettle();
      expect(repository.textCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('food list is not reloaded by a parent rebuild', (tester) async {
    final repository = _Repository();
    Widget app() => MaterialApp(
      home: CommunityHubPage(
        repository: repository,
        postImagePicker: _Picker(),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('community-nav-foods')),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('community-navigation-sheet')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-nav-foods')));
    await tester.pumpAndSettle();
    final baseline = repository.foodLoads;
    expect(baseline, greaterThan(0));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(repository.foodLoads, baseline);
  });
}
