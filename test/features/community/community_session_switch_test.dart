import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'real Supabase auth events rebuild the feed across local logout and account switch',
    (tester) async {
      var owner = '11111111-1111-4111-8111-111111111111';
      var feedLoads = 0;
      var logoutStatus = 200;
      final logoutScopes = <String?>[];
      final client = (await tester.runAsync(() async {
        final client = SupabaseClient(
          'https://community-session.invalid',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object body = const [];
            if (request.url.path == '/auth/v1/token') {
              final payload = base64Url
                  .encode(
                    utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})),
                  )
                  .replaceAll('=', '');
              body = {
                'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
                'refresh_token': 'test-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': owner,
                  'email': 'qa@example.invalid',
                  'app_metadata': {},
                  'user_metadata': {},
                  'aud': 'authenticated',
                  'created_at': '2026-09-09T00:00:00Z',
                },
              };
            } else if (request.url.path == '/auth/v1/logout') {
              logoutScopes.add(request.url.queryParameters['scope']);
              body = {};
            } else if (request.url.path == '/rest/v1/bil_community_posts') {
              feedLoads++;
              body = [
                {
                  'id': '33333333-3333-4333-8333-333333333333',
                  'author_id': owner,
                  'body': 'Visible for $owner',
                  'created_at': '2026-09-09T00:00:00Z',
                  'moderation_status': 'approved',
                  'deleted_at': null,
                },
              ];
            } else if (request.url.path.endsWith(
              'bil_current_community_policy_status',
            )) {
              body = {
                'status': 'unavailable',
                'server_now': '2026-09-09T00:00:00Z',
              };
            }
            return http.Response(
              jsonEncode(body),
              request.url.path == '/auth/v1/logout' ? logoutStatus : 200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        // Supabase owns a persistent JSON isolate. Initialize it outside the
        // widget test's fake clock, using the same read-only policy request.
        await client.rpc('bil_current_community_policy_status');
        return client;
      }))!;
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: CommunityHubPage(client: client),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      expect(feedLoads, 0);

      await tester.runAsync(
        () => client.auth.signInWithPassword(
          email: 'qa@example.invalid',
          password: 'local-fixture',
        ),
      );
      await _settleFeed(tester, 'Visible for $owner');
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Visible for $owner'), findsOneWidget);
      expect(feedLoads, 1);
      await tester.runAsync(() => client.auth.refreshSession());
      await tester.pumpAndSettle();
      expect(
        feedLoads,
        1,
        reason: 'Refreshing the same account must not reload the feed',
      );

      await tester.runAsync(() => signOutSettingsSession(client.auth, owner));
      await tester.pumpAndSettle();
      expect(logoutScopes, ['local']);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Visible for $owner'), findsNothing);

      final previousOwner = owner;
      owner = '22222222-2222-4222-8222-222222222222';
      await tester.runAsync(
        () => client.auth.signInWithPassword(
          email: 'qa@example.invalid',
          password: 'local-fixture',
        ),
      );
      await _settleFeed(tester, 'Visible for $owner');
      expect(find.text('Visible for $owner'), findsOneWidget);
      expect(find.text('Visible for $previousOwner'), findsNothing);
      expect(feedLoads, 2);
      logoutStatus = 503;
      await tester.runAsync(() => signOutSettingsSession(client.auth, owner));
      await tester.pumpAndSettle();
      expect(client.auth.currentUser, isNull);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Visible for $owner'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

Future<void> _settleFeed(WidgetTester tester, String body) async {
  for (var i = 0; i < 40 && find.text(body).evaluate().isEmpty; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
}
