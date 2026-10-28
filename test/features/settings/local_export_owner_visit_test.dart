import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_export_command.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/settings/local_export_range_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';

void main() {
  testWidgets('prepared export is retired after a real account change', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    await fixture.pump(tester);
    await _prepare(tester);
    expect(find.text('Share prepared export'), findsOneWidget);
    await fixture.signIn(tester, _ownerB);
    expect(fixture.client.auth.currentUser!.id, _ownerB);
    expect(find.text('Share prepared export'), findsNothing);
    expect(find.text('Export files are ready'), findsNothing);
    expect(fixture.share.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late A export cannot reappear after delivered A B A visits', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    fixture.data.pending = Completer<Map<String, String>>();
    addTearDown(() {
      final pending = fixture.data.pending;
      if (pending != null && !pending.isCompleted) {
        pending.complete(_Data.files);
      }
    });
    await fixture.pump(tester);
    await tester.ensureVisible(find.text('Create CSV export'));
    await tester.tap(find.text('Create CSV export'));
    await tester.pump();
    expect(fixture.data.calls, 1);
    await fixture.signIn(tester, _ownerB);
    await fixture.signIn(tester, _ownerA);
    fixture.data.pending!.complete(_Data.files);
    await tester.pumpAndSettle();
    expect(find.text('Share prepared export'), findsNothing);
    expect(fixture.share.calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('same owner token refresh retains an explicit prepared export', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    await fixture.pump(tester);
    await _prepare(tester);
    await fixture.signIn(tester, _ownerA);
    expect(find.text('Share prepared export'), findsOneWidget);
    await tester.ensureVisible(find.text('Share prepared export'));
    await tester.tap(find.text('Share prepared export'));
    await tester.pumpAndSettle();
    expect(fixture.share.calls, 1);
    expect(fixture.share.lastFiles, _Data.files);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'all dates is locked while preparing or sharing the chosen range',
    (tester) async {
      final fixture = await _Fixture.create(tester);
      fixture.data.pending = Completer<Map<String, String>>();
      fixture.share.pending = Completer<void>();
      addTearDown(() {
        if (!fixture.data.pending!.isCompleted) {
          fixture.data.pending!.complete(_Data.files);
        }
        if (!fixture.share.pending!.isCompleted) {
          fixture.share.pending!.complete();
        }
      });
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 9, 2);
      await fixture.pump(tester, from: from, to: to);
      await tester.ensureVisible(find.text('Create CSV export'));
      await tester.tap(find.text('Create CSV export'));
      await tester.pump();
      await tester.ensureVisible(find.text('All dates'));
      final allDates = find.ancestor(
        of: find.text('All dates'),
        matching: find.byType(TextButton),
      );
      expect(tester.widget<TextButton>(allDates).onPressed, isNull);
      expect(fixture.data.lastFrom, from);
      expect(fixture.data.lastTo, to);
      fixture.data.pending!.complete(_Data.files);
      await tester.pumpAndSettle();
      // Let the genuine preparation snackbar leave the share hit target.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Share prepared export'), 200);
      await tester.tap(find.text('Share prepared export'));
      await tester.pump();
      expect(fixture.share.calls, 1);
      await tester.ensureVisible(find.text('All dates'));
      expect(tester.widget<TextButton>(allDates).onPressed, isNull);
      fixture.share.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(allDates).onPressed, isNotNull);
      final localization = MaterialLocalizations.of(
        tester.element(find.byType(LocalExportRangePage)),
      );
      await tester.scrollUntilVisible(find.text('Start date'), -200);
      expect(find.text(localization.formatMediumDate(from)), findsOneWidget);
      expect(find.text(localization.formatMediumDate(to)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _prepare(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Create CSV export'));
  await tester.tap(find.text('Create CSV export'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Share prepared export'), 200);
}

class _Fixture {
  _Fixture(this.client);
  final SupabaseClient client;
  final data = _Data();
  final share = _Share();
  static String serverOwner = _ownerA;

  static Future<_Fixture> create(WidgetTester tester) async {
    serverOwner = _ownerA;
    final client = (await tester.runAsync(() async {
      final client = SupabaseClient(
        'https://export-owner.invalid',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final payload = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({'sub': serverOwner, 'exp': 4102444800}),
                ),
              )
              .replaceAll('=', '');
          return http.Response(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': serverOwner,
                'email': 'qa@example.invalid',
                'app_metadata': {},
                'user_metadata': {},
                'aud': 'authenticated',
                'created_at': '2026-09-09T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      // Warm Supabase's persistent JSON isolate outside the fake widget clock.
      await client.rpc('read_only_fixture');
      return client;
    }))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final fixture = _Fixture(client);
    await fixture.signIn(tester, _ownerA);
    return fixture;
  }

  Future<void> signIn(WidgetTester tester, String owner) async {
    serverOwner = owner;
    await tester.runAsync(
      () => client.auth.signInWithPassword(
        email: 'qa@example.invalid',
        password: 'local-fixture',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> pump(WidgetTester tester, {DateTime? from, DateTime? to}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileAuthIdentityProvider.overrideWith((ref) async* {
            yield ProfileAuthIdentity.fromUser(client.auth.currentUser);
            await for (final state in client.auth.onAuthStateChange) {
              yield ProfileAuthIdentity.fromUser(state.session?.user);
            }
          }),
        ],
        child: MaterialApp(
          home: LocalExportRangePage(
            initialFrom: from,
            initialTo: to,
            commandService: CoachExportCommandService(data: data, share: share),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _Data implements CoachExportDataGateway {
  static const files = {
    'BIL-progress.csv': 'date,weightKg\n2026-09-01,80.0',
    'BIL-meal-nutrition.csv': 'date,calories\n2026-09-01,1200',
    'BIL-exercise.csv': 'date,note\n2026-09-01,walk',
  };
  int calls = 0;
  DateTime? lastFrom;
  DateTime? lastTo;
  Completer<Map<String, String>>? pending;
  @override
  Future<Map<String, String>> exportCsvFiles({DateTime? from, DateTime? to}) {
    calls++;
    lastFrom = from;
    lastTo = to;
    return pending?.future ?? Future.value(files);
  }
}

class _Share implements CoachExportShareGateway {
  int calls = 0;
  Map<String, String>? lastFiles;
  Completer<void>? pending;
  @override
  Future<void> sharePortableCsvFiles(Map<String, String> files) async {
    calls++;
    lastFiles = files;
    await pending?.future;
  }
}
