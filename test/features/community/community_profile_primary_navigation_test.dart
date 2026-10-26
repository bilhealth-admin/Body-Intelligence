import 'dart:async';
import 'package:body_intelligence_log/app/router/bil_primary_navigation.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';

class _ProfileRepository extends CommunityRepository {
  _ProfileRepository(super.client);
  bool ownerChanged = false;
  Completer<CommunityProfileOverview>? held;
  @override
  String get currentUserId =>
      ownerChanged ? '22222222-2222-4222-8222-222222222222' : _owner;
  @override
  bool get useServerCommunityReferenceParity => false;
  static const profile = CommunityProfileOverview(
    userId: _owner,
    displayName: 'Synthetic profile',
    isSelf: true,
    relationship: CommunityRelationshipStatus.none,
    allowFriendRequests: true,
    allowFollows: true,
    showFollowers: true,
    showFollowing: true,
    showFriends: true,
    showPosts: true,
    showMembershipTier: false,
    followerCount: 0,
    followingCount: 0,
    friendCount: 5,
    postCount: 0,
  );
  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async =>
      held == null ? profile : await held!.future;
  @override
  Future<CommunityFeedBatch> loadProfilePosts({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => const CommunityFeedBatch(posts: [], hasMore: false);
}

class _OptionalMetadataRepository extends _ProfileRepository {
  _OptionalMetadataRepository(super.client);
  Completer<CommunityCreatorProfile>? pendingCreator;
  int coverReads = 0;
  @override
  bool get useServerCommunityReferenceParity => true;
  @override
  Future<CommunityProfileOverview> loadProfileOverview(String userId) async =>
      CommunityProfileOverview(
        userId: userId,
        displayName: 'Synthetic metadata profile',
        isSelf: false,
        relationship: CommunityRelationshipStatus.none,
        allowFriendRequests: true,
        allowFollows: true,
        showFollowers: true,
        showFollowing: true,
        showFriends: true,
        showPosts: true,
        showMembershipTier: false,
        followerCount: 0,
        followingCount: 0,
        friendCount: 5,
        postCount: 0,
      );
  @override
  Future<CommunityCreatorProfile> loadCommunityCreatorProfile(
    String userId,
  ) async {
    if (pendingCreator != null) return await pendingCreator!.future;
    throw StateError('Synthetic optional creator outage');
  }

  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> ids,
  ) async => {};
  @override
  Future<String?> loadCommunityProfileCoverUrl(String userId) async {
    coverReads++;
    return null;
  }

  @override
  Future<List<CommunityProfileReview>> loadCommunityProfileReviews({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async => [];
}

void main() {
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://profile-nav.invalid',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() async => client.dispose());
  for (final pending in [false, true]) {
    testWidgets(
      'authorized profile survives optional creator failure pending=$pending',
      (tester) async {
        final repository = _OptionalMetadataRepository(client);
        if (pending) {
          repository.pendingCreator = Completer<CommunityCreatorProfile>();
        }
        try {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                home: CommunityMemberProfilePage(
                  userId: '33333333-3333-4333-8333-333333333333',
                  repository: repository,
                ),
              ),
            ),
          );
          await tester.pump();
          if (pending) {
            await tester.pump(const Duration(seconds: 6));
            for (var i = 0; i < 5; i++) {
              await tester.pump();
            }
          }
          await tester.pumpAndSettle();
          expect(find.text('Synthetic metadata profile'), findsOneWidget);
          expect(find.text('5 Friends'), findsOneWidget);
          expect(
            repository.coverReads,
            pending ? 0 : 1,
            reason:
                'one shared optional budget must not start new reads after its deadline',
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          if (repository.pendingCreator?.isCompleted == false) {
            repository.pendingCreator!.completeError(
              StateError('Synthetic cancelled optional read'),
            );
          }
          await tester.pump();
        }
      },
    );
  }
  testWidgets(
    'negative control: unkeyed pages keep an imperative detail above the changed URI',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/community',
        routes: [
          GoRoute(
            path: '/community',
            pageBuilder: (context, state) => NoTransitionPage(
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      unawaited(
                        Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (detailContext) => Scaffold(
                              body: TextButton(
                                onPressed: () =>
                                    GoRouter.of(detailContext).go('/dashboard'),
                                child: const Text('Legacy detail navigation'),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open legacy detail'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (_, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Legacy destination')),
            ),
          ),
        ],
      );
      try {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open legacy detail'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Legacy detail navigation'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/dashboard');
        expect(
          find.text('Legacy detail navigation'),
          findsOneWidget,
          reason:
              'the old page configuration changes the URI while keeping the covering detail',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    },
  );
  for (final initial in [
    '/community',
    '/dashboard',
    '/settings',
    '/intelligence-center',
  ]) {
    for (final destination in {
      0: '/dashboard',
      1: '/intelligence-center',
      3: '/community',
      4: '/settings',
    }.entries) {
      for (final loading in [false, true]) {
        testWidgets(
          'profile tab escapes $initial to ${destination.value} loading=$loading',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final repository = _ProfileRepository(client);
            if (loading) {
              repository.held = Completer<CommunityProfileOverview>();
            }
            Widget origin(BuildContext unusedPageBuilderContext, String path) =>
                Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text('destination:$path'),
                        TextButton(
                          key: const Key('qa-open-profile'),
                          onPressed: () {
                            unawaited(
                              pushCommunityPage<void>(
                                context,
                                CommunityMemberProfilePage(
                                  userId: _owner,
                                  repository: repository,
                                ),
                              ),
                            );
                          },
                          child: const Text('Open actual profile'),
                        ),
                      ],
                    ),
                  ),
                );
            GoRoute route(String path) => GoRoute(
              path: path,
              pageBuilder: (context, state) => bilNoTransitionPage(
                state: state,
                child: origin(context, path),
              ),
            );
            final router = GoRouter(
              initialLocation: initial,
              routes: [
                route('/community'),
                ShellRoute(
                  pageBuilder: (_, state, child) => bilNoTransitionPage(
                    state: state,
                    child: ResponsiveAppShell(
                      currentUri: state.uri,
                      child: child,
                    ),
                  ),
                  routes: [
                    for (final path in [
                      '/dashboard',
                      '/settings',
                      '/intelligence-center',
                      '/daily-log',
                    ])
                      route(path),
                  ],
                ),
              ],
            );
            try {
              await tester.pumpWidget(
                ProviderScope(
                  child: MaterialApp.router(
                    routerConfig: router,
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      ...GlobalMaterialLocalizations.delegates,
                    ],
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('qa-open-profile')));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 350));
              final profile = find.byKey(
                const Key('community-member-profile-page'),
              );
              expect(profile, findsOneWidget);
              await tester.tap(
                find.descendant(
                  of: profile,
                  matching: find.byKey(
                    Key('bil-reference-nav-${destination.key}'),
                  ),
                ),
              );
              await tester.pump();
              // Flutter3.44's Android fade uses450ms. Observe actual route
              // settlement, including a still-loading page, rather than
              // inspecting a valid outgoing route at350ms.
              await tester.pumpAndSettle(
                const Duration(milliseconds: 20),
                EnginePhase.sendSemanticsUpdate,
                const Duration(seconds: 3),
              );
              expect(
                profile,
                findsNothing,
                reason:
                    'a primary tab cannot leave the pushed profile covering its destination',
              );
              expect(
                router.routeInformationProvider.value.uri.path,
                destination.value,
              );
              expect(
                find.text('destination:${destination.value}'),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              if (repository.held?.isCompleted == false) {
                repository.held!.complete(_ProfileRepository.profile);
              }
              await tester.pump();
              router.dispose();
            }
          },
        );
      }
    }
  }
}
