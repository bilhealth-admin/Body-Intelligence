// Run against the isolated source overlay with the BIL-07 integration proposal
// applied. The actual shared router and navigation widgets are the subjects.
// No source regex, skipped assertion, compile-time gate, or live backend is used.
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channels_route.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_attention_scope.dart';
import 'package:body_intelligence_log/features/community/presentation/community_entry_gate.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _channel = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _peer = '22222222-2222-4222-8222-222222222222';

Widget _actualGatedDestination(BuildContext context, String location) {
  final configuration = AppRouter.router.configuration;
  final matches = configuration.findMatch(Uri.parse(location));
  expect(matches.error, isNull, reason: location);
  expect(matches.matches, isNotEmpty, reason: location);
  final match = matches.last;
  final state = match.buildState(configuration, matches);
  expect(state.uri, Uri.parse(location));
  expect(match.route.builder, isNotNull);
  final built = match.route.builder!(context, state);
  expect(built, isA<PremiumRouteGlassGate>());
  final premium = built as PremiumRouteGlassGate;
  expect(premium.feature, PremiumGateFeature.community);
  expect(premium.child, isA<CommunityEntryGate>());
  final entry = premium.child as CommunityEntryGate;
  expect(entry.child, isA<CommunitySurface>());
  return (entry.child as CommunitySurface).child;
}

class _NavigationRepository extends CommunityRepository {
  _NavigationRepository(super.client);

  @override
  String get currentUserId => _owner;

  @override
  bool get useServerCommunityReferenceParity => false;

  @override
  Future<bool> isCommunityModerator() async => false;

  @override
  Future<CommunityProfile?> loadMyProfile() async => const CommunityProfile(
    userId: _owner,
    displayName: 'Synthetic navigation member',
    localeCode: 'en',
    discoverable: false,
  );

  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async =>
      CommunityProfileOverview.fromProfile((await loadMyProfile())!);

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];

  @override
  Future<CommunityAttention> loadAttention() async => const CommunityAttention(
    incomingRequests: 2,
    unreadMessages: 3,
    unreadBySender: {_peer: 3},
  );

  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedMode({
    required CommunityFeedMode mode,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async =>
      const CommunityFeedModeBatch(posts: [], hasMore: false, references: []);

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    final policy = CommunityContentPolicy.fromJson({
      'version': 'bil07-synthetic-navigation-policy',
      'locale_code': localeCode,
      'document_url': 'https://policy.invalid/bil07-navigation',
      'effective_at': '2026-10-01T00:00:00Z',
    });
    return CommunityPolicyState.accepted(
      policy,
      acceptedVersion: policy.version,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() => AppRouter.router.dispose());

  testWidgets('actual channel route matches preserve the complete gate chain', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);

    final directory = _actualGatedDestination(context, '/community/channels');
    expect(directory, isA<CommunityChannelsRoute>());
    expect((directory as CommunityChannelsRoute).channelId, isNull);

    final channel = _actualGatedDestination(
      context,
      '/community/channels/$_channel?origin=synthetic',
    );
    expect(channel, isA<CommunityChannelsRoute>());
    expect((channel as CommunityChannelsRoute).channelId, _channel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual private routes still resolve to private destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    expect(
      _actualGatedDestination(context, '/community/messages'),
      isA<CommunityMessagesPage>(),
    );
    expect(
      _actualGatedDestination(context, '/community/messages/new'),
      isA<NewCommunityMessagePage>(),
    );
    final chat = _actualGatedDestination(
      context,
      '/community/chat/$_peer?name=Synthetic%20peer',
    );
    expect(chat, isA<CommunityChatPage>());
    expect((chat as CommunityChatPage).userId, _peer);
    expect(chat.displayName, 'Synthetic peer');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hub Channels tap navigates without borrowing the private badge',
    (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final httpRequests = <Uri>[];
      // SDK worker-isolate lifecycle must stay outside widget fake time.
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://bil07-overlay.invalid',
          'synthetic-bil07-navigation-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            httpRequests.add(request.url);
            throw StateError('Navigation fixture must not request a backend');
          }),
        ),
      ))!;
      addTearDown(() => tester.runAsync(client.dispose));
      final repository = _NavigationRepository(client);
      final attention = CommunityAttentionController(repository.loadAttention)
        ..setOwner(_owner);
      addTearDown(attention.dispose);
      await attention.refresh();
      final router = GoRouter(
        initialLocation: '/community',
        routes: [
          GoRoute(
            path: '/community',
            builder: (_, _) => CommunityHubPage(
              repository: repository,
              entryWelcomeHandled: true,
            ),
          ),
          for (final path in ['/community/channels', '/community/messages'])
            GoRoute(
              path: path,
              builder: (_, state) => Scaffold(
                body: Text(
                  state.uri.path,
                  key: const Key('bil07-integration-destination'),
                ),
              ),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(FreePlan.createState()),
            ),
          ],
          child: CommunityAttentionScope(
            controller: attention,
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-settings')));
      await tester.pumpAndSettle();
      final channelsItem = find.byKey(const Key('community-nav-channels'));
      final messagesItem = find.byKey(const Key('community-nav-messages'));
      expect(channelsItem, findsOneWidget);
      expect(messagesItem, findsOneWidget);
      expect(
        find.descendant(
          of: channelsItem,
          matching: find.byType(CommunityUnreadBadge),
        ),
        findsNothing,
      );
      final privateBadge = find.descendant(
        of: messagesItem,
        matching: find.byType(CommunityUnreadBadge),
      );
      expect(privateBadge, findsOneWidget);
      expect(
        tester.widget<CommunityUnreadBadge>(privateBadge).kind,
        CommunityAttentionKind.messages,
      );
      expect(
        find.descendant(of: messagesItem, matching: find.text('3')),
        findsOneWidget,
      );
      await tester.ensureVisible(channelsItem);
      await tester.tap(channelsItem);
      await tester.pumpAndSettle();
      // GoRouter keeps the outer browser URL for imperative push by default.
      // Its active state and the rendered destination identify the top route.
      expect(router.state.uri.path, '/community/channels');
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('bil07-integration-destination')),
            )
            .data,
        '/community/channels',
      );
      expect(attention.value.unreadMessages, 3);
      expect(attention.value.unreadBySender, {_peer: 3});

      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-nav-messages')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/community/messages');
      expect(attention.value.unreadMessages, 3);
      expect(httpRequests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
