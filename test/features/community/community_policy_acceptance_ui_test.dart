import 'dart:async';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_safety_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

CommunityContentPolicy _policy(String version) =>
    CommunityContentPolicy.fromJson({
      'version': version,
      'locale_code': 'en',
      'document_url': 'https://www.bilhealth.com/community-guidelines',
      'effective_at': '2026-09-08T00:00:00.000Z',
    });

final class _PolicyRepository extends CommunityRepository {
  _PolicyRepository(
    this.state, {
    this.stateAfterAcceptance,
    this.postAcceptLoadBarrier,
    this.postAcceptLoadError,
  }) : super(
         SupabaseClient(
           'https://community-policy-test.invalid',
           'community-policy-test-key',
           authOptions: const AuthClientOptions(autoRefreshToken: false),
         ),
       );

  CommunityPolicyState state;
  final CommunityPolicyState? stateAfterAcceptance;
  final Future<void>? postAcceptLoadBarrier;
  final Object? postAcceptLoadError;
  final List<String> acceptedVersions = [];
  int loadCalls = 0;

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    loadCalls += 1;
    if (acceptedVersions.isNotEmpty) {
      final barrier = postAcceptLoadBarrier;
      if (barrier != null) await barrier;
      final error = postAcceptLoadError;
      if (error != null) throw error;
    }
    return state;
  }

  @override
  Future<void> acceptContentPolicy(String version) async {
    acceptedVersions.add(version);
    final replacement = stateAfterAcceptance;
    if (replacement != null) {
      state = replacement;
      return;
    }
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
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => CommunityPolicyState.accepted(
    _policy('community-policy-v1'),
    acceptedVersion: 'community-policy-v1',
  );

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

  testWidgets(
    'canonical policy launcher preserves English and requests Arabic',
    (tester) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        final repository = _PolicyRepository(
          CommunityPolicyState.acceptanceRequired(
            _policy('community-policy-v1'),
          ),
        );
        Uri? launched;
        await tester.pumpWidget(
          _app(
            CommunitySafetyPage(
              key: ValueKey(locale.languageCode),
              repository: repository,
              policyUrlLauncher: (uri) async {
                launched = uri;
                return true;
              },
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-community-policy')));
        await tester.pumpAndSettle();

        expect(launched?.scheme, 'https');
        expect(launched?.host, 'www.bilhealth.com');
        expect(launched?.path, '/community-guidelines');
        expect(
          launched?.queryParameters['lang'],
          locale.languageCode == 'ar' ? 'ar' : isNull,
        );
        expect(repository.acceptedVersions, isEmpty);
      }
    },
  );

  testWidgets('unaccepted policy stays locked until the user confirms', (
    tester,
  ) async {
    final postAcceptRead = Completer<void>();
    final repository = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v1')),
      postAcceptLoadBarrier: postAcceptRead.future,
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
    await tester.pump();

    expect(repository.acceptedVersions, ['community-policy-v1']);
    expect(repository.loadCalls, 2);
    expect(find.text('Accepted'), findsNothing);

    postAcceptRead.complete();
    await tester.pumpAndSettle();

    expect(find.text('Accepted'), findsOneWidget);
  });

  testWidgets('failed server re-read never creates optimistic acceptance', (
    tester,
  ) async {
    final repository = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v1')),
      postAcceptLoadError: StateError('policy receipt read failed'),
    );
    await tester.pumpWidget(_app(CommunitySafetyPage(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-community-policy')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('accept-community-policy')));
    await tester.pumpAndSettle();

    expect(repository.acceptedVersions, ['community-policy-v1']);
    expect(repository.loadCalls, 2);
    expect(find.text('Accepted'), findsNothing);
    expect(
      find.text('Consent could not be saved. Publishing remains locked.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('accept-community-policy')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('server must confirm acceptance for the exact policy version', (
    tester,
  ) async {
    final repository = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v1')),
      stateAfterAcceptance: CommunityPolicyState.accepted(
        _policy('community-policy-v2'),
        acceptedVersion: 'community-policy-v2',
      ),
    );
    await tester.pumpWidget(_app(CommunitySafetyPage(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-community-policy')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('accept-community-policy')));
    await tester.pumpAndSettle();

    expect(repository.acceptedVersions, ['community-policy-v1']);
    expect(repository.loadCalls, 2);
    expect(find.text('Accepted'), findsNothing);
    expect(find.textContaining('community-policy-v1'), findsOneWidget);
    expect(find.textContaining('community-policy-v2'), findsNothing);
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

  testWidgets('replacing the repository reloads policy state immediately', (
    tester,
  ) async {
    final first = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v1')),
    );
    final replacement = _PolicyRepository(
      CommunityPolicyState.accepted(
        _policy('community-policy-v2'),
        acceptedVersion: 'community-policy-v2',
      ),
    );

    await tester.pumpWidget(_app(CommunitySafetyPage(repository: first)));
    await tester.pumpAndSettle();
    expect(first.loadCalls, 1);
    expect(find.textContaining('community-policy-v1'), findsOneWidget);

    await tester.pumpWidget(_app(CommunitySafetyPage(repository: replacement)));
    await tester.pumpAndSettle();

    expect(replacement.loadCalls, 1);
    expect(find.textContaining('community-policy-v1'), findsNothing);
    expect(find.textContaining('community-policy-v2'), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget);
  });

  testWidgets('Not now invokes the optional decline callback only', (
    tester,
  ) async {
    final repository = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v1')),
    );
    var declineCalls = 0;
    await tester.pumpWidget(
      _app(
        CommunitySafetyPage(
          repository: repository,
          onDecline: () => declineCalls += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('community-policy-not-now')));
    await tester.pump();

    expect(declineCalls, 1);
    expect(repository.acceptedVersions, isEmpty);
    expect(find.byType(CommunitySafetyPage), findsOneWidget);
  });

  testWidgets('Not now pops false when policy was pushed', (tester) async {
    final repository = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v1')),
    );
    bool? declineResult;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-community-policy-test'),
              onPressed: () async {
                declineResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => CommunitySafetyPage(repository: repository),
                  ),
                );
              },
              child: const Text('Open policy'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-community-policy-test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-policy-not-now')));
    await tester.pumpAndSettle();

    expect(declineResult, isFalse);
    expect(repository.acceptedVersions, isEmpty);
    expect(find.text('Open policy'), findsOneWidget);
  });

  testWidgets('root Not now redirects to Community without acceptance', (
    tester,
  ) async {
    final repository = _PolicyRepository(
      CommunityPolicyState.acceptanceRequired(_policy('community-policy-v1')),
    );
    final router = GoRouter(
      initialLocation: '/community/safety',
      routes: [
        GoRoute(
          path: '/community',
          builder: (_, _) => const Scaffold(
            body: Text(
              'Community destination',
              key: Key('community-decline-destination'),
            ),
          ),
        ),
        GoRoute(
          path: '/community/safety',
          builder: (_, _) => CommunitySafetyPage(repository: repository),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('community-policy-not-now')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('community-decline-destination')),
      findsOneWidget,
    );
    expect(router.routeInformationProvider.value.uri.path, '/community');
    expect(repository.acceptedVersions, isEmpty);
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
