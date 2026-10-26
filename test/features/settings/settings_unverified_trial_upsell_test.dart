import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
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

void main() {
  test('neutral upsell label is localized in every supported locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final label = ReferenceSettingsCopy.resolve(
        'Explore Premium',
        locale.toLanguageTag(),
      );
      expect(label, isNotNull, reason: locale.toLanguageTag());
      expect(label!.trim(), isNotEmpty);
      if (locale.languageCode != 'en') {
        expect(label, isNot('Explore Premium'), reason: locale.toLanguageTag());
      }
    }
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final lifecycle in [
      SubscriptionLifecycle.inactive,
      SubscriptionLifecycle.expired,
    ]) {
      testWidgets('Settings never promises unverified trial: '
          '${locale.languageCode} ${lifecycle.name}', (tester) async {
        var planOpenCount = 0;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const ReferenceSettingsHomePage(),
            ),
            GoRoute(
              path: '/plans',
              builder: (_, _) {
                planOpenCount++;
                return const Scaffold(
                  body: Text('Store plans', key: Key('actual-plans-route')),
                );
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileAuthIdentityProvider.overrideWith(
                (_) => Stream.value(
                  const ProfileAuthIdentity(
                    ownerId: 'trial-copy-test',
                    email: 'qa@example.invalid',
                  ),
                ),
              ),
              verifiedSubscriptionStateProvider.overrideWithValue(
                AsyncData(
                  SubscriptionState(
                    plan: CommercePlan.free,
                    entitlements: const {},
                    authority: EntitlementAuthority.verifiedServer,
                    isPurchasable: true,
                    canRestorePurchases: true,
                    lifecycle: lifecycle,
                  ),
                ),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byType(FilledButton);
        await tester.scrollUntilVisible(action, 400);
        final label = ReferenceSettingsCopy.resolve(
          'Explore Premium',
          locale.toLanguageTag(),
        )!;
        expect(find.widgetWithText(FilledButton, label), findsOneWidget);
        expect(
          find.text(
            ReferenceSettingsCopy.resolve(
              'Start 7-day free trial',
              locale.toLanguageTag(),
            )!,
          ),
          findsNothing,
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('actual-plans-route')), findsOneWidget);
        expect(planOpenCount, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
