import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_sync_consent_notice.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_sync_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_sync_consent_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/settings/sharing_privacy_settings_page.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_cloud_sync.dart';
import 'package:flutter/rendering.dart';
import '../../visual_closure/visual_evidence_font.dart';

const _ownerA = '00000000-0000-4000-8030-000000000001';
const _ownerB = '00000000-0000-4000-8030-000000000002';

Future<_Harness> _mountCompactNotice(
  WidgetTester tester, {
  required Size size,
  required Locale locale,
  required double scale,
}) async {
  final fixture = (await tester.runAsync(() async {
    final fixture = _ConsentHttpFixture();
    await fixture.signIn(_ownerA);
    return fixture;
  }))!;
  final harness = _Harness(fixture);
  addTearDown(fixture.client.dispose);
  addTearDown(harness.database.close);
  addTearDown(harness.container.dispose);
  addTearDown(harness.router.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final font = locale.languageCode == 'ar'
      ? 'NotoArabicEvidence'
      : 'RobotoEvidence';
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('compact-consent-golden-boundary'),
      child: UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: visualEvidenceTheme(
            BilFlagshipTheme.light(isArabic: locale.languageCode == 'ar'),
            fontFamily: font,
          ).copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          routerConfig: harness.router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

void _expectReachableChoices(WidgetTester tester, Size size) {
  final dock = tester.getRect(find.byKey(const Key('glass-bottom-navigation')));
  for (final key in ['cloud-sync-enable-backup', 'cloud-sync-keep-local']) {
    final button = find.byKey(Key(key));
    expect(button, findsOneWidget);
    expect(
      button.hitTestable(),
      findsOneWidget,
      reason:
          'Both explicit privacy choices must be available before any scroll.',
    );
    final rect = tester.getRect(button);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(size.width));
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(
      rect.bottom,
      lessThanOrEqualTo(dock.top),
      reason: 'The real nested shell dock cannot cover either choice.',
    );
  }
  final context = tester.element(
    find.byKey(const Key('cloud-sync-keep-local')),
  );
  expect(
    identical(
      Navigator.of(context),
      Navigator.of(context, rootNavigator: true),
    ),
    isFalse,
    reason: 'The existing nested route ownership remains unchanged.',
  );
}

Future<void> _readDetailsWithoutMovingChrome(
  WidgetTester tester,
  Size size,
) async {
  final heading = find.byKey(const Key('cloud-sync-consent-pinned-heading'));
  final headingBefore = tester.getRect(heading);
  final keep = find.byKey(const Key('cloud-sync-keep-local'));
  final keepBefore = tester.getRect(keep);
  final manage = find.byKey(const Key('cloud-sync-manage-categories'));
  await tester.ensureVisible(manage);
  await tester.pumpAndSettle();
  expect(manage.hitTestable(), findsOneWidget);
  final body = tester.getRect(
    find.byKey(const Key('cloud-sync-consent-details-scroll')),
  );
  final link = tester.getRect(manage);
  expect(link.top, greaterThanOrEqualTo(body.top - .01));
  expect(link.bottom, lessThanOrEqualTo(body.bottom + .01));
  expect(
    tester.getRect(heading),
    headingBefore,
    reason: 'The primary title stays fixed while the disclosure body scrolls.',
  );
  expect(
    tester.getRect(keep),
    keepBefore,
    reason: 'Reading the disclosure cannot move either privacy choice.',
  );
  _expectReachableChoices(tester, size);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualEvidenceFont);
  for (final size in [const Size(360, 800), const Size(430, 932)]) {
    for (final scale in [1.0, 1.15, 2.0]) {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        final name =
            '${size.width.toInt()}x${size.height.toInt()} '
            '${locale.languageCode} scale$scale';
        testWidgets(
          'first Progress choices remain reachable without scroll $name',
          (tester) async {
            final harness = await _mountCompactNotice(
              tester,
              size: size,
              locale: locale,
              scale: scale,
            );
            expect(harness.fixture.writes, isEmpty);
            expect(harness.syncCalls, 0);
            _expectReachableChoices(tester, size);
            final keep = find.byKey(const Key('cloud-sync-keep-local'));
            await _readDetailsWithoutMovingChrome(tester, size);
            final context = tester.element(keep);
            final localText = context.strings.text(
              CloudSyncConsentCopy.localAction,
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: keep, matching: find.text(localText)),
            );
            expect(
              paragraph.textScaler.scale(15),
              closeTo(15 * scale, .001),
              reason: 'OS text scaling must remain effective.',
            );
            expect(tester.takeException(), isNull);
            await tester.tap(keep);
            await tester.pumpAndSettle();
            expect(harness.fixture.writes, [(_ownerA, false)]);
            expect(harness.syncCalls, 0);
            expect(harness.privacyOwners, isEmpty);
            expect(keep, findsNothing);
            expect(
              harness
                  .router
                  .routerDelegate
                  .currentConfiguration
                  .last
                  .matchedLocation,
              '/dashboard',
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );

        if (scale > 1) {
          for (final action in ['enable', 'manage']) {
            testWidgets(
              'compact Progress $action acts after reading details $name',
              (tester) async {
                final harness = await _mountCompactNotice(
                  tester,
                  size: size,
                  locale: locale,
                  scale: scale,
                );
                _expectReachableChoices(tester, size);
                expect(harness.fixture.writes, isEmpty);
                expect(harness.syncCalls, 0);
                await _readDetailsWithoutMovingChrome(tester, size);
                final selected = find.byKey(
                  Key(
                    action == 'enable'
                        ? 'cloud-sync-enable-backup'
                        : 'cloud-sync-manage-categories',
                  ),
                );
                await tester.tap(selected);
                await tester.pumpAndSettle();
                if (action == 'enable') {
                  expect(harness.fixture.writes, [(_ownerA, true)]);
                  expect(harness.syncCalls, 1);
                  expect(harness.privacyOwners, isEmpty);
                  expect(
                    find.byKey(const Key('cloud-sync-enable-backup')),
                    findsNothing,
                  );
                } else {
                  expect(
                    harness
                        .router
                        .routerDelegate
                        .currentConfiguration
                        .last
                        .matchedLocation,
                    '/settings/sharing-privacy',
                  );
                  expect(
                    find.byType(SharingPrivacySettingsPage),
                    findsOneWidget,
                  );
                  expect(harness.privacyOwners, [_ownerA]);
                  expect(harness.fixture.writes, isEmpty);
                  expect(harness.syncCalls, 0);
                  harness.router.pop();
                  await tester.pumpAndSettle();
                  expect(
                    harness
                        .router
                        .routerDelegate
                        .currentConfiguration
                        .last
                        .matchedLocation,
                    '/dashboard',
                  );
                  expect(
                    find.byKey(const Key('cloud-sync-manage-categories')),
                    findsNothing,
                  );
                  expect(harness.fixture.writes, isEmpty);
                  expect(harness.syncCalls, 0);
                }
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pumpAndSettle();
              },
            );
          }
        }

        testWidgets('new compact Progress consent golden $name', (
          tester,
        ) async {
          final harness = await _mountCompactNotice(
            tester,
            size: size,
            locale: locale,
            scale: scale,
          );
          _expectReachableChoices(tester, size);
          expect(harness.fixture.writes, isEmpty);
          expect(harness.syncCalls, 0);
          final suffix =
              '${locale.languageCode}_${size.width.toInt()}_'
              '${(scale * 100).round()}';
          await expectLater(
            find.byKey(const Key('compact-consent-golden-boundary')),
            matchesGoldenFile('goldens/cloud_sync_consent_compact/$suffix.png'),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}

final class _Harness {
  _Harness(this.fixture) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        // Diary visibility is unrelated to the consent navigation under test.
        diarySharingSummaryProvider.overrideWith(
          (_) => Stream.value('private'),
        ),
        cloudSyncConsentRepositoryProvider.overrideWithValue(
          CloudSyncConsentRepository(client: fixture.client),
        ),
        cloudSyncConsentStateProvider.overrideWith((_) async => current),
        cloudManualSyncStatusProvider.overrideWith(
          (_) => CloudManualSyncStatusController(
            preferences: PreferencesRepository(database),
            cloudAvailable: true,
            ownerId: _ownerA,
            runSync: () async {
              syncCalls++;
              return const CloudManualSyncResult(
                disposition: CloudManualSyncDisposition.unavailable,
              );
            },
          ),
        ),
      ],
    );
    router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              ResponsiveAppShell(currentUri: state.uri, child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const Scaffold(body: CloudSyncConsentNotice()),
            ),
            GoRoute(
              path: '/settings/sharing-privacy',
              builder: (_, _) {
                privacyOwners.add(fixture.client.auth.currentUser!.id);
                return const SharingPrivacySettingsPage();
              },
            ),
          ],
        ),
      ],
    );
  }
  final _ConsentHttpFixture fixture;
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  late final ProviderContainer container;
  late final GoRouter router;
  var current = const CloudSyncConsentState(
    availability: CloudSyncConsentAvailability.available,
    ownerId: _ownerA,
  );
  var syncCalls = 0;
  final privacyOwners = <String>[];

  Future<void> changeOwner(WidgetTester tester, String transition) async {
    for (final owner
        in transition == 'A to B' ? [_ownerB] : [_ownerB, _ownerA]) {
      await tester.runAsync(() => fixture.signIn(owner));
      current = CloudSyncConsentState(
        availability: CloudSyncConsentAvailability.available,
        ownerId: owner,
        recordedAt: DateTime.utc(2026, 11, 16),
      );
      container.invalidate(cloudSyncConsentStateProvider);
      await tester.pumpAndSettle();
    }
  }
}

// Only synthetic Auth/RPC HTTP is used. No hosted backend or OS health store.
final class _ConsentHttpFixture {
  _ConsentHttpFixture() {
    client = SupabaseClient(
      'https://cloud-owner-choice.invalid',
      'fixture-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(_handle)),
    );
  }

  late final SupabaseClient client;
  final writes = <(String, bool)>[];

  Future<void> signIn(String owner) async {
    await client.auth.signInWithPassword(
      email: '$owner@example.invalid',
      password: 'fixture',
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<http.Response> _handle(http.Request request) async {
    expect(request.url.host, 'cloud-owner-choice.invalid');
    final Object body;
    if (request.url.path == '/auth/v1/token') {
      final email = (jsonDecode(request.body) as Map)['email'] as String;
      final owner = email.split('@').first;
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      body = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'fixture-refresh-token-$owner',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-10-20T00:00:00Z',
        },
      };
    } else if (request.url.path == '/rest/v1/rpc/bil_record_consent') {
      final token = request.headers['Authorization']!.split(' ').last;
      final owner =
          (jsonDecode(
                    utf8.decode(
                      base64Url.decode(
                        base64Url.normalize(token.split('.')[1]),
                      ),
                    ),
                  )
                  as Map)['sub']
              as String;
      final params = jsonDecode(request.body) as Map;
      expect(params['p_purpose'], 'cloud_sync');
      expect(params['p_policy_version'], '1');
      writes.add((owner, params['p_granted'] as bool));
      body = {'recorded': true};
    } else {
      throw StateError('Unexpected synthetic request: ${request.url.path}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
