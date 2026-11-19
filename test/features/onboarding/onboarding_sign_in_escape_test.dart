import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:body_intelligence_log/features/onboarding/onboarding_page.dart';
import 'package:body_intelligence_log/features/onboarding/services/onboarding_permission_gateways.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'first Back saves exact owner draft and returns guest to sign in',
    (tester) async {
      final h = await _Harness.open(tester);
      try {
        await tester.tap(find.byKey(const Key('onboarding-back')));
        await _flush(tester);
        expect(h.path, '/login');
        expect(Supabase.instance.client.auth.currentUser, isNull);
        expect(h.logoutCalls, 1);
        expect(h.logoutScopes, ['local']);
        final saved = (await h.drafts.load())!;
        expect(saved.encode(), h.initial.encode());
        expect(await UserProfileRepository(h.database).getProfile(), isNull);
        expect(h.remote.writes, 0);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'explicit later-step exit saves once and ignores duplicate taps',
    (tester) async {
      final h = await _Harness.open(tester, step: 'height');
      try {
        h.preferences.held = Completer<void>();
        await tester.enterText(
          find.byKey(const Key('onboarding-height')),
          '177',
        );
        final action = find.byKey(const Key('onboarding-back-to-sign-in'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await _flush(tester);
        expect(h.preferences.entered, isTrue);
        await tester.tap(action);
        await tester.pump();
        expect(h.preferences.updateCalls, 1);
        expect(h.logoutCalls, 0);
        h.preferences.held!.complete();
        await _flush(tester);
        expect(h.path, '/login');
        final saved = (await h.drafts.load())!;
        expect(saved.stepId, 'height');
        expect(saved.heightCm, 177);
        expect(saved.remoteAiConsent, OnboardingRemoteAiConsent.declined);
        expect(h.logoutCalls, 1);
        expect(h.remote.writes, 0);
      } finally {
        await h.close(tester);
      }
    },
  );

  for (final aba in [false, true]) {
    testWidgets(
      'held draft ${aba ? 'ABA' : 'replacement'} retires exit without logout or navigation',
      (tester) async {
        final h = await _Harness.open(tester);
        try {
          h.preferences.held = Completer<void>();
          await tester.tap(find.byKey(const Key('onboarding-back')));
          await _flush(tester);
          expect(h.preferences.entered, isTrue);
          await tester.runAsync(() => h.signIn(_b));
          if (aba) await tester.runAsync(() => h.signIn(_a));
          h.preferences.held!.complete();
          await _flush(tester);
          expect(h.path, '/onboarding');
          expect(h.logoutCalls, 0);
          expect(Supabase.instance.client.auth.currentUser?.id, aba ? _a : _b);
          expect((await h.drafts.load())!.encode(), h.initial.encode());
          expect(h.remote.writes, 0);
        } finally {
          await h.close(tester);
        }
      },
    );
  }

  testWidgets('draft storage failure remains recoverable without signing out', (
    tester,
  ) async {
    final h = await _Harness.open(tester);
    try {
      h.preferences.fail = true;
      await tester.tap(find.byKey(const Key('onboarding-back')));
      await _flush(tester);
      expect(h.path, '/onboarding');
      expect(h.logoutCalls, 0);
      expect(Supabase.instance.client.auth.currentUser?.id, _a);
      expect(
        find.text('Could not sign out. Check your connection and retry.'),
        findsOneWidget,
      );
      expect((await h.drafts.load())!.encode(), h.initial.encode());
      h.preferences.fail = false;
      await tester.tap(find.byKey(const Key('onboarding-back')));
      await _flush(tester);
      expect(h.path, '/login');
      expect(h.logoutCalls, 1);
    } finally {
      await h.close(tester);
    }
  });

  testWidgets('replacement during logout HTTP does not route or sign out B', (
    tester,
  ) async {
    final h = await _Harness.open(tester);
    try {
      h.logoutHold = Completer<void>();
      await tester.tap(find.byKey(const Key('onboarding-back')));
      await _flush(tester);
      expect(h.logoutCalls, 1);
      expect(Supabase.instance.client.auth.currentUser, isNull);
      await tester.runAsync(() => h.signIn(_b));
      h.logoutHold!.complete();
      await _flush(tester);
      expect(h.path, '/onboarding');
      expect(Supabase.instance.client.auth.currentUser?.id, _b);
      expect(h.logoutCalls, 1);
    } finally {
      await h.close(tester);
    }
  });

  testWidgets(
    'review setup keeps its existing Settings return and no logout action',
    (tester) async {
      final h = await _Harness.open(tester, review: true);
      try {
        expect(
          find.byKey(const Key('onboarding-back-to-sign-in')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('onboarding-back')));
        await _flush(tester);
        expect(h.path, '/settings');
        expect(h.logoutCalls, 0);
        expect(h.remote.writes, 0);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'Arabic narrow 2x escape is translated, reachable and has no overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final h = await _Harness.open(
        tester,
        locale: const Locale('ar'),
        scale: 2,
      );
      try {
        final action = find.byKey(const Key('onboarding-back-to-sign-in'));
        expect(find.text('العودة إلى تسجيل الدخول'), findsOneWidget);
        await tester.ensureVisible(action);
        expect(tester.takeException(), isNull);
        await tester.tap(action);
        await _flush(tester);
        expect(h.path, '/login');
        expect(h.logoutCalls, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

class _HeldPreferences extends PreferencesRepository {
  _HeldPreferences(super.database);
  Completer<void>? held;
  bool entered = false, fail = false;
  int updateCalls = 0;

  @override
  Future<String> update(
    String key,
    String Function(String?) derive, {
    bool Function()? isCurrent,
  }) async {
    updateCalls++;
    entered = true;
    await held?.future;
    if (fail) throw StateError('synthetic storage unavailable');
    return super.update(key, derive, isCurrent: isCurrent);
  }
}

class _Remote implements OnboardingRemoteAiGateway {
  int writes = 0;
  @override
  Future<OnboardingRemoteAiResult> read() async =>
      OnboardingRemoteAiResult.declined;
  @override
  Future<OnboardingRemoteAiResult> setGranted(bool granted) async {
    writes++;
    throw StateError('Escape must not write remote consent');
  }
}

class _Harness {
  late AppDatabase database;
  late _HeldPreferences preferences;
  late OnboardingDraftRepository drafts;
  late OnboardingDraft initial;
  late GoRouter router;
  final remote = _Remote();
  int logoutCalls = 0;
  final logoutScopes = <String?>[];
  Completer<void>? logoutHold;
  String get path =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  static Future<_Harness> open(
    WidgetTester tester, {
    String step = 'goals',
    bool review = false,
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    final h = _Harness();
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await Supabase.initialize(
        url: 'https://onboarding-escape.invalid',
        publishableKey: 'synthetic-public-key',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: MockClient((request) async {
          if (!request.url.path.endsWith('/logout')) {
            throw StateError('Unexpected fixture route ${request.url.path}');
          }
          h.logoutCalls++;
          h.logoutScopes.add(request.url.queryParameters['scope']);
          await h.logoutHold?.future;
          return http.Response('', 204, request: request);
        }),
      );
      await h.signIn(_a);
      h.database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: _a,
      );
      h.preferences = _HeldPreferences(h.database);
      h.drafts = OnboardingDraftRepository(h.preferences);
      h.initial = OnboardingDraft(
        stepId: step,
        preferredName: 'Synthetic preserved name',
        heightCm: 170,
        countryRegion: 'Jordan',
        weeklyPaceKg: 0,
        remoteAiConsent: OnboardingRemoteAiConsent.declined,
      );
      await h.drafts.save(h.initial);
    });
    h.router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => OnboardingPage(reviewMode: review),
        ),
        GoRoute(
          path: '/account-gateway',
          builder: (_, _) => const Scaffold(body: Text('Gateway loop')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Sign in destination')),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('Settings destination')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(h.database),
          preferencesRepositoryProvider.overrideWithValue(h.preferences),
          onboardingRemoteAiGatewayProvider.overrideWithValue(h.remote),
        ],
        child: MaterialApp.router(
          routerConfig: h.router,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await _flush(tester);
    expect(find.byKey(const Key('onboarding-step-title')), findsOneWidget);
    return h;
  }

  Future<void> signIn(String owner) => Supabase.instance.client.auth
      .setInitialSession(
        jsonEncode({
          'access_token': 'synthetic-token-$owner',
          'refresh_token': 'synthetic-refresh-$owner',
          'token_type': 'bearer',
          'user': {
            'id': owner,
            'aud': 'authenticated',
            'app_metadata': {'provider': 'email'},
            'user_metadata': {},
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      )
      .then((_) {});

  Future<void> close(WidgetTester tester) async {
    if (preferences.held != null && !preferences.held!.isCompleted) {
      preferences.held!.complete();
    }
    if (logoutHold != null && !logoutHold!.isCompleted) logoutHold!.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    await tester.runAsync(() async {
      await database.close();
      await Supabase.instance.dispose();
    });
  }
}
