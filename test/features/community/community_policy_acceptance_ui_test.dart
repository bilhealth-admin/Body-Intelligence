import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_safety_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

CommunityContentPolicy _policy(String version) =>
    CommunityContentPolicy.fromJson({
      'version': version,
      'locale_code': 'en',
      'document_url': 'https://www.bilhealth.com/community-guidelines',
      'effective_at': '2026-09-08T00:00:00.000Z',
    });

final class _PolicyRepository extends CommunityRepository {
  _PolicyRepository(this.state)
    : super(
        SupabaseClient(
          'https://community-policy-test.invalid',
          'community-policy-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  CommunityPolicyState state;
  final List<String> acceptedVersions = [];

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => state;

  @override
  Future<void> acceptContentPolicy(String version) async {
    acceptedVersions.add(version);
    final policy = state.policy;
    if (policy != null && policy.version == version) {
      state = CommunityPolicyState.accepted(policy, acceptedVersion: version);
    }
  }
}

final class _PublishGuardRepository extends CommunityRepository {
  _PublishGuardRepository(this.failure)
    : super(
        SupabaseClient(
          'https://community-publish-test.invalid',
          'community-publish-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final Object failure;
  int publishCalls = 0;

  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';

  @override
  Future<bool> isCommunityModerator() async => false;

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => const [];

  @override
  Future<void> publishPost(String body) async {
    publishCalls += 1;
    throw failure;
  }
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

Future<void> _openComposerAndPublish(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('community-create-post')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('community-post-composer')),
    'Keep this draft until Community access is restored.',
  );
  await tester.tap(find.byKey(const Key('community-post-publish')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no active policy is explicit and cannot record acceptance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CommunitySafetyPage(
          repository: _PolicyRepository(
            const CommunityPolicyState.unavailable(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('community-policy-unavailable')),
      findsOneWidget,
    );
    expect(
      find.text('No active Community policy is available'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No acceptance has been recorded.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('accept-community-policy')), findsNothing);
  });

  testWidgets('unaccepted policy stays locked until the user confirms', (
    tester,
  ) async {
    final repository = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v1')),
    );
    await tester.pumpWidget(_app(CommunitySafetyPage(repository: repository)));
    await tester.pumpAndSettle();

    final accept = find.byKey(const Key('accept-community-policy'));
    expect(accept, findsOneWidget);
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    expect(find.byKey(const Key('community-policy-not-now')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-community-policy')));
    await tester.pump();
    expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
    await tester.tap(accept);
    await tester.pumpAndSettle();

    expect(repository.acceptedVersions, ['community-policy-v1']);
    expect(find.text('Accepted'), findsOneWidget);
  });

  testWidgets('a newly active version requires a new real acceptance', (
    tester,
  ) async {
    final v1 = _PolicyRepository(
      CommunityPolicyState.accepted(
        _policy('community-policy-v1'),
        acceptedVersion: 'community-policy-v1',
      ),
    );
    await tester.pumpWidget(
      _app(
        CommunitySafetyPage(
          key: const ValueKey('community-policy-v1'),
          repository: v1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accepted'), findsOneWidget);

    final v2 = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v2')),
    );
    await tester.pumpWidget(
      _app(
        CommunitySafetyPage(
          key: const ValueKey('community-policy-v2'),
          repository: v2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('community-policy-v2'), findsOneWidget);
    expect(find.text('Accepted'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('accept-community-policy')),
          )
          .onPressed,
      isNull,
    );
    expect(v2.acceptedVersions, isEmpty);
  });

  testWidgets('policy screen remains clear on Android and iOS', (tester) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = platform;
      try {
        await tester.pumpWidget(
          _app(
            CommunitySafetyPage(
              repository: _PolicyRepository(
                CommunityPolicyState.acceptanceRequired(
                  _policy('community-policy-v1'),
                ),
              ),
            ),
            locale: const Locale('ar'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('confirm-community-policy')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: platform.name);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    }
  });

  testWidgets('unaccepted publishing is blocked and keeps the draft', (
    tester,
  ) async {
    final repository = _PublishGuardRepository(
      const CommunityPolicyAccessException(
        failure: CommunityPolicyAccessFailure.acceptanceRequired,
        policyVersion: 'community-policy-v1',
      ),
    );
    await tester.pumpWidget(_app(CommunityHubPage(repository: repository)));
    await tester.pumpAndSettle();
    await _openComposerAndPublish(tester);

    expect(repository.publishCalls, 1);
    expect(
      find.text(
        'Review and accept the active Community policy before publishing.',
      ),
      findsWidgets,
    );
    expect(
      find.text('Keep this draft until Community access is restored.'),
      findsOneWidget,
    );
  });

  testWidgets('suspended member cannot publish and sees a clear lock state', (
    tester,
  ) async {
    final repository = _PublishGuardRepository(
      const CommunityMembershipAccessException(
        failure: CommunityMembershipAccessFailure.suspended,
      ),
    );
    await tester.pumpWidget(_app(CommunityHubPage(repository: repository)));
    await tester.pumpAndSettle();
    await _openComposerAndPublish(tester);

    expect(repository.publishCalls, 1);
    expect(
      find.text(
        'Your Community access is suspended. Publishing remains locked.',
      ),
      findsWidgets,
    );
    expect(
      find.text('Keep this draft until Community access is restored.'),
      findsOneWidget,
    );
  });
}
