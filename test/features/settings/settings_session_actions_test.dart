import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_copy.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _member = ProfileAuthIdentity(
  ownerId: 'member-a',
  email: 'qa@example.invalid',
);

void main() {
  test('sign-out failure is translated in every supported locale', () {
    const source = 'Could not sign out. Check your connection and retry.';
    for (final locale in AppLocalizations.supportedLocales) {
      final translated = ReferenceSettingsCopy.resolve(
        source,
        locale.toLanguageTag(),
      );
      expect(translated, isNotNull, reason: locale.toLanguageTag());
      if (locale.languageCode != 'en') {
        expect(translated, isNot(source), reason: locale.toLanguageTag());
      }
    }
  });

  testWidgets('signed-out action opens login and never signs out', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, Stream.value(const ProfileAuthIdentity.local()), (
      _,
    ) async {
      calls++;
    });
    final action = find.byKey(const Key('settings-sign-in'));
    await tester.scrollUntilVisible(action, 300);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-destination')), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('sign-out waits for success and ignores duplicate taps', (
    tester,
  ) async {
    final completion = Completer<void>();
    final owners = <String>[];
    await _pump(tester, Stream.value(_member), (owner) {
      owners.add(owner);
      return completion.future;
    });
    final action = find.byKey(const Key('settings-sign-out'));
    await tester.scrollUntilVisible(action, 300);
    await tester.tap(action);
    await tester.pump();
    await tester.tap(action);
    await tester.pump();
    expect(owners, ['member-a']);
    expect(find.byKey(const Key('login-destination')), findsNothing);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-destination')), findsOneWidget);
  });

  testWidgets('failed sign-out preserves page and permits retry', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, Stream.value(_member), (_) async {
      calls++;
      throw StateError('offline');
    });
    final action = find.byKey(const Key('settings-sign-out'));
    await tester.scrollUntilVisible(action, 300);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-destination')), findsNothing);
    expect(
      find.text('Could not sign out. Check your connection and retry.'),
      findsOneWidget,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets(
    'session switch changes sign-out to sign-in without reopening page',
    (tester) async {
      final identity = StreamController<ProfileAuthIdentity>();
      addTearDown(identity.close);
      identity.add(_member);
      await _pump(tester, identity.stream, (_) async {});
      final action = find.byKey(const Key('settings-sign-out'));
      await tester.scrollUntilVisible(action, 300);
      expect(action, findsOneWidget);
      identity.add(const ProfileAuthIdentity.local());
      await tester.pumpAndSettle();
      expect(action, findsNothing);
      expect(find.byKey(const Key('settings-sign-in')), findsOneWidget);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  Stream<ProfileAuthIdentity> identity,
  Future<void> Function(String) signOut,
) async {
  final router = GoRouter(
    initialLocation: '/settings/preferences',
    routes: [
      GoRoute(
        path: '/settings/preferences',
        builder: (_, _) => const ReferenceSettingsHomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) =>
            const Scaffold(body: Text('Login', key: Key('login-destination'))),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileAuthIdentityProvider.overrideWith((ref) => identity),
        settingsSignOutProvider.overrideWithValue(signOut),
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(
            SubscriptionState(
              plan: CommercePlan.free,
              entitlements: const {},
              authority: EntitlementAuthority.localDefault,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
