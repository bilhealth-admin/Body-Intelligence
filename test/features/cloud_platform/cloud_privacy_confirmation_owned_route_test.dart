// Actual Privacy page/modal/repository/owner fence. Synthetic Auth/RPC and
// available-but-ungranted entry snapshot isolate route lifetime, not readiness.
// The independent cold-provider suite owns actual provider availability proof.
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_sync_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_sync_consent_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/settings/sharing_privacy_settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '00000000-0000-4000-8048-000000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('retired Privacy confirm cannot pop an unrelated modal or write', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester);
    Route<bool>? consentDialog;
    DialogRoute<void>? unrelated;
    try {
      await f.openEnable(tester);
      final confirm = find.descendant(
        of: find.byWidgetPredicate((widget) => widget is AlertDialog),
        matching: find.byType(FilledButton),
      );
      expect(confirm, findsOneWidget);
      final oldConfirm = tester.widget<FilledButton>(confirm).onPressed!;
      consentDialog = ModalRoute.of<bool>(tester.element(confirm));
      expect(consentDialog, isNotNull);
      final navigator = consentDialog!.navigator!;
      unrelated = DialogRoute<void>(
        context: navigator.context,
        builder: (_) =>
            const AlertDialog(title: Text('Unrelated protected modal')),
      );
      unawaited(navigator.push<void>(unrelated));
      await tester.pumpAndSettle();
      expect(unrelated.isCurrent, isTrue);
      expect(consentDialog.isCurrent, isFalse);
      expect(f.http.writes, isEmpty);
      oldConfirm();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        unrelated.isCurrent,
        isTrue,
        reason:
            'Queued old confirmation owns its exact dialog, never the route above it.',
      );
      expect(find.text('Unrelated protected modal'), findsOneWidget);
      expect(f.http.writes, isEmpty);
      expect(f.syncCalls, 0);
    } finally {
      final covered = unrelated;
      if (covered != null && covered.isActive) {
        covered.navigator!.removeRoute<void>(covered);
      }
      final original = consentDialog;
      if (original != null && original.isActive) {
        original.navigator!.removeRoute<bool>(original, false);
      }
      await tester.pumpAndSettle();
      await f.close(tester);
    }
  });

  testWidgets(
    'current Privacy confirm records one grant and runs explicit sync once',
    (tester) async {
      final f = await _Fixture.mount(tester);
      try {
        await f.openEnable(tester);
        final confirm = find.descendant(
          of: find.byWidgetPredicate((widget) => widget is AlertDialog),
          matching: find.byType(FilledButton),
        );
        expect(confirm, findsOneWidget);
        await tester.ensureVisible(confirm);
        await tester.pump();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(f.http.writes, [(_owner, true)]);
        expect(f.syncCalls, 1);
        expect(
          find.byWidgetPredicate((widget) => widget is AlertDialog),
          findsNothing,
        );
        expect(find.byType(SharingPrivacySettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await f.close(tester);
      }
    },
  );
}

class _Fixture {
  final http = _SyntheticAuthConsent();
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  late ProviderContainer container;
  var syncCalls = 0;

  static Future<_Fixture> mount(WidgetTester tester) async {
    final f = (await tester.runAsync(() async {
      // Construct the SDK, its JSON isolate and auth listeners in the same
      // real-async Zone used for sign-in and disposal. A fakeAsync-owned SDK
      // can strand dispose() while runAsync pauses its original event queue.
      final fixture = _Fixture();
      await fixture.http.signIn();
      return fixture;
    }))!;
    f.container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(f.database),
        diarySharingSummaryProvider.overrideWith(
          (_) => Stream.value('private'),
        ),
        cloudSyncConsentRepositoryProvider.overrideWithValue(
          CloudSyncConsentRepository(client: f.http.client),
        ),
        // Same narrow DI boundary as existing owner_dialog canonical test.
        // This is denied data, not authority or a synthetic paid/consent grant.
        cloudSyncConsentStateProvider.overrideWith(
          (_) async => const CloudSyncConsentState(
            availability: CloudSyncConsentAvailability.available,
            ownerId: _owner,
            granted: false,
          ),
        ),
        cloudManualSyncStatusProvider.overrideWith(
          (_) => CloudManualSyncStatusController(
            preferences: PreferencesRepository(f.database),
            cloudAvailable: true,
            ownerId: _owner,
            runSync: () async {
              f.syncCalls++;
              return const CloudManualSyncResult(
                disposition: CloudManualSyncDisposition.unavailable,
              );
            },
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: f.container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const SharingPrivacySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return f;
  }

  Future<void> openEnable(WidgetTester tester) async {
    final tile = find.byKey(const Key('encrypted-cloud-sync-consent'));
    expect(tile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).onChanged, isNotNull);
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await tester.runAsync(() async {
      await database.close();
      await http.client.dispose();
    });
  }
}

class _SyntheticAuthConsent {
  _SyntheticAuthConsent() {
    client = SupabaseClient(
      'https://privacy-dialog-owned-route.invalid',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(_handle)),
    );
  }
  late final SupabaseClient client;
  final writes = <(String, bool)>[];
  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: '$_owner@example.invalid',
      password: 'synthetic-only',
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<http.Response> _handle(http.Request request) async {
    expect(request.url.host, 'privacy-dialog-owned-route.invalid');
    final Object body;
    if (request.url.path == '/auth/v1/token') {
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'sub': _owner,
                'exp': 4102444800,
                'role': 'authenticated',
              }),
            ),
          )
          .replaceAll('=', '');
      body = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': _owner,
          'aud': 'authenticated',
          'created_at': '2026-11-16T00:00:00Z',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
        },
      };
    } else if (request.url.path == '/rest/v1/rpc/bil_record_consent') {
      expect(request.method, 'POST');
      final token = request.headers['authorization']!.split(' ').last;
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map;
      expect(claims['sub'], _owner);
      final params = jsonDecode(request.body) as Map;
      expect(params['p_purpose'], 'cloud_sync');
      expect(params['p_policy_version'], '1');
      expect(params['p_granted'], isTrue);
      writes.add((_owner, true));
      body = {'recorded': true};
    } else {
      throw StateError('Unexpected synthetic operation outside modal contract');
    }
    return http.Response(
      jsonEncode(body),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
