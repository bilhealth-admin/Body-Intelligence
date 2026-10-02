import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_attention_scope.dart';
import 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';
import 'package:body_intelligence_log/features/community/presentation/community_profile_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_bil_code_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_safety_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../visual_closure/visual_evidence_font.dart';

/// Synthetic profiles only. These scenes never connect to production or send.
class _VisualRepository extends CommunityRepository {
  _VisualRepository(this.arabic)
    : super(
        SupabaseClient(
          'https://visual.invalid',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final bool arabic;
  static const owner = '11111111-1111-4111-8111-111111111111';
  static const peer = '22222222-2222-4222-8222-222222222222';
  String get name => arabic ? 'عضو تجريبي' : 'Sample member';
  @override
  String get currentUserId => owner;
  @override
  Future<bool> isCommunityModerator() async => false;
  @override
  Future<CommunityProfile?> loadMyProfile() async => CommunityProfile(
    userId: owner,
    displayName: name,
    localeCode: arabic ? 'ar' : 'en',
    discoverable: true,
    bio: arabic
        ? 'أشارك خطوات رحلتي مع أصدقائي.'
        : 'Sharing small steps with my friends.',
  );
  @override
  Future<CommunitySocialIdentity> loadSocialIdentity() async =>
      const CommunitySocialIdentity(
        handle: 'sample_member',
        chosen: true,
        discoverable: true,
      );
  @override
  Future<CommunityPublicCode> loadPublicCode() async => CommunityPublicCode(
    code: '11111111111141118111111111111111',
    uri: Uri.parse('bil://community/member/11111111111141118111111111111111'),
    handle: 'sample_member',
  );
  @override
  Future<CommunityAttention> loadAttention() async => const CommunityAttention(
    unreadMessages: 3,
    incomingRequests: 1,
    unreadBySender: {peer: 3},
  );
  @override
  Future<CommunityFeedBatch> loadMyPosts({
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async => CommunityFeedBatch(
    posts: [
      CommunityPost(
        id: '88888888-8888-4888-8888-888888888888',
        authorId: owner,
        authorName: name,
        authorHandle: 'sample_member',
        body: arabic ? 'يوم جديد وخطوة جديدة.' : 'A new day and a new step.',
        createdAt: DateTime.utc(2026, 9, 29, 8),
        moderationStatus: CommunityPostModerationStatus.pending,
      ),
    ],
    hasMore: false,
  );
  @override
  Future<CommunitySavedPostBatch> loadSavedPosts({
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async => CommunitySavedPostBatch(
    posts: (await loadFeed()).map((p) => p.withSaved(true)).toList(),
    hasMore: false,
  );
  @override
  Future<List<CommunityPostStats>> loadPostStats(List<String> ids) async => [
    for (final id in ids)
      CommunityPostStats(
        postId: id,
        likeCount: 4,
        liked: false,
        commentCount: 1,
      ),
  ];
  @override
  Future<List<CommunityComment>> loadPostComments(
    String postId, {
    DateTime? after,
    String? afterId,
    int limit = 30,
  }) async => [
    CommunityComment(
      id: 'fixture-comment',
      authorId: peer,
      authorName: name,
      authorHandle: 'sample_member',
      body: arabic
          ? 'شكرًا على المشاركة والتشجيع!'
          : 'Thanks for sharing and encouraging everyone!',
      createdAt: DateTime.utc(2026, 9, 29, 8, 15),
      likeCount: 0,
      liked: false,
    ),
  ];

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'community-policy-v1',
      'locale_code': localeCode,
      'document_url': 'https://www.bilhealth.com/community-guidelines',
      'effective_at': '2026-09-08T00:00:00Z',
    });
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
  }

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [
    CommunityPost(
      id: '66666666-6666-4666-8666-666666666666',
      authorId: peer,
      authorName: name,
      authorHandle: 'sample_member',
      body: arabic
          ? 'خطوة صغيرة كل يوم تصنع فرقًا. كيف كان يومكم؟'
          : 'Small steps every day make a difference. How was your day?',
      createdAt: DateTime.utc(2026, 9, 29, 8),
      likeCount: 4,
      commentCount: 2,
    ),
    CommunityPost(
      id: '77777777-7777-4777-8777-777777777777',
      authorId: peer,
      authorName: name,
      authorHandle: 'sample_member',
      body: 'A quiet walk and a fresh start.',
      createdAt: DateTime.utc(2026, 9, 28, 8),
      likeCount: 1,
    ),
  ];
  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async => [
    {
      'id': '33333333-3333-4333-8333-333333333333',
      'requester_id': peer,
      'addressee_id': owner,
      'other_user_id': peer,
      'status': 'accepted',
      'profile': {'display_name': name, 'avatar_url': null},
    },
  ];
  Map<String, dynamic> row(bool incoming, int index) => {
    'id': '${index == 0 ? '44444444' : '55555555'}-4444-4444-8444-444444444444',
    'sender_id': incoming ? peer : owner,
    'recipient_id': incoming ? owner : peer,
    'profile': {'display_name': name, 'avatar_url': null},
    'body': arabic
        ? 'أهلًا، شكرًا على التشجيع!'
        : 'Hello, thanks for the encouragement!',
    'created_at': '2026-09-29T08:20:00Z',
    'read_at': index == 0 ? null : '2026-09-29T08:21:00Z',
  };
  @override
  Future<List<Map<String, dynamic>>> loadInboxMessages() async => [
    row(true, 0),
    row(true, 1),
  ];
  @override
  Future<List<Map<String, dynamic>>> loadSentMessages() async => [
    row(false, 0),
  ];
  @override
  Stream<void> watchInboxChanges() => const Stream.empty();
  @override
  Stream<void> watchConversationChanges(String other) => const Stream.empty();
  @override
  Future<List<CommunityMessage>> loadMessages(String other) async => [
    for (var index = 0; index < 4; index++)
      CommunityMessage(
        id: 'synthetic-message-$index',
        senderId: index.isEven ? peer : owner,
        recipientId: index.isEven ? owner : peer,
        body: arabic
            ? 'مرحبًا بك في المجتمع. يوم جميل وخطوة جديدة.'
            : 'Welcome to the community. A good day and a fresh start.',
        createdAt: DateTime.utc(2026, 9, 29, 8, index),
        readAt: DateTime.utc(2026, 9, 29, 8, index + 1),
      ),
  ];
  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async => ids.length;
}

void main() {
  setUpAll(() async {
    await loadVisualEvidenceFont();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final arabic in [false, true]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'production Community surfaces ${arabic ? 'ar' : 'en'} ${dark ? 'dark' : 'light'} text $scale',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(414, 896);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final repository = _VisualRepository(arabic);
            final controller = CommunityAttentionController(
              () async => const CommunityAttention(
                unreadMessages: 3,
                incomingRequests: 1,
                unreadBySender: {_VisualRepository.peer: 3},
              ),
            );
            controller.setOwner('fixture');
            await controller.refresh();
            final key = GlobalKey();
            final locale = Locale(arabic ? 'ar' : 'en');
            final theme = dark
                ? BilFlagshipTheme.dark(isArabic: arabic)
                : BilFlagshipTheme.light(isArabic: arabic);
            final scenes = <String, Widget>{
              'welcome': const Scaffold(body: CommunityWelcome()),
              'feed': CommunityHubPage(repository: repository),
              'profile': CommunityProfilePage(repository: repository),
              'my_code': CommunityBilCodePage(repository: repository),
              'my_posts': CommunityMyPostsPage(
                repository: repository,
                showProfileHeader: true,
              ),
              'saved': CommunitySavedPostsPage(repository: repository),
              'updates': CommunityNotificationsPage(repository: repository),
              'safety': CommunitySafetyPage(repository: repository),
              'find_people': CommunityPeoplePage(repository: repository),
              'messages': CommunityMessagesPage(repository: repository),
              'friends': CommunityConnectionsPage(repository: repository),
              'chat': CommunityChatPage(
                userId: _VisualRepository.peer,
                displayName: repository.name,
                repository: repository,
              ),
            };
            for (final scene in scenes.entries) {
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    verifiedSubscriptionStateProvider.overrideWithValue(
                      AsyncData(FreePlan.createState()),
                    ),
                  ],
                  child: MaterialApp(
                    theme: visualEvidenceTheme(
                      theme.copyWith(
                        textTheme: theme.textTheme.apply(
                          fontFamilyFallback: const [
                            'RobotoEvidence',
                            'NotoArabicEvidence',
                          ],
                        ),
                      ),
                      fontFamily: arabic
                          ? 'NotoArabicEvidence'
                          : 'RobotoEvidence',
                    ),
                    locale: locale,
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true,
                      ),
                      child: CommunityAttentionScope(
                        controller: controller,
                        child: RepaintBoundary(key: key, child: child!),
                      ),
                    ),
                    home: CommunitySurface(child: scene.value),
                  ),
                ),
              );
              await tester.pump();
              if (scene.key == 'feed') {
                await tester.pump(const Duration(milliseconds: 2200));
              }
              await tester.pumpAndSettle();
              await settleVisualAssetImages(tester);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: scene.key);
              await _capture(
                tester,
                key,
                '${scene.key}_${locale.languageCode}_${dark ? 'dark' : 'light'}_${scale.toInt()}',
              );
              if (scene.key == 'feed') {
                await tester.tap(find.byKey(const Key('community-settings')));
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const Key('community-nav-messages')),
                  findsOneWidget,
                );
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'navigation sheet',
                );
                await _capture(
                  tester,
                  key,
                  'actions_${locale.languageCode}_${dark ? 'dark' : 'light'}_${scale.toInt()}',
                );
                tester
                    .state<NavigatorState>(find.byType(Navigator).first)
                    .pop();
                await tester.pumpAndSettle();
                final comments = find.byKey(
                  const Key(
                    'community-post-comments-66666666-6666-4666-8666-666666666666',
                  ),
                );
                await tester.scrollUntilVisible(
                  comments,
                  180,
                  scrollable: find
                      .descendant(
                        of: find.byKey(
                          const PageStorageKey('community-feed-scroll'),
                        ),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
                await tester.tap(comments);
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'post details/comments',
                );
                await _capture(
                  tester,
                  key,
                  'comments_${locale.languageCode}_${dark ? 'dark' : 'light'}_${scale.toInt()}',
                );
                tester
                    .state<NavigatorState>(find.byType(Navigator).first)
                    .pop();
                await tester.pumpAndSettle();
                await tester.tap(
                  find.byKey(const Key('community-create-post')),
                );
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const Key('community-post-editor-page')),
                  findsOneWidget,
                );
                expect(tester.takeException(), isNull, reason: 'create post');
                await _capture(
                  tester,
                  key,
                  'composer_${locale.languageCode}_${dark ? 'dark' : 'light'}_${scale.toInt()}',
                );
              }
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            }
            controller.dispose();
          },
        );
      }
    }
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['BIL_COMMUNITY_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 1.5);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
