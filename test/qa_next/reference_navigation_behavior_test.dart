import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_feed_modes.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_reference_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _NavigationRepository extends CommunityRepository {
  _NavigationRepository()
    : super(
        SupabaseClient(
          'https://navigation.invalid',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  int policyReads = 0;

  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';

  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async => null;

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];

  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async => const [];

  @override
  Future<CommunityFeedModeBatch> loadCommunityFeedMode({
    CommunityFeedMode mode = CommunityFeedMode.forYou,
    int? beforePriority,
    DateTime? before,
    String? beforeId,
    int limit = 40,
  }) async => const CommunityFeedModeBatch(
    posts: [],
    hasMore: false,
    references: [],
  );

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    policyReads++;
    return const CommunityPolicyState.unavailable();
  }
}

Color _dockColor(WidgetTester tester) {
  final dock = tester.widget<DecoratedBox>(
    find.byKey(const Key('bil-reference-navigation')),
  );
  return (dock.decoration as BoxDecoration).gradient!.colors.first;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final override in <bool?>[null, false, true]) {
      testWidgets('dock theme $brightness override $override', (tester) async {
        final selections = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              bottomNavigationBar: BilReferenceBottomBar(
                selected: 3,
                dark: override,
                onSelected: selections.add,
              ),
            ),
          ),
        );
        final dark = override ?? brightness == Brightness.dark;
        expect(
          _dockColor(tester),
          dark ? const Color(0xFF172530) : const Color(0xFFFFFFFF),
        );
        for (var index = 0; index < 5; index++) {
          final target = find.byKey(Key('bil-reference-nav-$index'));
          expect(target.hitTestable(), findsOneWidget);
          expect(tester.getSize(target).height, greaterThanOrEqualTo(64));
          await tester.tap(target);
        }
        expect(selections, [0, 1, 2, 3, 4]);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('dock updates when the inherited theme changes', (tester) async {
    final selections = <int>[];
    Widget host(Brightness brightness) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        bottomNavigationBar: BilReferenceBottomBar(
          selected: 3,
          onSelected: selections.add,
        ),
      ),
    );
    await tester.pumpWidget(host(Brightness.light));
    expect(_dockColor(tester), const Color(0xFFFFFFFF));
    await tester.pumpWidget(host(Brightness.dark));
    await tester.pumpAndSettle();
    expect(_dockColor(tester), const Color(0xFF172530));
    await tester.tap(find.byKey(const Key('bil-reference-nav-2')));
    expect(selections, [2]);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      for (final section in ['explore', 'following', 'circles']) {
        testWidgets(
          'Community Quick Add opens diary: $language $brightness $section',
          (tester) async {
            final repository = _NavigationRepository();
            addTearDown(repository.communitySocialClient.dispose);
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
                GoRoute(
                  path: '/daily-log',
                  builder: (_, _) => const Scaffold(
                    body: Text('Diary destination', key: Key('diary-target')),
                  ),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp.router(
                  routerConfig: router,
                  locale: Locale(language),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  theme: ThemeData(brightness: brightness),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(Key('community-hub-$section-tab')).hitTestable(),
            );
            await tester.pumpAndSettle();
            final readsBeforeTap = repository.policyReads;
            expect(readsBeforeTap, greaterThan(0));
            expect(
              _dockColor(tester),
              brightness == Brightness.dark
                  ? const Color(0xFF172530)
                  : const Color(0xFFFFFFFF),
            );
            final quickAdd = find.byKey(const Key('bil-reference-nav-2'));
            expect(quickAdd.hitTestable(), findsOneWidget);
            await tester.tap(quickAdd);
            await tester.pumpAndSettle();
            expect(
              router.routeInformationProvider.value.uri.path,
              BilReferenceBottomBar.routes[2],
            );
            expect(find.byKey(const Key('diary-target')), findsOneWidget);
            expect(repository.policyReads, readsBeforeTap);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
